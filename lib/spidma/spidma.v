`timescale 1ns/1ps
`default_nettype none

/* NOR flash notes for later....

- need to test QE bit first (SR2 on BYTe (35h), SR on Macronix (05h))
- if it's not set we need to
   - enable writing to non-volatile status reg (50h)
   - write status/config (BYTe == 31h, Macronix == 01h)
- Need to leave "performance enhancing bytes" set to 00h in reads which means we need sio_en = 4'b1111, sio_dout = 4'b0000 so
as to not accidentally turn on XIP
- "Fast reads" EBh seems to be consistent (e.g. CMD + ADDR + 6 dummy cycles)
- "quad page program" 
	- BYTe: 32h, sends CMD + address in SPI mode
	- Macronix: 38h, sends CMD in SPI mode, sends address + data in QPI mode  
- sector erase
	- BYTe: 20h, uses SPI for CMD + ADDRESS
	- Macronix: 20h, can operate fully in SPI or QPI mode
	
Deltas between the two brands I have in stock (Macronix and BYTe) for 8-pin SPI NOR flashes

- Where the QE bit is stored (SR2 vs SR)
- The command to write it (31h vs 01h)
- quad page programming (command 32h v 38h) and command stream format
- sector erase: only in SPI on BYTe

Likely target to not go full on mad:

- SPI only
- 01h write status reg
- 05h read status reg (WEL and WIP bits are in the same spot)
- 06h write enable
- 20h sector erase
- 02h page program
- 03h read data

*/

// writes take 7 + DUMMY_CYCLES + (1 + SRAM_ADDR_WIDTH/8 + BURST_LEN + 1) * (2 * (1 + QPI_TIMER_BITS) + 1) cycles
// reads take 7 + (1 + SRAM_ADDR_WIDTH/8 + BURST_LEN + 1) * (2 * (1 + QPI_TIMER_BITS) + 1) cycles

// cmd_read == read from SPI memory, write to host memory
// cmd_write == write to SPI memory, read from host memory
`define spidma_cmd_read 4'h0
`define spidma_cmd_write 4'h1

