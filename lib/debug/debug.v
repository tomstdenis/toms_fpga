`timescale 1ns/1ps

/*

	Simple looped serial debug wire protocol
	
Every module that wants to have debug support instantiates one or more of these and daisy chains the
rx_{data/clk} to the tx_{data/clk}, meaning modules that use this need to export/import those nets and the parent module
has to ensure they're all connected.

The protocol uses a 144 bit packet consisting of 1 bit direction (read or write) 15 bit address, and 128 bits of payload.

Upon reset every node assigns themselves the address 7FFF.  The host controller sends out a frame consisting of 
[15:1] == 7FFF and [30:16] == 0000.  This assigns the first node the address 0000.  That node increments the address
by 1 and transmits [30:16] == 0001 assigning the next node a 0001 and so on.

After the host sees a broadcast packet come out it now knows how many nodes are in the chain.

Now the host can send a node a packet by setting [0] to the direction, bits [15:1] to the address, and [143:16] to the payload.

For write commands the payload is copied to the debug_incoming_data[127:0] and the register debug_incoming_tgl is inverted.  The
parent module must latch that and detect an edge (falling or raising) to know when the value changed.

For read commands the first byte of payload [23:16] is the READ "command" where only one command READ_CMD_IDENT is defined.
If the read command is READ_CMD_IDENT then the payload identity[127:0] is sent in response, otherwise the default
contents of debug_outgoing_data[127:0] is sent.  The theory of operation being you'd assign debug_outgoing_data[127:0] to be
either a wire that collects several important nets together, or similarly a register that does the same.  Each module can choose
what it wants to pack into the net.  It could even respond to write commands that for instance ask for a specific datum from
the module.

If the packet is not for the node the node just forwards it on verbatim.

Design considerations:

- We use a synchronization pipe to help with clock domain crossings.

- It's assumed that prescaler is chosen (per instantiation) such that for the slowest
clocked module in the system the rx_clk period is 4 or more cycles (low for 2, high for 2).  This means that different
instantiations might use different prescalers.  For instance, if you have one block at 1MHz and another at 4MHz then
the prescaler for the 4MHz block must set the tx_clk low for 2 1MHz cycles (8 4MHz cycles) meaning you'd need to use a 
prescaler of 8 for the 4MHz block and 2 for the 1MHz block yielding an overall 250kbit/sec clock (recall min period is 4 1MHz cycles).

- For the receiving side it's self clocking so you can have have prescaler mismatches provided the 4 cycle period minimum is observed
across all clock domains.

- At the root you'd use a debug_host.v module (yet to be written) that provides a UART to Serial Debugger interface with commands
for enumerating nodes, fetching identities of a node, and reading/writing payload from/to nodes.  It'd be then up to the PC side
host application to make a UI or application around that on a per design basis.

*/

module serial_debug #(
	parameter BITS=128
)(
	input clk,
	input rst_n,
	
	// baud rate
	input [7:0] prescaler,								// prescaler against clk to control tx_clk (ideally >= 2) (meant to be a constant wire not subject to reset)
	
	// serial input
	input rx_data,										// incoming serial data
	input rx_clk,										// incoming serial clock
	
	// serial output
	output reg tx_data,									// outgoing serial data
	output reg tx_clk,									// outgoing serial clock
	
	// controller input
	input [BITS-1:0] debug_outgoing_data,					// default data we want to provide when given a READ (cmd != IDENT)
	
	// control output
	output reg debug_incoming_tgl,						// toggle indicating whether debug_incoming_data changed
	output reg [BITS-1:0] debug_incoming_data,				// data the host is writing to us
	
	// identity
	input [BITS-1:0] identity								// 128-bit identity provided with a read and CMD == IDENT used to tell the host what module this address is
);
	localparam
		SF_BITS = BITS + 16,								// bits per store-forward frame, 128 data bits + 15 address bits + 1 direction bit
		BROADCAST_ADDR = 15'h7FFF,						// default broadcast address
		READ_DIRECTION = 0,								// packet is a read
		WRITE_DIRECTION = 1;							// packet is a write 

	reg [SF_BITS-1:0] sf_buf;							// local store forward buffer
	reg [14:0] our_address;								// our address
	reg [7:0] sf_bits_left;								// how many bits left to transmit or read
	reg [7:0] sf_prescale_cnt;							// prescaler used to generate tx_clk
	reg [7:0] sf_prescaler;
	
	wire [14:0] sf_address = sf_buf[15:1];				// what address is the packet for
	wire sf_direction = sf_buf[0];						// what direction is the traffic (READ=0, WRITE=1)
	wire [7:0] sf_read_cm = sf_buf[23:16];				// first byte of READ outgoing payload is the read operation command
	
	reg [3:0] rx_data_pipe;								// sync pipe for rx_data
	reg [3:0] rx_clk_pipe;								// sync pipe for rx_clk
	wire cur_rx_data = rx_data_pipe[2];					// current synced data
	wire cur_rx_clk  = rx_clk_pipe[2];					// current synced clock
	wire cur_rx_clk_prev = rx_clk_pipe[3];				// previous current synced clock

	localparam
		STATE_IDLE = 0,
		STATE_LOADING_SF = 1,
		STATE_WAIT_TO_DECODE_SF = 2,
		STATE_DECODING_SF = 3,
		STATE_SENDING_SF = 4;

	localparam
		READ_CMD_IDENT = 0;
		
	reg [3:0] state;									// current FSM state

	always @(posedge clk) begin
		if (!rst_n) begin
			our_address <= BROADCAST_ADDR;														// default to broadcast address
			state <= STATE_IDLE;																// enter the IDLE state
			rx_data_pipe <= 0;																	// clear the RX data pipe
			rx_clk_pipe <= 0;																	// clear the RX clk pipe
			tx_clk <= 1'b1;																		// ensure our TX clk is idle high
			tx_data <= 1'b0;																	// set the TX data to a known value
			debug_incoming_data <= 0;															// clear the incoming data 
			debug_incoming_tgl <= 0;															// set the toggle to a default state
			sf_prescaler <= prescaler < 2 ? 2 : prescaler;										// save the prescaler at a minimum period of 4 (2*sf_prescaler)
		end else begin
			// solve for metastability
			rx_data_pipe <= {rx_data_pipe[2:0], rx_data};
			rx_clk_pipe  <= {rx_clk_pipe[2:0], rx_clk};
			case (state)
				STATE_IDLE:
					begin
						if (cur_rx_clk_prev == 1'b1 && cur_rx_clk == 1'b0) begin				// detect falling edge of clk
							state 		 <= STATE_LOADING_SF;
							sf_bits_left <= SF_BITS;
							sf_buf		 <= 0;
						end
					end
				STATE_LOADING_SF:
					begin
						if (cur_rx_clk_prev == 1'b0 && cur_rx_clk == 1'b1) begin				// detect raising edge of clk
							// sample on high
							sf_buf <= {sf_buf[SF_BITS-2:0], cur_rx_data};
							if (sf_bits_left == 1) begin
								// we're done
								state <= STATE_DECODING_SF;
							end
							sf_bits_left <= sf_bits_left - 1'b1;
						end
					end
				STATE_DECODING_SF:
					begin
						state 			 <= STATE_SENDING_SF;									// we always jump to sending the store forward
						sf_bits_left 	 <= SF_BITS;											// total bits
						sf_prescale_cnt  <= 2;													// We want to align to a falling edge of the clock
						tx_clk 			 <= 1'b1;												// ensure clock is high for at least 2 cycles

						`ifdef SIM_MODEL
						$display("sf_address = %h, sf_direction = %d", sf_address, sf_direction);
						`endif
						if (our_address == BROADCAST_ADDR && sf_address == BROADCAST_ADDR) begin
							// first packet will be enumeration
							our_address   <= sf_buf[30:16];										// store our address
							sf_buf[30:16] <= sf_buf[30:16] + 1'b1;								// increment it 
						end else begin
							// is it for us?
							if (our_address == sf_address) begin
								if (sf_direction == READ_DIRECTION) begin
									// READ for us
									case (sf_read_cm)
										READ_CMD_IDENT:											// IDENT command we only write our identity wire
											begin
												sf_buf[SF_BITS-1:16] <= identity;
											end
										default:
											begin
												sf_buf[SF_BITS-1:16] <= debug_outgoing_data;	// default is to just copy whatever is in the outgoing wire
											end
									endcase
								end else begin
									// WRITE for us
									debug_incoming_data 	  <= sf_buf[SF_BITS-1:16];			// write to our incoming debug wire
									debug_incoming_tgl		  <= ~debug_incoming_tgl;			// flip the incoming tgl bit to let the parent know we stored something new
								end
							end else begin
								// not for us
							end
						end
					end
				STATE_SENDING_SF:
					begin
						if (sf_prescale_cnt == 1) begin
							// we're at the next clock phase
							if (tx_clk == 1'b0) begin
								// we're transition to high so we need to have already loaded the value
								tx_clk <= 1'b1;
							end else begin
								// we're transition to low so load the next bit
								tx_data			 <= sf_buf[SF_BITS-1];							// send the MSB
								sf_buf 			 <= {sf_buf[SF_BITS-2:0], 1'b0 };				// shift store forward buffer left
								if (sf_bits_left == 0) begin
									state 		 <= STATE_IDLE;									// out of bits return to IDLE state
									tx_clk 		 <= 1'b1;										// ensure clock goes high
								end else begin
									sf_bits_left <= sf_bits_left - 1'b1;						// otherwise decrement count and keep going
									tx_clk 		 <= 1'b0;										// clock was high, force it low now
								end
							end
							sf_prescale_cnt <= sf_prescaler;									// reset prescaler count to hold TX clk steady
						end else begin
							sf_prescale_cnt <= sf_prescale_cnt - 1'b1;							// we're still in one half cycle, decrement the prescaler counter
						end	
					end
				default: begin end
			endcase
		end
	end
endmodule
