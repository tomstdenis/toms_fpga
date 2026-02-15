module top(input clk, inout [7:0]io);
    wire [7:0] i_port = io;                // input port, we only use one pin right now
    wire [7:0] o_port;                              // output port
    wire o_port_pulse;                              // this inverts when o_port is written to by the core
    wire [15:0] mem_data;                           // the 16-bits read from the BRAM from mem_addr_next, mem_addr
    wire wren;                                      // write enable
    wire [7:0] mem_out;                             // data the core wants to write to BRAM
    wire [11:0] mem_addr;                           // address of data we want in mem_data[7:0]
    wire [11:0] mem_addr_next;                      // address of data we want in mem_data[15:0]
    wire rst_n;                                     // reset 
    wire pll_clk;
    reg read_fifo;                                  //
    reg write_fifo;
    wire fifo_empty;
    wire fifo_full;
    reg [7:0] fifo_in;
    wire [7:0] fifo_out;
    reg [3:0] rstcnt = 4'b0;

    assign rst_n = rstcnt[3];
// Bit-by-bit Quasi-Bidirectional Logic (PCF8574 style)
// If o_port[n] is 1, io[n] is High-Z (allows input or pulls high via resistor)
// If o_port[n] is 0, io[n] is driven Low (0)
    assign io[0] = o_port[0] ? 1'bz : 1'b0;
    assign io[1] = o_port[1] ? 1'bz : 1'b0;
    assign io[2] = o_port[2] ? 1'bz : 1'b0;
    assign io[3] = o_port[3] ? 1'bz : 1'b0;
    assign io[4] = o_port[4] ? 1'bz : 1'b0;
    assign io[5] = o_port[5] ? 1'bz : 1'b0;
    assign io[6] = o_port[6] ? 1'bz : 1'b0;
    assign io[7] = o_port[7] ? 1'bz : 1'b0;

    wire portBen = ~wren;           // only read if we're not writing

/*
    Gowin_rPLL rPLL(
        .clkout(pll_clk), //output clkout
        .clkin(clk) //input clkin
    );
*/

    always @(posedge clk) begin
        rstcnt <= {rstcnt[2:0], 1'b1};
        if (!rst_n) begin
            write_fifo <= 0;
            read_fifo <= 0;
            fifo_in <= 0;
        end
    end

    Gowin_DPB useq_ram(
        .douta(mem_data[7:0]), //output [7:0] douta
        .doutb(mem_data[15:8]), //output [7:0] doutb
        .clka(clk), //input clka
        .ocea(1'b1), //input ocea
        .cea(1'b1), //input cea
        .reseta(~rst_n), //input reseta
        .wrea(wren), //input wrea
        .clkb(clk), //input clkb
        .oceb(1'b1), //input oceb
        .ceb(portBen), //input ceb
        .resetb(~rst_n), //input resetb
        .wreb(1'b0), //input wreb
        .ada(mem_addr), //input [11:0] ada
        .dina(mem_out), //input [7:0] dina
        .adb(mem_addr_next), //input [11:0] adb
        .dinb(8'b0) //input [7:0] dinb
    );

    useq #(.ENABLE_IRQ(1), .ENABLE_HOST_FIFO_CTRL(1), .FIFO_DEPTH(32), .STACK_DEPTH(32))
        test_useq(
            .clk(clk), .rst_n(rst_n), 
            .mem_data(mem_data), .wren(wren), .mem_out(mem_out), .mem_addr(mem_addr), .mem_addr_next(mem_addr_next),
            .i_port(i_port), .o_port(o_port), .o_port_pulse(o_port_pulse),
            .read_fifo(read_fifo), .write_fifo(write_fifo), .fifo_empty(fifo_empty), .fifo_full(fifo_full), .fifo_out(fifo_out), .fifo_in(fifo_in));

endmodule