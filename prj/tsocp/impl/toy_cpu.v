module top(
    input wire clk,
    input wire rst_n,

    output wire is_halted,

    // port A
    output wire [7:0] bus_addr_a,
    output wire [7:0] bus_data_in_a,
    input wire [7:0] bus_data_out_a,
    output wire bus_wr_en_a,
    output wire bus_valid_a,
    input wire bus_ready_a,

    // port B
    output wire [7:0] bus_addr_b,
    output wire [7:0] bus_data_in_b,
    input wire [7:0] bus_data_out_b,
    output wire bus_wr_en_b,
    output wire bus_valid_b,
    input wire bus_ready_b
);
    wire pll_clk;
    wire plllock;

    pll mypll(.clkin(clk), .clkout0(pll_clk), .locked(plllock));

    toy_isa cpu(
        .clk(pll_clk), .rst_n(rst_n), .is_halted(is_halted),

        .bus_addr_a(bus_addr_a), .bus_data_in_a(bus_data_in_a),
        .bus_data_out_a(bus_data_out_a), .bus_wr_en_a(bus_wr_en_a),
        .bus_valid_a(bus_valid_a), .bus_ready_a(bus_ready_a),

        .bus_addr_b(bus_addr_b), .bus_data_in_b(bus_data_in_b),
        .bus_data_out_b(bus_data_out_b), .bus_wr_en_b(bus_wr_en_b),
        .bus_valid_b(bus_valid_b), .bus_ready_b(bus_ready_b));

endmodule