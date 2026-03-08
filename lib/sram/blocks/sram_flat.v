`timescale 1ns/1ps
/* Flat register base SRAM driver

Meant for bulk line size data (e.g. scanline/cacheline).

*/


module spi_sram_flat #(
	parameter CLK_FREQ_MHZ=27,								// system clock frequency (required for walltime requirements)
	parameter DATA_WIDTH=32,								// controls the line size

	// default configuration for a 23LC512 (20MHz max QPI rate)
	parameter SRAM_ADDR_WIDTH=16,							// how many bits does the address have (e.g. 16 or 24)
	parameter DUMMY_BYTES=1,								// how many dummy reads are required before the first byte is valid
	parameter CMD_READ=8'h03,								// command to read 
	parameter CMD_WRITE=8'h02,								// command to write
	parameter CMD_EQIO=8'h38,								// command to enter quad IO mode
	parameter MIN_CPH_NS=5,									// how many ns must CS be high between commands (23LC's have a min time of mostly nothing)
	parameter SPI_TIMER_BITS=4,								// divide clock by 16 for SPI operations
	parameter QPI_TIMER_BITS=1								// divide clcok by 2 for QPI operations
)(
	input clk,												// clock
	input rst_n,											// active low reset

	// BUS
	output done,											// active high means the module is done with a request
	
	// DATA in/out
	input [DATA_WIDTH-1:0] data_in,							// data to write to the SRAM
	input data_in_valid,									// active high indicates the user wants to send data to the outgoing FIFO
	output reg [DATA_WIDTH-1:0] data_out,					// The entire line output
	input [3:0] data_be,									// byte enables (only supported for DATA_WIDTH==32)
	
	// CMD
	input write_cmd,										// active high we're doing a write
	input read_cmd,											// active high we're doing a read
	input [SRAM_ADDR_WIDTH-1:0] address,					// address to read/write from

	// I/O
	inout [3:0] sio_pin,									// data pins
	output cs_pin,											// active low CS pin
	output sck_pin											// SPI clock
);
`ifdef SIM_MODEL
	reg [7:0] sim_memory[(1<<SRAM_ADDR_WIDTH)-1:0];
	reg [15:0] sim_address;
	reg [7:0] sim_dummy;
