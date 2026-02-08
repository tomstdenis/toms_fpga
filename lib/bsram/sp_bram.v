/* 
  bus wrapper for SP primitive on GW2A devices
  
  Unlike the GW5A parts the SP primitive here doesn't have a byte enable
so this module provides one with a bus wrapper around them.
*/
`timescale 1ns/1ps
`include "sp_bram.vh"

module sp_bram
#(
    parameter ADDR_WIDTH=32,
    parameter DATA_WIDTH=32,
    WIDTH=8192                  // using four 8bits x WIDTH long arrays
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
    output wire bus_err    // active high error signal

    // peripheral specific
);

    reg [31:0] i_mem;
    wire [31:0] o_mem;
    reg [3:0] wren;
    reg error;
    assign bus_err = enable & error;
    assign irq = 1'b0;
    
/* 4 x WIDTH byte arrays form the 4 lanes we need for a 32-bit memory
    
    These blocks work as follows
    
		- Reads: (bypass mode)
			- Cycle 0: ce goes high
			- Cycle 1: write address
			- Cycle 2: data available on the negedge of the clock (posedge if using pipeline mode)
		- Write: (bypass mode)
			- Cycle 0: ce hoes high
			- Cycle 1: write address and data

	To speed things up we leave the CE's always enabled, it's the .wre we toggle as needed, defaulting to 0 so it's in read mode.
*/
    Gowin_SP b1(.dout(o_mem[7:0]), .clk(clk), .oce(1'b1), .ce(1'b1), .wre(wren[0]), .ad(addr[$clog2(WIDTH)+1:2]), .din(i_mem[7:0]), .reset(~rst_n));
    Gowin_SP b2(.dout(o_mem[15:8]), .clk(clk), .oce(1'b1), .ce(1'b1), .wre(wren[1]), .ad(addr[$clog2(WIDTH)+1:2]), .din(i_mem[15:8]), .reset(~rst_n));
    Gowin_SP b3(.dout(o_mem[23:16]), .clk(clk), .oce(1'b1), .ce(1'b1), .wre(wren[2]), .ad(addr[$clog2(WIDTH)+1:2]), .din(i_mem[23:16]), .reset(~rst_n));
    Gowin_SP b4(.dout(o_mem[31:24]), .clk(clk), .oce(1'b1), .ce(1'b1), .wre(wren[3]), .ad(addr[$clog2(WIDTH)+1:2]), .din(i_mem[31:24]), .reset(~rst_n));

    reg state;

    localparam
        ISSUE = 0,
        RETIRE = 1;

    always @(posedge clk) begin
        if (!rst_n) begin
            wren <= 0;
            error <= 0;
            ready <= 0;
            state <= ISSUE;
            i_mem <= 0;
            o_data <= 0;
        end else begin
            if (!error & enable & !ready) begin
                case(state)
                    ISSUE:
                        begin
                            if (wr_en) begin
                                // writing (ISSUE => sort out where to put i_data and wren's
                                case(be)
                                    4'b1111:
                                        begin
                                            if (addr & 2'b11) begin
                                                error <= 1;
                                                ready <= 1;
                                            end else begin
                                                i_mem[31:0] <= i_data[31:0];
                                                wren <= 4'b1111;
                                                state <= RETIRE;
                                            end
                                        end
                                    4'b0011: // 16-bit writes
                                        begin
                                            case(addr & 2'b11)
                                                2'b00:
                                                    begin
                                                        i_mem[15:0] <= i_data[15:0];
                                                        wren <= 4'b0011;
                                                        state <= RETIRE;
                                                    end
                                                2'b10:
                                                    begin
                                                        i_mem[31:16] <= i_data[15:0];
                                                        wren <= 4'b1100;
                                                        state <= RETIRE;
                                                    end
                                                default:
                                                    begin
                                                        error <= 1;
                                                        ready <= 1;
                                                    end
                                            endcase
                                        end
                                    4'b0001: // 8-bit writes
                                        begin
                                            case(addr & 2'b11) 
                                                2'b00:
                                                    begin
                                                        i_mem[7:0] <= i_data[7:0];
                                                        wren <= 4'b0001;
                                                        state <= RETIRE;
                                                    end
                                                2'b01:
                                                    begin
                                                        i_mem[15:8] <= i_data[7:0];
                                                        wren <= 4'b0010;
                                                        state <= RETIRE;
                                                    end
                                                2'b10:
                                                    begin
                                                        i_mem[23:16] <= i_data[7:0];
                                                        wren <= 4'b0100;
                                                        state <= RETIRE;
                                                    end
                                                2'b11:
                                                    begin
                                                        i_mem[31:24] <= i_data[7:0];
                                                        wren <= 4'b1000;
                                                        state <= RETIRE;
                                                    end
                                            endcase
                                        end
                                endcase
                            end else begin
                                // reading read 32-bits right away and we'll sort out muxing in the next cycle
                                state <= RETIRE;
                            end
                        end
                    RETIRE:
                        begin
                            ready <= 1;
                            if (!error) begin
                                if (wr_en) begin
									wren <= 4'b0000;
                                end else begin
                                    // reading we need to mux o_mem to o_data based on be
                                    case(be)
                                        4'b1111:
                                            begin
                                                if (addr & 2'b11) begin
                                                    error <= 1;
                                                end else begin
                                                    o_data[31:0] <= o_mem[31:0];
                                                end
                                            end
                                        4'b0011: // 16-bit reads
                                            begin
                                                case(addr & 2'b11)
                                                    2'b00:
                                                        begin
                                                            o_data[31:0] <= {16'b0, o_mem[15:0]};
                                                        end
                                                    2'b10:
                                                        begin
                                                            o_data[31:0] <= {16'b0, o_mem[31:16]};
                                                        end
                                                    default:
                                                        begin
                                                            error <= 1;
                                                        end
                                                endcase
                                            end
                                        4'b0001: // 8-bit reads
                                            begin
                                                case(addr & 2'b11) 
                                                    2'b00:
                                                        begin
                                                            o_data[31:0] <= {24'b0, o_mem[7:0]};
                                                        end
                                                    2'b01:
                                                        begin
                                                            o_data[31:0] <= {24'b0, o_mem[15:8]};
                                                        end
                                                    2'b10:
                                                        begin
                                                            o_data[31:0] <= {24'b0, o_mem[23:16]};
                                                        end
                                                    2'b11:
                                                        begin
                                                            o_data[31:0] <= {24'b0, o_mem[31:24]};
                                                        end
                                                endcase
                                            end
                                    endcase
                                end
                            end
                        end
                endcase
            end else if (!enable) begin
				wren <= 4'b0000;
                ready <= 0;
                error <= 0;
                state <= ISSUE;
            end
        end
    end
endmodule
