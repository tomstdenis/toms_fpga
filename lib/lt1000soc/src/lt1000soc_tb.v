/* verilator lint_off WIDTHEXPAND */
/* verilator lint_off WIDTHTRUNC */
`timescale 1ns/1ps

module lt1000soc_tb();
    // Clock Generation
    localparam CLK_PERIOD = 20;    //  50MHz
    reg clk;
    always #(CLK_PERIOD/2) clk = ~clk;

    reg rst_n;
    reg [31:0] cycles;
    always @(posedge clk) begin
        rst_n  <= 1'b1;
        cycles <= cycles + 1;
    end

    lt1000soc #(.CORE_FREQ_KHZ(50_000), .UART_BAUD(1_000_000)) lt1000dut(
        .core_clk(clk), .vga_clk(clk), .rst_n(rst_n)
    );

    initial begin
        // Waveform setup
        $dumpfile("lt1000soc.vcd");
        $dumpvars(0, lt1000soc_tb);

        cycles = 0;
        rst_n  = 0;
        clk    = 0;

        while (cycles < 50000) @(posedge clk);
        $finish;
    end
endmodule

`include "lt1000soc.v"