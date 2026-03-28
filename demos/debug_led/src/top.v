module top(
    input clk,
    output uart_tx,
    input uart_rx,
    output [3:0] led);

    localparam
        BITS=64,
        ENABLE=1,
        USE_MEM=0;
   
    wire pll_clk;
    wire pll2_clk;

    // 81 MHz PLL
    Gowin_rPLL debug_node_1_pll(
        .clkout(pll_clk), //output clkout
        .clkin(clk) //input clkin
    );

    // 75 MHz PLL2
    Gowin_rPLL2 debug_node_3_pll(
        .clkout(pll2_clk), //output clkout
        .clkin(clk) //input clkin
    );

    // RESET
    reg [3:0] rstcnt = 4'b0;
    assign rst_n = rstcnt[3];

    // drive 81MHz reset from the 27MHz reset.
    reg [2:0] rst_n_81_sync;
    always @(posedge pll_clk) begin
        rst_n_81_sync <= {rst_n_81_sync[1:0], rst_n}; // rst_n is from the 27MHz logic
    end
    wire rst_n_81 = rst_n_81_sync[2];

    // drive 75MHz reset from the 27MHz reset.
    reg [2:0] rst_n_75_sync;
    always @(posedge pll2_clk) begin
        rst_n_75_sync <= {rst_n_75_sync[1:0], rst_n}; // rst_n is from the 27MHz logic
    end
    wire rst_n_75 = rst_n_75_sync[2];

    wire node0_rx_data;                     // node0 input (which is output from debug_uart)
    wire node0_rx_clk;
    wire node0_tx_data;                     // node0 output is node1's input
    wire node0_tx_clk;
    wire node1_tx_data;                     // node1 output is node2's input
    wire node1_tx_clk;
    wire node2_tx_data;                     // node2 output is node3's input
    wire node2_tx_clk;
    wire node3_tx_data;                     // node3 output is tx_data input on debug_uart
    wire node3_tx_clk;

    // combinatorially assign the LEDs to avoid CDC issues.
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

    // These are the debug nodes, in a real design
    // there would be one of these (at least) per module that can be debugged with it
    // they wouldn't be placed all in the same module like this
    // node0 -- Runs at 27MHz
    serial_debug #(.BITS(BITS), .ENABLE(ENABLE), .USE_MEM(USE_MEM)) node0(
        .clk(clk), .rst_n(rst_n),
        .prescaler(4'h2),
        .rx_data(node0_rx_data), .rx_clk(node0_rx_clk),
        .tx_data(node0_tx_data), .tx_clk(node0_tx_clk),
        .debug_outgoing_data(node0_outgoing_data),
        .debug_incoming_tgl(node0_incoming_tgl), .debug_incoming_data(node0_incoming_data),
        .identity(node0_identity));

    // node1 -- runs at 81MHz 
    serial_debug #(.BITS(BITS), .ENABLE(ENABLE), .USE_MEM(USE_MEM)) node1(
        .clk(pll_clk), .rst_n(rst_n_81),
        .prescaler(4'h6),                                   // node1 runs 3x faster than the other nodes so it needs a 3x prescaler
        .rx_data(node0_tx_data), .rx_clk(node0_tx_clk),
        .tx_data(node1_tx_data), .tx_clk(node1_tx_clk),
        .debug_outgoing_data(node1_outgoing_data),
        .debug_incoming_tgl(node1_incoming_tgl), .debug_incoming_data(node1_incoming_data),
        .identity(node1_identity));

    // node2 -- runs at 27MHz
    serial_debug #(.BITS(BITS), .ENABLE(ENABLE), .USE_MEM(USE_MEM)) node2(
        .clk(clk), .rst_n(rst_n),
        .prescaler(4'h2),
        .rx_data(node1_tx_data), .rx_clk(node1_tx_clk),
        .tx_data(node2_tx_data), .tx_clk(node2_tx_clk),
        .debug_outgoing_data(node2_outgoing_data),
        .debug_incoming_tgl(node2_incoming_tgl), .debug_incoming_data(node2_incoming_data),
        .identity(node2_identity));

    // node3 -- runs at 75MHz
    serial_debug #(.BITS(BITS), .ENABLE(ENABLE), .USE_MEM(USE_MEM)) node3(
        .clk(pll2_clk), .rst_n(rst_n_75),
        .prescaler(4'h6),                               // at 75MHz we need 3x the prescaler since 2.77 isn't an option
        .rx_data(node2_tx_data), .rx_clk(node2_tx_clk),
        .tx_data(node3_tx_data), .tx_clk(node3_tx_clk),
        .debug_outgoing_data(node3_outgoing_data),
        .debug_incoming_tgl(node3_incoming_tgl), .debug_incoming_data(node3_incoming_data),
        .identity(node3_identity));

    // This is the UART that binds to the debugger input node0 and output node3
    // You'd put one of these per debug loop to grant access to the outside world to the 
    // debug loop.
    // uartdebug -- runs at 27MHz
    serial_debug_uart #(.BITS(BITS), .ENABLE(ENABLE), .USE_MEM(USE_MEM)) debug_uart(
        .clk(clk), .rst_n(rst_n),
        .prescaler(4'h2),
        .debug_tx_data(node3_tx_data), .debug_tx_clk(node3_tx_clk),
        .debug_rx_data(node0_rx_data), .debug_rx_clk(node0_rx_clk),
        .uart_bauddiv(baud_div), .uart_rx_pin(uart_rx), .uart_tx_pin(uart_tx));

    // node1 resides in the pll_clk domain so we manipulate it here
    always @(posedge pll_clk) begin
        if (!rst_n_81) begin
            node1_outgoing_data <= 0;
            node1_incoming_tgl_prev <= 0;
            node1_identity <= 32'h11223301;
        end else begin
            if (node1_incoming_tgl_prev != node1_incoming_tgl) begin
                node1_incoming_tgl_prev <= node1_incoming_tgl;
                node1_outgoing_data <= node1_incoming_data;
            end
        end
    end

    // node3 resides in the pll_clk domain so we manipulate it here
    always @(posedge pll2_clk) begin
        if (!rst_n_75) begin
            node3_outgoing_data <= 0;
            node3_incoming_tgl_prev <= 0;
            node3_identity <= 32'h11223303;
        end else begin
            if (node3_incoming_tgl_prev != node3_incoming_tgl) begin
                node3_incoming_tgl_prev <= node3_incoming_tgl;
                node3_outgoing_data <= node3_incoming_data;
            end
        end
    end

    always @(posedge clk) begin
        rstcnt <= {rstcnt[2:0], 1'b1};
        if (!rst_n) begin
            node0_outgoing_data <= 0;
            node2_outgoing_data <= 0;
            node0_incoming_tgl_prev <= 0;
            node2_incoming_tgl_prev <= 0;
            node0_identity <= 32'h11223300;
            node2_identity <= 32'h11223302;
        end else begin
            if (node0_incoming_tgl_prev != node0_incoming_tgl) begin
                node0_incoming_tgl_prev <= node0_incoming_tgl;
                node0_outgoing_data <= node0_incoming_data;
            end
            if (node2_incoming_tgl_prev != node2_incoming_tgl) begin
                node2_incoming_tgl_prev <= node2_incoming_tgl;
                node2_outgoing_data <= node2_incoming_data;
            end
        end
    end
endmodule
