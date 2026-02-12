module top(input clk, input in1, output out1);
    reg ticker;
    wire [7:0] i_port = {6'b0, in1, ticker};
    wire [7:0] o_port;
    wire o_port_pulse;
    wire [7:0] mem_data;
    wire [7:0] mem_addr;
    wire rst_n;
    wire pll_clk;
    reg read_fifo;
    reg write_fifo;
    wire fifo_empty;
    wire fifo_full;
    reg [7:0] fifo_in;
    wire [7:0] fifo_out;
    reg [3:0] rstcnt = 4'b0;

    assign rst_n = rstcnt[3];
    assign out1 = o_port[0];

    Gowin_rPLL rPLL(
        .clkout(pll_clk), //output clkout
        .clkin(clk) //input clkin
    );

    always @(posedge pll_clk) begin
        rstcnt <= {rstcnt[2:0], 1'b1};
        if (!rst_n) begin
            write_fifo <= 0;
            read_fifo <= 0;
            fifo_in <= 0;
            ticker <= 0;
        end else begin
            ticker <= ticker ^ 1;
        end
    end

    Gowin_ROM16 useq_rom(
        .dout(mem_data), //output [7:0] dout
        .ad(mem_addr) //input [7:0] ad
    );

`define BUILD_ALL
//`define BUILD_EXEC1_ONLY
//`define BUILD_EXEC2_ONLY
//`define BUILD_SLIM

    // all build
`ifdef BUILD_ALL
    useq #(.ENABLE_EXEC1(1), .ENABLE_EXEC2(1),.ENABLE_IRQ(1), .ENABLE_HOST_FIFO_CTRL(1)) 
`elsif BUILD_EXEC1_ONLY
    // exec1 only
    useq #(.ENABLE_EXEC1(1), .ENABLE_EXEC2(0),.ENABLE_IRQ(1), .ENABLE_HOST_FIFO_CTRL(1)) 
`elsif BUILD_EXEC2_ONLY
    // exec2 only
    useq #(.ENABLE_EXEC1(0), .ENABLE_EXEC2(1),.ENABLE_IRQ(1), .ENABLE_HOST_FIFO_CTRL(1)) 
`elsif BUILD_SLIM
    // exec2 only with no host FIFO no IRQ
    useq #(.ENABLE_EXEC1(1), .ENABLE_EXEC2(0),.ENABLE_IRQ(0), .ENABLE_HOST_FIFO_CTRL(0)) 
`endif
        test_useq(
            .clk(pll_clk), .rst_n(rst_n), 
            .mem_data(mem_data), .i_port(i_port), .mem_addr(mem_addr), .o_port(o_port), .o_port_pulse(o_port_pulse),
            .read_fifo(read_fifo), .write_fifo(write_fifo), .fifo_empty(fifo_empty), .fifo_full(fifo_full),
            .fifo_out(fifo_out), .fifo_in(fifo_in));

endmodule