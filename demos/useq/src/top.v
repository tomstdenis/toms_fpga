module top(input clk, input in1, output out1);
    reg ticker;
    wire [7:0] i_port = {6'b0, in1, ticker};
    wire [7:0] o_port;
    wire [7:0] mem_data;
    wire [7:0] mem_addr;
    wire rst_n;
    wire pll_clk;
    reg read_fifo;
    reg write_fifo;
    wire fifo_empty;
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

    useq test_useq(.clk(pll_clk), .rst_n(rst_n), 
        .mem_data(mem_data), .i_port(i_port), .mem_addr(mem_addr), .o_port(o_port),
        .read_fifo(read_fifo), .write_fifo(write_fifo), .fifo_empty(fifo_empty),
        .fifo_out(fifo_out), .fifo_in(fifo_in));

endmodule