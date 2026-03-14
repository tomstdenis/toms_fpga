`timescale 1ns/1ps

module spi_sram_mem
#(
    parameter ADDR_WIDTH=32,
    parameter DATA_WIDTH=32,
    
    // SPI SRAM related
	parameter CLK_FREQ_MHZ=27,								// system clock frequency (required for walltime requirements)
//	parameter DATA_WIDTH=32,								// controls the line size

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
    // common bus in
    input clk,
    input rst_n,            // active low reset
    input enable,           // active high overall enable (must go low between commands)
    input wr_en,            // active high write enable (0==read, 1==write)
    input [ADDR_WIDTH-1:0] addr,
    input [DATA_WIDTH-1:0] i_data,
    input [DATA_WIDTH/8-1:0] be,       // lane 0 must be asserted, other lanes can be asserted but they're ignored.

    // common bus out
    output reg ready,       // active high signal when o_data is ready (or write is done)
    output reg [DATA_WIDTH-1:0] o_data,
    output wire irq,        // active high IRQ pin
    output wire bus_err,    // active high error signal

    // peripheral specific
	inout [3:0] sio_pin,									// data pins
	output cs_pin,											// active low CS pin
	output sck_pin											// SPI clock
);

	wire sram_done;
	reg [DATA_WIDTH-1:0] sram_data_in;
	reg sram_data_in_valid;
	wire [DATA_WIDTH-1:0] sram_data_out;
	reg sram_write_cmd;
	reg sram_read_cmd;
	reg [SRAM_ADDR_WIDTH-1:0] sram_address;

	spi_sram_flat #(
		.CLK_FREQ_MHZ(CLK_FREQ_MHZ),
		.DATA_WIDTH(DATA_WIDTH),
		.CMD_READ(CMD_READ),
		.CMD_WRITE(CMD_WRITE),
		.CMD_EQIO(CMD_EQIO),
		.MIN_CPH_NS(MIN_CPH_NS),
		.SPI_TIMER_BITS(SPI_TIMER_BITS),
		.QPI_TIMER_BITS(QPI_TIMER_BITS)
	) sram (
		.clk(clk), .rst_n(rst_n),
		.done(sram_done),
		.data_in(sram_data_in),
		.data_in_valid(sram_data_in_valid),
		.data_out(sram_data_out),
		.data_be(be),
		.write_cmd(sram_write_cmd),
		.read_cmd(sram_read_cmd),
		.address(sram_address),
		.sio_pin(sio_pin), .cs_pin(cs_pin), .sck_pin(sck_pin));

	reg state;
	reg error;
	assign bus_err = enable & error;
	localparam
		STATE_IDLE = 0,
		STATE_WORK = 1;
	
	always @(posedge clk) begin
		if (!rst_n) begin
			sram_data_in 		<= 0;
			sram_data_in_valid 	<= 0;
			sram_write_cmd 		<= 0;
			sram_read_cmd 		<= 0;
			sram_address 		<= 0;
			state 				<= STATE_IDLE;
			ready 				<= 0;
			o_data 				<= 0;
			error	 			<= 0;
		end else begin
			if (enable && !error && !ready) begin
				case(state)
					STATE_IDLE: // wait for a command
						if (sram_done)
						begin
							if (wr_en) begin									// we're writing 
								sram_data_in 		<= i_data;					// latch data
								sram_data_in_valid 	<= 1;						// mark as valid
								sram_write_cmd 		<= 1;						// write command
							end else begin
								sram_read_cmd 		<= 1;						// read command
							end
							sram_address 	<= addr[SRAM_ADDR_WIDTH-1:0];		// store address
							state 			<= STATE_WORK;
						end
					STATE_WORK:
						begin
							sram_data_in_valid 		<= 0;						// turn off all enables
							sram_write_cmd 			<= 0;
							sram_read_cmd 			<= 0;
							if (sram_done) begin								// wait for SRAM to be done
								if (!wr_en) begin
									// it was a read
									o_data <= sram_data_out;
								end
								ready <= 1;
								state <= STATE_IDLE;
							end
						end
				endcase
			end else if (!enable) begin
				ready <= 0;
				error <= 0;
			end
		end
	end
endmodule
