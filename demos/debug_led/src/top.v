module top(
    input clk,
    output uart_tx,
    input uart_rx,
    output [3:0] led);

    localparam
        BITS=128,
        ENABLE=1;

    wire node0_rx_data;
    wire node0_rx_clk;
    wire node0_tx_data;
    wire node0_tx_clk;
    wire node1_tx_data;
    wire node1_tx_clk;
    wire node2_tx_data;
    wire node2_tx_clk;
    wire node3_tx_data;
    wire node3_tx_clk;

    assign led[0] = ~node0_outgoing_data[0];
    assign led[1] = ~node1_outgoing_data[0];
    assign led[2] = ~node2_outgoing_data[0];
    assign led[3] = ~node3_outgoing_data[0];

    reg [BITS-1:0] node0_outgoing_data;
    reg [BITS-1:0] node1_outgoing_data;
    reg [BITS-1:0] node2_outgoing_data;
    reg [BITS-1:0] node3_outgoing_data;
    wire [BITS-1:0] node0_incoming_data;
    wire node0_incoming_tgl;
    reg node0_incoming_tgl_prev;
    wire [BITS-1:0] node1_incoming_data;
    wire node1_incoming_tgl;
    reg node1_incoming_tgl_prev;
    wire [BITS-1:0] node2_incoming_data;
    wire node2_incoming_tgl;
    reg node2_incoming_tgl_prev;
    wire [BITS-1:0] node3_incoming_data;
    wire node3_incoming_tgl;
    reg node3_incoming_tgl_prev;

    reg [BITS-1:0] node0_identity;
    reg [BITS-1:0] node1_identity;
    reg [BITS-1:0] node2_identity;
    reg [BITS-1:0] node3_identity;

    wire [15:0] baud_div = 27_000_000 / 115_200;

    serial_debug #(.BITS(BITS), .ENABLE(ENABLE)) node0(
        .clk(clk), .rst_n(rst_n),
        .prescaler(8'h4),
        .rx_data(node0_rx_data), .rx_clk(node0_rx_clk),
        .tx_data(node0_tx_data), .tx_clk(node0_tx_clk),
        .debug_outgoing_data(node0_outgoing_data),
        .debug_incoming_tgl(node0_incoming_tgl), .debug_incoming_data(node0_incoming_data),
        .identity(node0_identity));

    serial_debug #(.BITS(BITS), .ENABLE(ENABLE)) node1(
        .clk(clk), .rst_n(rst_n),
        .prescaler(8'h4),
        .rx_data(node0_tx_data), .rx_clk(node0_tx_clk),
        .tx_data(node1_tx_data), .tx_clk(node1_tx_clk),
        .debug_outgoing_data(node1_outgoing_data),
        .debug_incoming_tgl(node1_incoming_tgl), .debug_incoming_data(node1_incoming_data),
        .identity(node1_identity));

    serial_debug #(.BITS(BITS), .ENABLE(ENABLE)) node2(
        .clk(clk), .rst_n(rst_n),
        .prescaler(8'h4),
        .rx_data(node1_tx_data), .rx_clk(node1_tx_clk),
        .tx_data(node2_tx_data), .tx_clk(node2_tx_clk),
        .debug_outgoing_data(node2_outgoing_data),
        .debug_incoming_tgl(node2_incoming_tgl), .debug_incoming_data(node2_incoming_data),
        .identity(node2_identity));

    serial_debug #(.BITS(BITS), .ENABLE(ENABLE)) node3(
        .clk(clk), .rst_n(rst_n),
        .prescaler(8'h4),
        .rx_data(node2_tx_data), .rx_clk(node2_tx_clk),
        .tx_data(node3_tx_data), .tx_clk(node3_tx_clk),
        .debug_outgoing_data(node3_outgoing_data),
        .debug_incoming_tgl(node3_incoming_tgl), .debug_incoming_data(node3_incoming_data),
        .identity(node3_identity));

    serial_debug_uart #(.BITS(BITS), .ENABLE(ENABLE)) debug_uart(
        .clk(clk), .rst_n(rst_n),
        .prescaler(8'h4),
        .debug_tx_data(node3_tx_data), .debug_tx_clk(node3_tx_clk),
        .debug_rx_data(node0_rx_data), .debug_rx_clk(node0_rx_clk),
        .uart_bauddiv(baud_div), .uart_rx_pin(uart_rx), .uart_tx_pin(uart_tx));

    // RESET
    reg [3:0] rstcnt = 4'b0;
    assign rst_n = rstcnt[3];

    always @(posedge clk) begin
        rstcnt <= {rstcnt[2:0], 1'b1};
        if (!rst_n) begin
            node0_outgoing_data <= 0;
            node1_outgoing_data <= 0;
            node2_outgoing_data <= 0;
            node3_outgoing_data <= 0;
            node0_incoming_tgl_prev <= 0;
            node1_incoming_tgl_prev <= 0;
            node2_incoming_tgl_prev <= 0;
            node3_incoming_tgl_prev <= 0;
            node0_identity <= 32'h11223300;
            node1_identity <= 32'h11223301;
            node2_identity <= 32'h11223302;
            node3_identity <= 32'h11223303;
        end else begin
            if (node0_incoming_tgl_prev != node0_incoming_tgl) begin
                node0_incoming_tgl_prev <= node0_incoming_tgl;
                node0_outgoing_data <= node0_incoming_data;
            end
            if (node1_incoming_tgl_prev != node1_incoming_tgl) begin
                node1_incoming_tgl_prev <= node1_incoming_tgl;
                node1_outgoing_data <= node1_incoming_data;
            end
            if (node2_incoming_tgl_prev != node2_incoming_tgl) begin
                node2_incoming_tgl_prev <= node2_incoming_tgl;
                node2_outgoing_data <= node2_incoming_data;
            end
            if (node3_incoming_tgl_prev != node3_incoming_tgl) begin
                node3_incoming_tgl_prev <= node3_incoming_tgl;
                node3_outgoing_data <= node3_incoming_data;
            end
        end
    end

endmodule
