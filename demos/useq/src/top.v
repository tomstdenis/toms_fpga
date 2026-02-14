module top(input clk, input in1, output out1);
    wire [7:0] i_port = {7'b0, in1};
    wire [7:0] o_port;
    wire o_port_pulse;
    wire [15:0] mem_data;
    wire [11:0] mem_addr;
    wire [11:0] mem_addr_next;
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
        .wrea(1'b0), //input wrea
        .clkb(clk), //input clkb
        .oceb(1'b1), //input oceb
        .ceb(1'b1), //input ceb
        .resetb(~rst_n), //input resetb
        .wreb(1'b0), //input wreb
        .ada(mem_addr), //input [11:0] ada
        .dina(8'b0), //input [7:0] dina
        .adb(mem_addr_next), //input [11:0] adb
        .dinb(8'b0) //input [7:0] dinb
    );

    useq #(.ENABLE_IRQ(1), .ENABLE_HOST_FIFO_CTRL(1)) 
        test_useq(
            .clk(clk), .rst_n(rst_n), 
            .mem_data(mem_data), .i_port(i_port), .mem_addr(mem_addr), .mem_addr_next(mem_addr_next), .o_port(o_port), .o_port_pulse(o_port_pulse),
            .read_fifo(read_fifo), .write_fifo(write_fifo), .fifo_empty(fifo_empty), .fifo_full(fifo_full),
            .fifo_out(fifo_out), .fifo_in(fifo_in));

endmodule