module spidma #(
	// Timing
	parameter CLK_FREQ_MHZ    = 27,							// system clock frequency (required for walltime requirements)
	
	// Host Side Memory
	parameter HOST_MEM_ADDR   = 11,							// default to typical 2048x8 memories common to most 18kBit DPRAM blocks

	// MEMORY default configuration for a typical 8-pin SPI PSRAM
	parameter SRAM_ADDR_WIDTH = 24,							// how many bits does the address have (e.g. 16 or 24)
	parameter DUMMY_CYCLES    = 6,							// how many dummy reads are required before the first byte is valid
	parameter CMD_READ        = 8'hEB,						// command to read 
	parameter CMD_WRITE       = 8'h38,						// command to write
	parameter CMD_EQIO        = 8'h35,						// command to enter quad IO mode
	parameter CMD_RESETEN     = 8'h66,						// command to enable reset
	parameter CMD_RESET       = 8'h99,						// command to reset
	parameter MIN_CPH_NS      = 50,							// how many ns must CS be high between commands (23LC's have a min time of mostly nothing)
	parameter MIN_WAKEUP_NS   = 150_000,					// how many ns to wait for it to wakeup after POR
	parameter SPI_TIMER_BITS  = 4,							// divide clock by X for SPI operations
	parameter QPI_TIMER_BITS  = 1,							// divide clock by X for QPI operations
	parameter PSRAM_RESET     = 1							// do you need to send 66 99 to reset required by PSRAM chips?
)(
	input wire clk,											// clock
	input wire rst_n,										// active low reset

	// BUS
	output reg ready,										// active high means the module is done with a request
	
	// Host side memory
	output reg [HOST_MEM_ADDR-1:0] host_mem_addr,			// address to read/write to from host memory
	output reg host_mem_wr_en,								// write enable
	output reg [7:0] host_mem_data_in,						// data to write to host mem
	input  wire [7:0] host_mem_data_out,					// data read from host mem
	
	// Command data
	input wire [3:0] cmd_value,								// what command to run (read, write, ...)
	input wire cmd_valid,									// active high when all cmd signals are valid
	input wire [SRAM_ADDR_WIDTH-1:0] cmd_spi_address,		// address to read/write from the SPI device
	input wire [HOST_MEM_ADDR-1:0] cmd_host_address,		// address to write/read from the host memory
	input wire [7:0] cmd_burst_len,							// how many bytes to read (1..256)

	// I/O
	input wire [3:0] sio_din,
	output reg [3:0] sio_dout,
	output reg [3:0] sio_en,
	output reg cs_pin,										// active low CS pin
	output reg sck_pin										// SPI clock
);
`ifdef SIM_MODEL
	reg [3:0] sim_memory[(1<<(SRAM_ADDR_WIDTH+1))-1:0];		// 4-bit memory to store QPI data only
	reg [SRAM_ADDR_WIDTH:0] sim_address;					// byte address (we use bit_cnt to select the nibble)
	reg sim_wr_en;											// are writes enabled at this point? (skip over cmd/address)
`endif

	// fsm related
	reg [4:0] state;										// What state is our FSM in
	reg [4:0] tag;
	reg [2:0] send_cmd_addr_cycle;							// counter to tell which step of sending CMD + ADDR we're on
	reg [3:0] dummy_cnt;									// how many dummy cycles to waste

	// transfer related
	reg [3:0] bit_cnt;										// bit counter a variety of FSM states
	reg [3:0] sck_timer;									// timer used to know when to change phase
	reg [7:0] temp_wire_bits;
	
	// hangup/wakeup related
	reg [20:0] hangup_timer;
	wire [20:0] hangup_bauddiv = ((CLK_FREQ_MHZ * MIN_CPH_NS + 999) / 1000);
	wire [20:0] wakeup_bauddiv = ((CLK_FREQ_MHZ * MIN_WAKEUP_NS + 999) / 1000);
	
	// Command data
	reg [3:0] cmd_value_l;								// what command to run (read, write, ...)
	reg [SRAM_ADDR_WIDTH-1:0] cmd_spi_address_l;		// address to read/write from the SPI device
	reg [HOST_MEM_ADDR-1:0] cmd_host_address_l;			// address to write/read from the host memory
	reg [7:0] cmd_burst_len_l;							// how many bytes to read (1..256)
	
	localparam
		STATE_INIT					= 0,													// Initialize the SPI memory by putting into a quad-io mode
		STATE_INIT_DONE				= 1,													
		STATE_SEND_RESETEN			= 2,													// enable RESET
		STATE_SEND_RESETEN_DONE		= 3,
		STATE_SEND_RESET			= 4,													// issue RESET command
		STATE_SEND_RESET_DONE		= 5,
		STATE_SPI_SHIFT_8			= 6,													// Send a command in 1-bit SPI mode
		STATE_QPI_SEND_2			= 7,
		STATE_QPI_RECV_2			= 8,
		STATE_IDLE					= 9,													// Idle state waiting for a command
		STATE_QPI_SEND_CMD_ADDR     = 10,
		STATE_START_READ			= 11,
		STATE_START_WRITE			= 12,
		STATE_DONE_WRITE            = 13,
		STATE_DONE					= 14,
		STATE_HANGUP				= 15,													// Hang up SPI bus
		STATE_HANGUP_WAIT			= 16;													// hold CS high for a count

	always @(posedge clk) begin
		if (!rst_n) begin
            state			    <= STATE_HANGUP_WAIT;						// Jump to initial FSM state
            tag				    <= PSRAM_RESET == 1 ? STATE_SEND_RESETEN : STATE_INIT;
            hangup_timer        <= wakeup_bauddiv;
            sck_timer			<= 0;
            sio_en			    <= 4'b0000;									// disable all outputs
            sio_dout		    <= 4'b1111;									// SPI bus output
            sck_pin			    <= 1'b0;									// default low
            cs_pin			    <= 1'b1;									// default high
            temp_wire_bits      <= 8'h00;
            bit_cnt			    <= 4'h0;
            cmd_value_l         <= 0;
            cmd_burst_len_l     <= 0;
            cmd_host_address_l  <= 0;
            cmd_spi_address_l   <= 0;
            send_cmd_addr_cycle <= 0;
            dummy_cnt           <= 0;
            host_mem_addr		<= 0;
            host_mem_wr_en		<= 0;
            host_mem_data_in	<= 0;
            ready				<= 0;
		end else begin
			case(state)
				STATE_SEND_RESETEN:										// Send 0x66 RESET ENABLE
					begin
						temp_wire_bits	<= CMD_RESETEN;
						bit_cnt			<= 7;
						state			<= STATE_SPI_SHIFT_8;
						tag				<= STATE_SEND_RESETEN_DONE;
						sio_en			<= 4'b0001;						// enable MOSI output pin SIO[0]
						sck_timer		<= SPI_TIMER_BITS;
					end
				STATE_SEND_RESETEN_DONE:								// done sending 0x66 RESET ENABLE, hangup and then issue RESET
					begin
						state			<= STATE_HANGUP;
						tag				<= STATE_SEND_RESET;
					end

				STATE_SEND_RESET:										// Send 0x99 RESET 
					begin
						temp_wire_bits	<= CMD_RESET;
						state			<= STATE_SPI_SHIFT_8;
						tag				<= STATE_SEND_RESET_DONE;
						sio_en			<= 4'b0001;						// enable MOSI output pin SIO[0]
					end
				STATE_SEND_RESET_DONE:								    // done sending 0x66 RESET ENABLE, hangup and then issue RESET
					begin
						state			<= STATE_HANGUP;
						tag				<= STATE_INIT;
					end

				STATE_INIT:												// send enter Quad I/O command
					begin
                        // sticking some STATE_INIT initializations here.
                        temp_wire_bits	<= CMD_EQIO;					// Send "enter quad mode IO" command
						state			<= STATE_SPI_SHIFT_8;			// Use single bit SEND state
						tag				<= STATE_INIT_DONE;
						sio_en			<= 4'b0001;						// enable MOSI output pin SIO[0]
					end
				STATE_INIT_DONE:
					begin
						state			<= STATE_HANGUP;
						tag				<= STATE_IDLE;
					end

				/* STATE_SPI_SHIFT_8:
					in: sio_en = 4'b0001, bit_cnt = 7, sck_timer = SPI_TIMER_BITS, temp_wire_bits = data to shift out MOSI
					out: bit_cnt = 7, sck_timer = SPI_TIMER_BITS, temp_wire_bits = data shifted in MISO
				*/
				STATE_SPI_SHIFT_8:										// shift 8 bits in/out temp_spi_bits (sio_en[0] = 1, bit_cnt = 7)	
					begin
						cs_pin <= 1'b0;									// default CS low 
						case(sck_pin)
							1'd0:										// SCK low phase, put data on wire
								begin
									// write during low
									sio_dout[0] <= temp_wire_bits[7];
									if (sck_timer == 0) begin
										sck_timer      <= SPI_TIMER_BITS;					 // time to switch to SCK high
										sck_pin        <= ~sck_pin;
										temp_wire_bits <= {temp_wire_bits[6:0], sio_din[1]}; // shift wire bits, and insert MISO bit
									end else begin
										sck_timer <= sck_timer - 1'b1;
									end
								end
							1'd1:										// SCK high phase, keep data steady, move to next bit at end of phase
								begin
									if (sck_timer == 0) begin
										bit_cnt        <= bit_cnt - 1'b1;
										sck_pin        <= ~sck_pin;							// set SCK to low for either the next bit of this transaction or the start of the next transaction
										sck_timer      <= SPI_TIMER_BITS;					// reset timer in case we chain SEND_8's
										if (bit_cnt == 0) begin
											bit_cnt    <= 7;								// reset bit count in case we chain SEND_8's
											state      <= tag;
										end
									end else begin
										sck_timer <= sck_timer - 1'b1;
									end
								end
						endcase
					end
					
				/* STATE_QPI_SEND_2:
					in: sio_en = 4'b1111, bit_cnt = 1, sck_timer = QPI_TIMER_BITS, temp_wire_bits = data to shift out SIO[3:0]
					out: bit_cnt = 1, sck_timer = QPI_TIMER_BITS, temp_wire_bits = 0
				*/
				STATE_QPI_SEND_2:
					begin
						cs_pin <= 1'b0;
						case(sck_pin)
							1'b0:														// shift data out during SCK low phase
								begin
									sio_dout <= temp_wire_bits[7:4];