`endif

	reg [SPI_TIMER_BITS-1:0] timer;

	reg [3:0] dout;											// our output to the SPI bus
	reg [3:0] sio_en;										// per lane output enables 

	assign sio_pin[0] = sio_en[0] ? dout[0] : 1'bz;
	assign sio_pin[1] = sio_en[1] ? dout[1] : 1'bz;
	assign sio_pin[2] = sio_en[2] ? dout[2] : 1'bz;
	assign sio_pin[3] = sio_en[3] ? dout[3] : 1'bz;
	wire [3:0] din = sio_pin;
	
	// SEND wire
	// total size of send wire
	localparam SEND_SIZE = 8 + (SRAM_ADDR_WIDTH) + DATA_WIDTH;
	localparam READ_SIZE = 8 + SRAM_ADDR_WIDTH;
	reg [SRAM_ADDR_WIDTH-1:0] send_address;					// latched address
	reg [DATA_WIDTH-1:0] send_data;							// latched data to send
	reg [7:0] send_cmd;										// the command byte to send

	// thes wires forms the basic command we send when doing a read or a write
	wire [SEND_SIZE-1:0] send_wire = { send_cmd, send_address, send_data };
	wire [READ_SIZE-1:0] read_wire = { send_cmd, send_address };

	reg [3:0] read_data_be;									// latch the data_be
	
	wire spi_pulse;
	wire qpi_pulse;
	reg spi_prev_pulse;										// previous pulse to detect edge of pulse
	reg qpi_prev_pulse;										// previous pulse to detect edge of pulse
	
	reg [3:0] state;										// What state is our FSM in
	reg [7:0] bit_cnt;										// bit counter a variety of FSM states
	reg [$clog2(DUMMY_BYTES*2):0] dummy_nibbles;			// how many nibbles to ignore
	reg [$clog2(SEND_SIZE)-1:0] nibble_idx;					// index into reg/wires in steps of 4 bits

	reg [7:0] hangup_timer;
	wire [15:0] hangup_bauddiv = ((CLK_FREQ_MHZ * MIN_CPH_NS + 999) / 1000);
	reg busy;
	reg doing_read;
	reg [7:0] temp_spi_bits;
	
	// the SPI pulses FSM
	always @(posedge clk) begin
		if (!rst_n || !busy) begin
			timer <= 0;
			spi_prev_pulse <= 1'b1;								// init prev to 1 so the first pass detects the edge if needed
			qpi_prev_pulse <= 1'b1;								// init prev to 1 so the first pass detects the edge if needed
		end else if (busy) begin
			timer <= timer + 1'b1;
			spi_prev_pulse <= spi_pulse;
			qpi_prev_pulse <= qpi_pulse;
		end
	end
	
	localparam
		STATE_INIT=0,
		STATE_SPI_SEND_8=1,
		STATE_IDLE=2,
		STATE_STORE_ADDR_1=3,
		STATE_STORE_ADDR_2=4,
		STATE_STORE_ADDR_3=5,
		STATE_SPI_SEND_2_WRITE=6,
		STATE_SPI_SEND_2_READ=7,
		STATE_SPI_READ_2=8,
		STATE_POST_WRITE=9,
		STATE_POST_READ=10,
		STATE_HANGUP=11,
		STATE_HANGUP_WAIT=12;

	assign cs_pin 		= ~busy;															// active low CS pin
	assign spi_pulse 	= timer[SPI_TIMER_BITS-1];											// SPI timed pulses
	assign qpi_pulse 	= timer[QPI_TIMER_BITS-1];											// QPI timed pulses
	assign sck_pin 		= busy & (state == STATE_SPI_SEND_8 ? spi_pulse : qpi_pulse);		// The SCK pin depending on if we're doing SPI or QPI traffic
	assign done			= (state == STATE_IDLE);											// 'done' is basically a "are we at idle" flag
	
	// assign data out
	always @(*) begin
		if (DATA_WIDTH == 32) begin
			case (read_data_be)
				4'b1111: data_out = send_data;
				4'b0011: data_out = {{(DATA_WIDTH-32){1'b0}}, 16'b0, send_data[31:16]};
				default: data_out = {{(DATA_WIDTH-32){1'b0}}, 24'b0, send_data[31:24]};
			endcase
		end else begin
			data_out = send_data;
		end
	end
	
	always @(posedge clk) begin
		if (!rst_n) begin
            state <= STATE_INIT;
            sio_en <= 4'b0000;									// disable all outputs
            dout <= 0;
            busy <= 0;
            send_address <= 0;
            send_data <= 0;
            send_cmd <= 0;
		end else begin
			case(state)
				STATE_INIT:
					begin
                        // sticking some STATE_INIT initializations here.
                        temp_spi_bits	<= CMD_EQIO;			// Send "enter quad mode IO" command
                        bit_cnt			<= 8;					// we use single bit SPI mode for this command
						state			<= STATE_SPI_SEND_8;	// Use single bit SEND state
						sio_en			<= 4'b0001;				// enable MOSI output pin SIO[0]
						busy			<= 1;					// start SPI clock
					end
				STATE_SPI_SEND_8:								// send 8 bits in temp_spi_bits (sio_en[0] = 1, bit_cnt = 8)	
					begin
						case(spi_pulse)
							1'd0:								// we put data on the line mid way through the first half cycle
								begin
									if (spi_prev_pulse != spi_pulse) begin			// we detect edges of the pulse so we only process the state once
										dout[0] <= temp_spi_bits[7];
									end
								end
							1'd1:							// Detect if we should exit this loop
								begin
									if (timer == ((1 << SPI_TIMER_BITS) - 1)) begin	// only move on the last system clock cycle of the SPI clock cycle
										bit_cnt <= bit_cnt - 1'b1;
										temp_spi_bits <= {temp_spi_bits[6:0], 1'b0};
										if (bit_cnt == 1) begin						// we stop at 1 since we execute first then check
											busy   <= 0;
											state  <= STATE_POST_WRITE;
										end
									end
								end
						endcase
					end
				STATE_SPI_SEND_2_WRITE:							// WRITE: Write the cmd + address + line in QPI mode
					begin
						if (qpi_prev_pulse != qpi_pulse) begin	// only run the case statement on the edge of the QPI clock pulse
							case(qpi_pulse)
								1'd0:							// we put data on the line in the first half cycle
									begin
`ifdef SIM_MODEL
/*
	if (fifo_rptr >= (1 + (SRAM_ADDR_WIDTH/8))) begin
		if (bit_cnt == 2) begin
			sim_memory[sim_address] <= {temp_bits[7:4], sim_memory[sim_address][3:0]};
		end else begin
			sim_memory[sim_address] <= {sim_memory[sim_address][7:4], temp_bits[7:4]};
			sim_address <= sim_address + 1'b1;
			$display("Wrote %2h to %4h", {sim_memory[sim_address][7:4], temp_bits[7:4]}, sim_address);
		end
	end
*/
`endif
										dout <= send_wire[nibble_idx +: 4];			// in quad mode we shift out the most significant nibble first
									end
								1'd1:												// Detect if we should exit from this loop
									begin
										// if there are more bytes to send ...
										nibble_idx  <= nibble_idx - 4;
										if (nibble_idx == 0) begin
											state			<= STATE_POST_WRITE;
											busy			<= 0;					// it was a write command so we're done
										end
									end
							endcase
						end
					end
				STATE_SPI_SEND_2_READ:							// READ: Write the cmd + address in QPI mode
					begin
						if (qpi_prev_pulse != qpi_pulse) begin	// only run the case statement on the edge of the QPI clock pulse
							case(qpi_pulse)
								1'd0:							// we put data on the line in the first half cycle
									begin
										dout <= read_wire[nibble_idx[$clog2(READ_SIZE)-1:0] +: 4];			// in quad mode we shift out the most significant nibble first
									end
								1'd1:							// Detect if we should exit from this loop
									begin
										// if there are more bytes to send ...
										nibble_idx  <= nibble_idx - 4;
										if (nibble_idx == 0) begin
											state			<= STATE_SPI_READ_2;					// jump to reading
											busy			<= 1;									// it was a READ command so we're not done yet
											dummy_nibbles   <= DUMMY_BYTES * 2;
											if (DATA_WIDTH == 32) begin
												case(read_data_be)
													4'b1111: // 32-bit operation
														begin
															nibble_idx      <= DATA_WIDTH - 4;		// start at the most significant nibble of the send_cmd byte
														end
													4'b0011: // 16-bit operation
														begin
															nibble_idx      <= DATA_WIDTH - 4 - 16;  // sub 4 so we can match without using a computed sub (sub 16 since we're only sending 16 bits out of 32)
														end
													default: // default to 8 bit
														begin
															nibble_idx      <= DATA_WIDTH - 4 - 24; // sub 4 so we can match without using a computed sub (sub 24 since we're only sending 8 bits out of 32)
														end
												endcase
											end else begin
												nibble_idx <= DATA_WIDTH - 4;
											end
										end
									end
							endcase
						end
					end
				STATE_SPI_READ_2:							// read from the SPI SRAM upto DUMMY_READ + read_cmd_size bytes
					begin
						if (qpi_prev_pulse != qpi_pulse) begin
							case(qpi_pulse)
								1'd0:
									begin
										sio_en <= 4'b0000;		// disable all four outputs
									end
								1'd1:							// we sample during the 2nd half of the cycle
									begin
`ifdef SIM_MODEL
/*
	if (sim_dummy == 0) begin
		if (bit_cnt == 2) begin
			temp_bits <= {4'b0, sim_memory[sim_address][7:4]};
		end else begin
			temp_bits <= {temp_bits[3:0], sim_memory[sim_address][3:0]};
			sim_address <= sim_address + 1'b1;
			$display("We read %2h from %4h", {temp_bits[3:0], sim_memory[sim_address][3:0]}, sim_address);
		end
	end else begin
		$display("dummy == %d", sim_dummy);
		sim_dummy <= sim_dummy - 1'b1;
	end
*/
`else
										send_data[nibble_idx[$clog2(DATA_WIDTH)-1:0] +: 4] <= din; // store nibble
`endif
										// write next byte we read out, this starts just after the cmd and address 
										if (dummy_nibbles == 0) begin
											nibble_idx <= nibble_idx - 4;
										end else begin
											dummy_nibbles <= dummy_nibbles - 1;
										end
										if (nibble_idx == 0) begin
											state <= STATE_POST_READ;
											busy  <= 0;
										end
									end
							endcase
						end
					end
				STATE_IDLE:																	// IDLE state, we look for data_in_valid, write_cmd, read_cmd here
					begin
						if (data_in_valid) begin
							if (DATA_WIDTH == 32) begin
								case(data_be)
									4'b1111: // 32-bit operation
										begin
											send_data 		<= data_in;
										end
									4'b0011: // 16-bit operation
										begin
											send_data 		<= { data_in[15:0], 16'b0, {(DATA_WIDTH-32){1'b0}} };
										end
									default: // default to 8 bit
										begin
											send_data		<= { data_in[7:0], 24'b0, {(DATA_WIDTH-32){1'b0}} };
										end
								endcase
							end else begin
								send_data 		<= data_in;
							end
						end
						
						if (write_cmd | read_cmd) begin																// user wants to issue a read or write so we prepare the SPI write (command + address + optional payload)
							sio_en 			<= 4'b1111;																// enable all 4 outputs
							send_cmd 		<= (write_cmd == 1) ? CMD_WRITE : CMD_READ;								// the SPI command we need
							send_address	<= address;																// latch the address
							state			<= (write_cmd == 1) ? STATE_SPI_SEND_2_WRITE : STATE_SPI_SEND_2_READ;	// jump to state relevant to the operation requested
							busy 			<= 1;																	// we're going to be busy in the next cycle
							read_data_be	<= data_be;																// latch the data_be so we can use it during reads
							if (write_cmd) begin
								if (DATA_WIDTH == 32) begin
									case(data_be)
										4'b1111: // 32-bit operation
											begin
												nibble_idx      <= SEND_SIZE - 4;		// start at the most significant nibble of the send_cmd byte
											end
										4'b0011: // 16-bit operation
											begin
												nibble_idx      <= SEND_SIZE - 4 - 16;  // sub 4 so we can match without using a computed sub (sub 16 since we're only sending 16 bits out of 32)
											end
										default: // default to 8 bit
											begin
												nibble_idx      <= SEND_SIZE - 4 - 24; // sub 4 so we can match without using a computed sub (sub 24 since we're only sending 8 bits out of 32)
											end
									endcase
								end else begin
									nibble_idx <= SEND_SIZE - 4;
								end
							end else begin
								// read commands are just the cmd + address
								nibble_idx <= 8 + SRAM_ADDR_WIDTH - 4;
							end
                        `ifdef SIM_MODEL
                            sim_dummy <= DUMMY_BYTES[7:0] * 2;
                            sim_address <= address[15:0];
                        `endif
						end
					end
				STATE_POST_WRITE: // after a write command
					begin
						sio_en    		<= 4'b0000;						// disable outputs
						state 	  		<= STATE_HANGUP;
					end
				STATE_POST_READ: // after a read command
					begin
						state		  	<= STATE_HANGUP;
					end
				STATE_HANGUP:		// hang up the SPI connection
					begin
						hangup_timer	<= hangup_bauddiv[7:0]; // ensure we hit the required MIN_CPH_NS time (round up for safety)
						state			<= STATE_HANGUP_WAIT;
					end
				STATE_HANGUP_WAIT:
					begin
						hangup_timer 	<= hangup_timer - 1'b1;
						if (hangup_timer == 0) begin
							state <= STATE_IDLE;
						end
					end
				default:
					begin
					end
			endcase
		end
	end
endmodule
