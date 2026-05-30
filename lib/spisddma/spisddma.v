/* SPI SD DMA Block

 Faciliates transfering memory between SPI SD cards and host synchronous memories.

			┌──────────────────┐                 ┌─────────────────┐          ┌──────────────────┐
			│                  │                 │                 │  cs/sck  │                  │
			│                  ├────────────────►│                 ├─────────►│                  │
			│   Host Memory    │   host_mem_*    │                 │   sio_*  │      SPI SD      │
			│                  │◄────────────────┤                 │◄────────►┤                  │
			│                  │                 │     SPI DMA     │          │                  │
			└──────────┬───────┘                 │                 │          └──────────────────┘
					▲  │                         │                 │                              
					│  │                         │                 │                              
					│  │                         │                 │                              
					│  ▼                         └──────────┬──────┘                              
			┌───────┴──────────┐                       ▲    │                                     
			│                  │    cmd_*              │    │                                     
			│                  ├───────────────────────┘    │                                     
			│  SPI DMA Driver  │                            │                                     
			│                  │◄───────────────────────────┘                                     
			│                  │    ready                                                         
			└──────────────────┘                                                                  

*/

`timescale 1ns/1ps
`default_nettype none

`include "spisddma.vh"

module spisddma #(
	// Host Side Memory
	parameter HOST_MEM_ADDR   = 11,							// default to typical 2048x8 memories common to most 18kBit DPRAM blocks

	// Timing parameters
	parameter CLK_FREQ_MHZ    = 50							// Clock rate of module
)(
	input wire clk,											// clock
	input wire rst_n,										// active low reset

	// BUS
	output reg ready,										// active high means the module is done with a request
	output reg [1:0] error,									// error codes (0 == ok)
	
	// CARD info
	output reg card_is_sdsc,
	output reg card_is_init,
	
	// Host side memory
	output reg [HOST_MEM_ADDR-1:0] host_mem_addr,			// address to read/write to from host memory
	output reg host_mem_wr_en,								// write enable
	output reg [7:0] host_mem_data_in,						// data to write to host mem
	input  wire [7:0] host_mem_data_out,					// data read from host mem
	
	// Command data
	input wire cmd_wr_en,									// what command to run (read, write, ...)
	input wire cmd_valid,									// active high when all cmd signals are valid
	input wire [31:0] cmd_sector,							// 512-byte sector to access
	input wire [HOST_MEM_ADDR-1:0] cmd_host_address,		// address to write/read from the host memory

	// I/O
	input wire miso_pin,
	output reg mosi_pin,
	output reg sck_pin,
	output reg cs_pin
);

	// Slow (100KHz) and Fast (24 MHz) clocks
	localparam
		SLOW_CLKDIV     = ((CLK_FREQ_MHZ * 500_000) / 100_000) - 1,			// ((clk / 2) / 100_000) - 1
		FAST_CLKDIV     = ((CLK_FREQ_MHZ * 500_000) / 24_000_000) - 1;		// ((clk / 2) / 24_000_000) - 1

	// fsm related
	reg [4:0] state;										// What state is our FSM in
	reg [4:0] tag;
	reg [4:0] cmd_tag;
	reg 	  fst_clk;										// 1 == use FAST_CLKDIV
	reg [3:0] state_step;

	// transfer related
	reg [3:0]   bit_cnt;									// bit counter a variety of FSM states
	wire [3:0]  bit_cnt_orig;
	reg [$clog2(SLOW_CLKDIV):0]  sck_timer;					// timer used to know when to change phase
	wire [$clog2(SLOW_CLKDIV):0] sck_timer_orig;
	reg [25:0]  sck_cycles;
	wire [25:0] timeout;
	reg [7:0]   temp_wire_bits;
	reg         shift8_cs_exit;								// some commands require CS to go high immediately
	
	// Command data
	reg 	   cmd_wr_en_l;									// what command to run (read, write, ...)
	reg [31:0] cmd_sector_l;								// address to read/write from the SPI device
	reg [8:0]  cmd_pos;										// position in sector we're reading
	
	// SPI CMD data
	reg [7:0]   spi_cmd_opcode;
	reg [31:0]  spi_cmd_payload;
	reg [7:0]   spi_cmd_crc;
	wire [47:0] spi_cmd_block;
	reg [7:0]   spi_cmd58_byte0;
	
	assign bit_cnt_orig   = 7;
	assign timeout        = fst_clk ? 25_000_000 : 100_000;
	assign sck_timer_orig = ($clog2(SLOW_CLKDIV)+1)'(fst_clk ? FAST_CLKDIV : SLOW_CLKDIV);
	assign spi_cmd_block  = { spi_cmd_opcode, spi_cmd_payload, spi_cmd_crc };
	
	localparam
		STATE_INIT_SPI				= 0,		// Initial SPI init command 
		STATE_INIT_CMD0				= 1,		// Send CMD0
		STATE_INIT_CMD0_R1			= 2,		// Process R1 for CMD0
		STATE_INIT_CMD8_R1			= 3,		// process R1 for CMD8
		STATE_INIT_CMD8_READ		= 4,		// Read 32-bits from CMD8
		STATE_INIT_CMD55			= 5,		// Send CMD55
		STATE_INIT_CMD55_R1			= 6,		// Process R1 for CMD55
		STATE_INIT_ACMD41_R1		= 7,		// Process R1 for ACMD41
		STATE_INIT_CMD58			= 8,		// Send CMD58
		STATE_INIT_CMD58_R1			= 9,		// Process R1 from CMD58
		STATE_INIT_CMD58_READ		= 10,		// Read 32-bits from CMD58
		STATE_INIT_CMD16			= 11,		// Send CMD16
		STATE_INIT_CMD16_R1			= 12,		// Process R1 from CMD16
		STATE_INIT_DONE				= 13,		// Initialization done
		STATE_SEND_CMD				= 14,
		STATE_READ_R1				= 15,
		STATE_SHIFT_DATA			= 16,
		STATE_IDLE					= 17,
		STATE_DONE 					= 18,
		STATE_WAIT_VALID_LOW        = 19,
		STATE_START_WRITE_RESP		= 20,
		STATE_START_READ_RESP		= 21,
		STATE_WAIT_TOKEN			= 22,
		STATE_WRITE_SHIFT			= 23,
		STATE_WRITE_CRC				= 24,
		STATE_WRITE_BLOCK_RESP		= 25,
		STATE_READ_SHIFT			= 26,
		STATE_READ_CRC				= 27,
		STATE_WRITE_TOKEN			= 28,
		STATE_WRITE_WAIT		    = 29;

	always @(posedge clk) begin
		if (!rst_n) begin
            state			    <= STATE_INIT_SPI;							// Jump to initial FSM state
            tag				    <= 0;
            sck_timer			<= 0;
			mosi_pin			<= 1'b1;
            sck_pin			    <= 1'b0;									// default low
            cs_pin			    <= 1'b1;									// default high
            temp_wire_bits      <= 8'h00;
            bit_cnt			    <= 4'h0;
			error				<= `SPISD_ERR_OK;
			card_is_init		<= 1'b0;
			state_step 			<= 0;

			// shared reset/init_spi nets
			cmd_wr_en_l         <= 0;
			cmd_sector_l 	    <= 0;
			host_mem_addr		<= 0;
			host_mem_wr_en		<= 0;
			host_mem_data_in	<= 0;
			ready				<= 0;
			shift8_cs_exit		<= 0;
			spi_cmd_opcode		<= 0;
			spi_cmd_payload     <= 0;
			spi_cmd_crc 		<= 0;
			card_is_init		<= 1'b0;
			card_is_sdsc		<= 1'b0;
			fst_clk				<= 1'b0;			
		end else begin
			case(state)
				// this performs a partial reset of the module, then sends 8 'FFs with the CS pin high
				STATE_INIT_SPI:
					begin
						if (!cmd_valid) begin
							// wait for host to drop valid if there's an error 
							cmd_wr_en_l         <= 0;
							cmd_sector_l 	    <= 0;
							host_mem_addr		<= 0;
							host_mem_wr_en		<= 0;
							host_mem_data_in	<= 0;
							ready				<= 0;
							shift8_cs_exit		<= 0;
							spi_cmd_opcode		<= 0;
							spi_cmd_payload     <= 0;
							spi_cmd_crc 		<= 0;
							card_is_init		<= 1'b0;
							card_is_sdsc		<= 1'b0;
							fst_clk				<= 1'b0;

							// send 8 FF's with CS high
							sck_cycles	   		<= 0;
							cs_pin         		<= 1'b1;
							state_step     		<= (state_step == 9) ? 0 : (state_step + 1'b1);
							temp_wire_bits 		<= 8'hFF;
							bit_cnt 	   		<= bit_cnt_orig;
							sck_timer 	   		<= ($clog2(SLOW_CLKDIV)+1)'(SLOW_CLKDIV);
							state          		<= STATE_SHIFT_DATA;
							tag            		<= (state_step == 9) ? STATE_INIT_CMD0 : STATE_INIT_SPI;
						end
					end
				
				// Send the initial CMD0 to see if we're in SPI mode
				STATE_INIT_CMD0:
					begin
						// send a CMD0
						cs_pin			<= 1'b0;
						sck_pin 		<= 1'b0;
						spi_cmd_opcode  <= 8'h40;
						spi_cmd_payload <= 32'b0;
						spi_cmd_crc     <= 8'h95;
						cmd_tag			<= STATE_INIT_CMD0_R1;
						state		    <= STATE_SEND_CMD;
					end
					
				// process the R1, should get 01 (in idle state) back if not we're not in SPI mode
				STATE_INIT_CMD0_R1:
					begin
						if (temp_wire_bits != 8'h01) begin
							// not in idle state try again (TODO: with delay...)
							state 			<= STATE_INIT_SPI;
						end else begin
							// Got idle state, send CMD8(0x1AA) CRC: 0x87, this command checks if we have a v2 card
							spi_cmd_opcode  <= 8'h48;
							spi_cmd_payload <= 32'h1AA;
							spi_cmd_crc     <= 8'h87; // TODO: check this
							state           <= STATE_SEND_CMD;
							cmd_tag         <= STATE_INIT_CMD8_R1;
						end
					end
				
				// process CMD8 R1, a 04h indicates an opcode error (v1 card), otherwise if idle read the OCR payload
				STATE_INIT_CMD8_R1:
					begin
						if ((temp_wire_bits & 8'h04) == 8'h04) begin
							card_is_sdsc <= 1'b1;
							state 		 <= STATE_INIT_CMD55;
						end else begin
							if (temp_wire_bits == 8'h01) begin
								tag        <= STATE_INIT_CMD8_READ;
								state      <= STATE_SHIFT_DATA;
								state_step <= 0;
							end else begin
								// not getting 01 back means it's a card error
								state <= STATE_INIT_SPI;
							end
						end
					end
				
				// read 32-bits from CMD8 response, should get back voltage ok (01) and echo back of our data (AA)
				STATE_INIT_CMD8_READ:
					begin
						state <= (state_step == 3) ? STATE_INIT_CMD55 : STATE_SHIFT_DATA;
						case (state_step)
							0: if (temp_wire_bits != 8'h00) state <= STATE_INIT_SPI;
							1: if (temp_wire_bits != 8'h00) state <= STATE_INIT_SPI;
							2: if (temp_wire_bits != 8'h01) state <= STATE_INIT_SPI;
							3: if (temp_wire_bits != 8'hAA) state <= STATE_INIT_SPI;
						endcase
						state_step <= (state_step == 3) ? 0 : (state_step + 1'b1);
					end
				
				// send CMD55 (Application commands need a CMD55 prefix)
				STATE_INIT_CMD55:
					begin
						spi_cmd_opcode  <= 8'h40 + 8'd55;
						spi_cmd_payload <= 32'h0;
						spi_cmd_crc     <= 8'h00;
						state           <= STATE_SEND_CMD;
						cmd_tag         <= STATE_INIT_CMD55_R1;
					end
				
				// read CMD55 R1 response (should be in idle state so we expect 01 here)
				STATE_INIT_CMD55_R1:
					begin
						if (temp_wire_bits != 8'h01) begin
							state		<= STATE_INIT_SPI;
						end else begin
							// Send ACMD41 to ready the card
							spi_cmd_opcode  <= 8'h40 + 8'd41;
							spi_cmd_payload <= 32'h40000000;
							spi_cmd_crc     <= 8'h00;
							state           <= STATE_SEND_CMD;
							cmd_tag         <= STATE_INIT_ACMD41_R1;
						end
					end
				
				// process the R1 from ACMD41 we're looking for R1(00) (not in idle state)
				STATE_INIT_ACMD41_R1:
					begin
						if (temp_wire_bits != 8'h00) begin
							// not ready
							state <= STATE_INIT_CMD55;
						end else begin
							// we're ready now we can enable the fast clock
							fst_clk <= 1'b1;
							// now if we're SDSC we definitely jump to setting block length
							if (card_is_sdsc) begin
								state <= STATE_INIT_CMD16;
							end else begin
								state <= STATE_INIT_CMD58;
							end
						end
					end

				// send CMD58
				STATE_INIT_CMD58:
					begin
						// issue opcode 58 to see if we need to set the block length
						spi_cmd_opcode  <= 8'h40 + 8'd58;
						spi_cmd_payload <= 32'h0;
						spi_cmd_crc     <= 8'h00;
						state           <= STATE_SEND_CMD;
						cmd_tag		    <= STATE_INIT_CMD58_R1;
					end

				// read R1 from CMD58
				STATE_INIT_CMD58_R1:
					begin
						if (temp_wire_bits != 8'h00) begin
							state <= STATE_INIT_SPI;
						end else begin
							// now we need to read the 32-bit code back
							tag   <= STATE_INIT_CMD58_READ;
							state <= STATE_SHIFT_DATA;
						end
					end
				
				// read 32-bits of reply from CMD58 of which we only care abous bits 31 and 30.
				STATE_INIT_CMD58_READ:
					begin
						state <= STATE_SHIFT_DATA;
						if (state_step == 0) begin
							// save the top bits to compare later
							spi_cmd58_byte0 <= temp_wire_bits;
						end else if (state_step == 3) begin
							if (spi_cmd58_byte0[7]) begin 
								// if bit 6 is set it's block based
								state <= spi_cmd58_byte0[6] ? STATE_INIT_DONE : STATE_INIT_CMD16;
							end else begin
								state <= STATE_INIT_CMD58;
							end
						end
						state_step <= (state_step == 3) ? 0 : (state_step + 1'b1);
					end
				
				// send CMD16 (set block length) to 512 bytes
				STATE_INIT_CMD16:
					begin
						spi_cmd_opcode  <= 8'h40 + 8'd16;
						spi_cmd_payload <= 32'h200;
						spi_cmd_crc     <= 8'h00;
						state           <= STATE_SEND_CMD;
						cmd_tag         <= STATE_INIT_CMD16_R1;
					end
				
				// read R1 response from CMD16 (should get 00 back)
				STATE_INIT_CMD16_R1:
					begin
						if (temp_wire_bits != 8'h00) begin
							state <= STATE_INIT_SPI;
						end else begin
							state <= STATE_INIT_DONE;
						end
					end
				
				// card is initialized by now into 512-byte sector mode
				STATE_INIT_DONE:
					begin
						card_is_init <= 1'b1;
						error 		 <= `SPISD_ERR_OK;
						state        <= STATE_IDLE;
					end
				
				// send the 6 byte command packet
				STATE_SEND_CMD:
					begin
						// send the 6 bytes of the command
						temp_wire_bits <= spi_cmd_block[40 - (state_step * 8) +: 8];
						bit_cnt 	   <= bit_cnt_orig;
						sck_timer 	   <= sck_timer_orig;
						state          <= STATE_SHIFT_DATA;
						tag            <= (state_step == 5) ? STATE_READ_R1 : STATE_SEND_CMD;
						state_step     <= (state_step == 5) ? 0 : (state_step + 1'b1);
						sck_cycles     <= 0;
					end

				// R1 responses have a variable number of MISO=1 bits (not necessarily a multiple of 8)
				// before clocking out 7 bits of R1 value
				// wait and then read an R1 code, jumps back to cmd_tag, puts code in temp_wire_bits
				STATE_READ_R1:
					begin
						case(sck_pin)
							1'b0:
								begin
									if (sck_timer == 0) begin
										sck_timer   <= sck_timer_orig;					 // time to switch to SCK high
										sck_pin     <= ~sck_pin;
									end else begin
										sck_timer   <= sck_timer - 1'b1;
									end
								end
							1'd1:										// SCK high phase, keep data steady, move to next bit at end of phase
								begin
									if (sck_timer == 0) begin
										sck_cycles     <= sck_cycles + 1'b1;
										sck_timer      <= sck_timer_orig;					// reset timer in case we chain SEND_8's
										sck_pin        <= ~sck_pin;							// set SCK to low for either the next bit of this transaction or the start of the next transaction
										if (~miso_pin) begin
											// went low so now we should read 7 more bits 
											temp_wire_bits <= 0;
											state          <= STATE_SHIFT_DATA;
											tag			   <= cmd_tag;
											bit_cnt        <= bit_cnt_orig - 1;
										end else begin
											if (sck_cycles == timeout) begin
												// no response in 1 second == card not present
												if (spi_cmd_opcode == 8'h48) begin // CMD8 may timeout
													temp_wire_bits <= 8'h04; // invalid opcode
													state 		   <= cmd_tag;
												end else begin
													state 		   <= STATE_INIT_SPI;
													error          <= `SPISD_ERR_TIMEOUT;
												end
											end
										end
									end else begin
										sck_timer <= sck_timer - 1'b1;
									end
								end
						endcase
					end
			
				/* STATE_SHIFT_DATA:
					in: bit_cnt = bit_cnt_orig, sck_timer = sck_timer_origin, temp_wire_bits = data to shift out MOSI/SIO
					out: bit_cnt, sck_timer: unchanged, temp_wire_bits = data shifted in MISO/SIO
				*/
				STATE_SHIFT_DATA:										// shift 8 bits in/out temp_spi_bits	
					begin
						cs_pin <= 1'b0;									// default CS low 
						case(sck_pin)
							1'd0:										// SCK low phase, put data on wire
								begin
									// write during low
									mosi_pin <= temp_wire_bits[7];
									if (sck_timer == 0) begin
										sck_timer   <= sck_timer_orig;					 // time to switch to SCK high
										sck_pin     <= ~sck_pin;
									end else begin
										sck_timer   <= sck_timer - 1'b1;
									end
								end
							1'd1:										// SCK high phase, keep data steady, move to next bit at end of phase
								begin
									if (sck_timer == 0) begin
										temp_wire_bits <= {temp_wire_bits[6:0], miso_pin}; // shift wire bits, and insert MISO bit
										mosi_pin	   <= temp_wire_bits[6];
										bit_cnt        <= bit_cnt - 1'b1;
										sck_pin        <= ~sck_pin;							// set SCK to low for either the next bit of this transaction or the start of the next transaction
										sck_timer      <= sck_timer_orig;					// reset timer in case we chain SEND_8's
										if (bit_cnt == 0) begin
											bit_cnt    <= bit_cnt_orig;						// reset bit count in case we chain SEND_8's
											state      <= tag;
											cs_pin     <= shift8_cs_exit;					// some commands require cs to go high after the last bit
											shift8_cs_exit <= 0;							// reset cs_exit for next SPI transfer
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
							cs_pin  			<= 1'b0;
							sck_pin 			<= 1'b0;
							
							// latch the command
							cmd_wr_en_l         <= cmd_wr_en;
							cmd_sector_l   		<= cmd_sector;
							cmd_pos				<= 9'd0;
							
							// init the host memory address (this also gets the first read primed
							host_mem_addr       <= cmd_host_address;
							
							// default to ok
							error 		 		<= `SPISD_ERR_OK;
					
							// branch to the next state
							case(cmd_wr_en)
								1'b0:  
									begin
										spi_cmd_opcode  <= 8'h40 + 8'd17;
										spi_cmd_payload <= cmd_sector;
										spi_cmd_crc     <= 8'h00;
										state           <= STATE_SEND_CMD;
										cmd_tag         <= STATE_START_READ_RESP;
										host_mem_addr   <= cmd_host_address - 1'b1;
									end
								1'b1:
									begin
										spi_cmd_opcode  <= 8'h40 + 8'd24;
										spi_cmd_payload <= cmd_sector;
										spi_cmd_crc     <= 8'h00;
										state           <= STATE_SEND_CMD;
										cmd_tag         <= STATE_START_WRITE_RESP;
									end
							endcase
						end else begin
							// TODO: every 250ms send a STATUS request
						end
					end

				// parse R1 (expect 00), then shift out 0xFF, followed by 0xFE (the write block token)
				STATE_START_WRITE_RESP:
					begin
						if (temp_wire_bits != 8'h00) begin
							error 		   <= `SPISD_ERR_READ;
							state 		   <= STATE_DONE;
						end else begin
							// clock out 8 bits before sending the write token
							temp_wire_bits <= 8'hFF;
							state          <= STATE_SHIFT_DATA;
							tag		       <= STATE_WRITE_TOKEN;
						end
					end
				
				// shift out the write block token FE letting the card know payload follows
				STATE_WRITE_TOKEN:
					begin
						temp_wire_bits     <= 8'hFE;
						state			   <= STATE_SHIFT_DATA;
						tag				   <= STATE_WRITE_SHIFT;
					end

				// write 512 bytes from host memory to SD SPI
				// by time we get here the host memory should have loaded the first byte
				STATE_WRITE_SHIFT:
					begin
						temp_wire_bits <= host_mem_data_out;
						host_mem_addr  <= host_mem_addr + 1'b1;
						state          <= STATE_SHIFT_DATA;
						tag            <= (cmd_pos == 9'd511) ? STATE_WRITE_CRC : state;
						cmd_pos        <= (cmd_pos == 9'd511) ? 0 : (cmd_pos + 1'b1);
					end
				
				// we don't (yet?) compute the CRC so we just shift out 0xFFFF, we shift out another 0xFF to read the response back
				STATE_WRITE_CRC:
					begin
						temp_wire_bits <= 8'hFF;
						tag            <= (state_step == 2) ? STATE_WRITE_BLOCK_RESP : state;
						state          <= STATE_SHIFT_DATA;
						state_step     <= (state_step == 2) ? 0 : (state_step + 1'b1);
					end
				
				// Read the write response back, the bottom 5 bits have the code we care about
				STATE_WRITE_BLOCK_RESP:
					begin
						state <= STATE_DONE;
						case (temp_wire_bits & 8'h1F)
							8'h05: 
								begin
									error          <= `SPISD_ERR_OK;
									state          <= STATE_WRITE_WAIT;
									temp_wire_bits <= 8'h00;				// next state is waiting for MISO to go high so preload low
									sck_cycles	   <= 0;
								end
							8'h0B, 8'h0D: 	error <= `SPISD_ERR_WRITE;
							default:
								begin
									error <= `SPISD_ERR_TIMEOUT;
									state <= STATE_INIT_SPI;
								end
						endcase
					end
				
				// The card will hold MISO low until the write is complete so we just
				// use SHIFT_DATA to re-use clocking
				STATE_WRITE_WAIT:
					begin
						if (temp_wire_bits != 8'h00) begin
							// write done when MISO goes high at any point
							state      <= STATE_DONE;
						end else begin
							state      <= STATE_SHIFT_DATA;
							tag        <= state;
							// increment by 8 since we're shifting bytes here
							sck_cycles <= sck_cycles + 8;
							if (sck_cycles >= timeout) begin
								error <= `SPISD_ERR_TIMEOUT;
								state <= STATE_INIT_SPI;
							end
						end
					end

				// Read the read sector R1 (should be 00)
				STATE_START_READ_RESP:
					begin
						if (temp_wire_bits != 8'h00) begin
							error 		   <= `SPISD_ERR_READ;
							state 		   <= STATE_DONE;
						end else begin
							// preload temp wire so we can jump into wait token with a known value
							temp_wire_bits <= 8'hFF;
							state          <= STATE_WAIT_TOKEN;
							sck_cycles     <= 0;
							cmd_tag        <= STATE_READ_SHIFT;
						end
					end

				// The SD card shifts out 0xFF bytes until it's ready to provide payload
				// which start with a 0xFE token followed by the payload (512 bytes) followed by 2 bytes of CRC
				// wait for a byte aligned 0xFE token
				STATE_WAIT_TOKEN:
					begin
						sck_cycles <= sck_cycles + 8;					// add 8 since we're shifting 8 bits per iteration
						if (sck_cycles >= timeout) begin
							error <= `SPISD_ERR_TIMEOUT;
							state <= STATE_INIT_SPI;
						end else begin
							state      <= STATE_SHIFT_DATA;
							if (temp_wire_bits == 8'hFE) begin
								// proceed to shift data out of the SD card into host memory
								tag   <= cmd_tag;
							end else begin
								// keep shifting until we hit the read token
								tag   <= state;
							end
						end
					end

				// we enter this having already shifted the first byte so the loop is slightly diff
				// from the STATE_WRITE_SHIFT
				STATE_READ_SHIFT:
					begin
						host_mem_data_in  <= temp_wire_bits;
						host_mem_wr_en    <= 1'b1;
						host_mem_addr     <= host_mem_addr + 1'b1;
						cmd_pos			  <= (cmd_pos == 9'd511) ? 0 : (cmd_pos + 1'b1);
						state             <= (cmd_pos == 9'd511) ? STATE_READ_CRC : STATE_SHIFT_DATA;
						tag			      <= state;
					end
				
				// read the 16-bit CRC from the read sector command
				STATE_READ_CRC:
					begin
						host_mem_wr_en    <= 1'b0;
						state_step		  <= (state_step == 1) ? 0 : (state_step + 1'b1);
						state			  <= (state_step == 1) ? STATE_DONE : STATE_SHIFT_DATA;
						tag				  <= state;
					end
				
				// where commands go before idle, we raise CS, clock out a byte
				STATE_DONE:
					begin
						cs_pin 		   	  <= 1'b1;
						temp_wire_bits    <= 8'hFF;
						host_mem_wr_en	  <= 1'b0;
						state 		      <= STATE_SHIFT_DATA;
						tag   		      <= STATE_WAIT_VALID_LOW;
					end
				
				// here we raise valid and wait for ready to drop before returning to idle
				STATE_WAIT_VALID_LOW:
					begin
						ready <= 1'b1;
						if (!cmd_valid) begin
							ready <= 1'b0;
							state <= STATE_IDLE;
						end
					end 
			endcase
		end
	end
endmodule