`ifdef SIM_MODEL
									if (sim_wr_en) begin
										sim_memory[sim_address + bit_cnt[0]] <= temp_wire_bits[7:4] & sio_en;
									end
`endif

									if (sck_timer == 0) begin
										sck_timer      <= QPI_TIMER_BITS;
										sck_pin        <= ~sck_pin;
										temp_wire_bits <= {temp_wire_bits[3:0], 4'b0};
									end else begin
										sck_timer      <= sck_timer - 1'b1;
									end
								end
							1'b1:														// hold stable during the SCK high phase
								begin
									if (sck_timer == 0) begin
										bit_cnt	  <= bit_cnt - 1'b1;
										sck_pin   <= ~sck_pin;
										sck_timer <= QPI_TIMER_BITS;
										if (bit_cnt == 0) begin
											bit_cnt <= 1;
											state   <= tag;
`ifdef SIM_MODEL
											if (sim_wr_en) begin
												sim_address <= sim_address + 2;
											end
`endif
										end
									end else begin
										sck_timer <= sck_timer - 1'b1;
									end
								end
						endcase
					end

				/* STATE_QPI_RECV_2:
					in: sio_en = 4'b0000, bit_cnt = 1, sck_timer = QPI_TIMER_BITS, temp_wire_bits = X
					out: bit_cnt = 1, sck_timer = QPI_TIMER_BITS, temp_wire_bits = data shifted in over SIO[3:0]
				*/
				STATE_QPI_RECV_2:
					begin
						host_mem_wr_en <= 1'b0;											// ensure host write is turned off now
						cs_pin 		   <= 1'b0;											// ensure CS is low
						case(sck_pin)
							1'b0:														// shift data in during SCK low phase
								begin
									if (sck_timer == 0) begin
										sck_timer      <= QPI_TIMER_BITS;
										sck_pin        <= ~sck_pin;
`ifdef SIM_MODEL
										temp_wire_bits <= {temp_wire_bits[3:0], sim_memory[sim_address + bit_cnt[0]] & ~sio_en};
`else
										temp_wire_bits <= {temp_wire_bits[3:0], sio_din};
`endif
									end else begin
										sck_timer      <= sck_timer - 1'b1;
									end
								end
							1'b1:														// hold stable during the SCK high phase
								begin
									if (sck_timer == 0) begin
										bit_cnt	  <= bit_cnt - 1'b1;
										sck_pin   <= ~sck_pin;
										sck_timer <= QPI_TIMER_BITS;
										if (bit_cnt == 0) begin
											bit_cnt <= 1;
											state   <= tag;
`ifdef SIM_MODEL
											sim_address <= sim_address + 2;
`endif
										end
									end else begin
										sck_timer <= sck_timer - 1'b1;
									end
								end
						endcase
					end

				// IDLE waiting for cmd_valid
				STATE_IDLE:
					begin
						if (cmd_valid) begin
							// ensure cs_pin drops before SCK goes high
							cs_pin  <= 1'b0;
							sck_pin <= 1'b0;
							
							// latch the command
							cmd_value_l         <= cmd_value;
							cmd_spi_address_l   <= cmd_spi_address;
							cmd_host_address_l  <= cmd_host_address;
							cmd_burst_len_l     <= cmd_burst_len;
							
							// init the host memory address (this also gets the first read primed
							host_mem_addr       <= cmd_host_address;
							
							// init params for other states
							send_cmd_addr_cycle <= 0;
							if (DUMMY_CYCLES == 0) begin
								// with DUMMY_CYCLES==0 we signal cnt==1 to prime the initial read
								dummy_cnt       <= 1;
							end else begin
								dummy_cnt       <= DUMMY_CYCLES + DUMMY_CYCLES;			// x2 because a cycle is both SCK LOW and HIGH phases...
							end

`ifdef SIM_MODEL
							sim_address <= cmd_spi_address << 1;
							sim_wr_en   <= 1'b0;
`endif
					
							// branch to the next state
							case(cmd_value)
								`spidma_cmd_read:  state <= STATE_QPI_SEND_CMD_ADDR;
								`spidma_cmd_write: state <= STATE_QPI_SEND_CMD_ADDR;
								default:
									begin
										// invalid cmd_value so just hangup
										tag   <= STATE_DONE;
										state <= STATE_HANGUP;
									end
							endcase
						end
					end

				// send the command and address
				// in: send_cmd_addr_cycle == 0, cmd_value_l == READ/WRITE/etc, cmd_spi_address_l == address
				STATE_QPI_SEND_CMD_ADDR:
					begin
						// configure I/O
						sio_en  <= 4'b1111;
						bit_cnt <= 1;

						// setup QPI send
						send_cmd_addr_cycle <= send_cmd_addr_cycle + 1'b1;
						state               <= STATE_QPI_SEND_2;
						tag                 <= state;
						if (send_cmd_addr_cycle == 0) begin
							// write the command byte
							case (cmd_value)
								`spidma_cmd_read:  
									begin
										temp_wire_bits <= CMD_READ;
										host_mem_addr  <= host_mem_addr - 1'b1;			// subtract one so we can have a simpler loop in READ loop
									end
								`spidma_cmd_write: 
									begin
										temp_wire_bits <= CMD_WRITE;
									end
								default:
									begin
										// invalid cmd_value so just hangup
										tag   <= STATE_DONE;
										state <= STATE_HANGUP;
									end
							endcase
						end else begin
							// send parts of the address
							temp_wire_bits <= cmd_spi_address_l[SRAM_ADDR_WIDTH-(8*send_cmd_addr_cycle) +: 8];
/* verilator lint_off WIDTHEXPAND */
							if (send_cmd_addr_cycle == SRAM_ADDR_WIDTH/8) begin
/* verilator lint_on WIDTHEXPAND */
								// last byte of address we tag out to READ/WRITE/etc operations instead of coming back here
								case(cmd_value)
									`spidma_cmd_read:  tag <= STATE_START_READ;
									`spidma_cmd_write: tag <= STATE_START_WRITE;
									default:
										begin
											// shouldn't get here but if we do hangup gracefully
											tag   <= STATE_DONE;
											state <= STATE_HANGUP;
										end
								endcase
							end
						end
					end

				/* STATE_START_READ: Start and process a generic read command after the CMD+ADDRESS was sent
				   In: dummy_cnt = 2 * # of cycles to wait, host_mem_addr = address to write to - 1, cmd_burst_len_l = bytes to read - 1
				   out: dummy_cnt = 0, host_mem_addr = last written address, cmd_burst_len_l = 0
				*/
				STATE_START_READ:
					begin
						sio_dout <= 4'b0000;	// ensure SIO[3:0] is 0 during any dummy cycles
						if (DUMMY_CYCLES == 0 && dummy_cnt == 1) begin
							// this is the state we get into when there's no dummy wait cycles but we need to prime temp_wire_bits...
							dummy_cnt <= 0;
							sio_en    <= 4'b0000;
							state     <= STATE_QPI_RECV_2;
							tag       <= state;
						end else if (dummy_cnt > 0) begin
							// waiting for dummy cycles
							if (sck_timer == 0) begin
								dummy_cnt  <= dummy_cnt - 1'b1;
								sck_pin    <= ~sck_pin;
								sck_timer  <= QPI_TIMER_BITS;
								if (dummy_cnt == 1) begin
									// issue first QPI read
									sio_en    <= 4'b0000;
									state     <= STATE_QPI_RECV_2;
									tag       <= state;
								end
							end else begin
								sck_timer  <= sck_timer - 1'b1;
							end
						end else begin
							// we're now in the reading from SPI memory phase
							// by time we get here we've read at least the first byte from SPI
							host_mem_data_in <= temp_wire_bits;
							host_mem_wr_en   <= 1'b1;
							host_mem_addr    <= host_mem_addr + 1'b1;						// note: we previously subtracted 1 to start the loop
							if (cmd_burst_len_l == 0) begin
								// end of burst so hangup and then hit wait state
								state <= STATE_HANGUP;
								tag   <= STATE_DONE;
							end else begin
								cmd_burst_len_l <= cmd_burst_len_l - 1'b1;
								state <= STATE_QPI_RECV_2;
								tag   <= state;
							end
						end
					end

				/* STATE_START_WRITE: Start process to read from host and write to SPI
					in: host_mem_addr = address to read from, cmd_burst_len_l = bytes to read - 1
					out: host_mem_addr = +1 end of read, cmd_burst_len_l = 0;
				*/
				STATE_START_WRITE:
					begin
`ifdef SIM_MODEL
						sim_wr_en      <= 1'b1;							// at this point any SEND_2's are going to memory
`endif
						temp_wire_bits <= host_mem_data_out;
						state		   <= STATE_QPI_SEND_2;
						tag			   <= state;
						host_mem_addr  <= host_mem_addr + 1'b1;
						if (cmd_burst_len_l == 0) begin
							tag <= STATE_DONE_WRITE;
						end else begin
							cmd_burst_len_l <= cmd_burst_len_l - 1'b1;
						end
					end
				// we're done writing so hang up
				// (this is needed so we can give STATE_HANGUP a valid tag ... if we used tag==STATE_HANGUP above
				// it would just endlessly jump to itself
				STATE_DONE_WRITE:
					begin
						state <= STATE_HANGUP;
						tag   <= STATE_DONE;
					end

				// done, signal ready, wait for valid to drop (note: you can signal ready in the previous cycle to save time)
				// for now we signal ready here because if the user deasserts/reasserts valid before we get here we'll never
				// reset to IDLE
				STATE_DONE:
					begin
						ready <= 1'b1;
						if (!cmd_valid) begin
							ready <= 1'b0;
							state <= STATE_IDLE;
						end
					end

				// initiate hangup process by resetting IO pins, turn off host write, setup hangup timer
				STATE_HANGUP:																// hang up the SPI connection
					begin
						host_mem_wr_en	<= 1'b0;											// ensure host memory write is off
						hangup_timer	<= hangup_bauddiv;		 							// ensure we hit the required MIN_CPH_NS time (round up for safety)
						state			<= STATE_HANGUP_WAIT;
						cs_pin		    <= 1'b1;											// reset CS to default of high
						sck_pin			<= 1'b0;											// reset SCK to default of low
						sio_en    		<= 4'b0000;											// disable outputs
						sio_dout		<= 4'b1111;
					end

				// hangup wait loop, used to ensure there's a required delay beween CS lows
				STATE_HANGUP_WAIT:															// Hangup and hold CS high for a mandatory period
					begin
						hangup_timer 	<= hangup_timer - 1'b1;
						if (hangup_timer == 0) begin
							state <= tag;													// Resume next state
						end
					end

				// if we end up here we really need to stop and ask for directions...
				default:
					if (cmd_valid) begin
						// invalid cmd_value so just hangup
						tag   <= STATE_DONE;
						state <= STATE_HANGUP;
					end
			endcase
		end
	end
endmodule
