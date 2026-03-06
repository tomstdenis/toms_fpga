module top(
    input clk,
    output uart_tx,
    input uart_rx);

    localparam
        BITS=64,
        ENABLE=1;
   
    wire pll1_clk; // 50
    wire pll2_clk; // 75
	wire pll3_clk; // 100
	wire pll4_clk; // 83.3333

	wire pll1_locked;
	wire pll2_locked;
	wire pll3_locked;
	wire pll4_locked;
	
	pll1 pll1(.clkin(clk), .clkout0(pll1_clk), .locked(pll1_locked));
	pll2 pll2(.clkin(clk), .clkout0(pll2_clk), .locked(pll2_locked));
	pll3 pll3(.clkin(clk), .clkout0(pll3_clk), .locked(pll3_locked));
	pll4 pll4(.clkin(clk), .clkout0(pll4_clk), .locked(pll4_locked));

    // RESET
    reg [3:0] rstcnt = 4'b0;
    assign rst_n = rstcnt[3];

    // drive 50MHz reset from the 25MHz reset.
    reg [2:0] rst_n_50_sync = 3'b0;
    always @(posedge pll1_clk) begin
		if (pll1_locked) begin
			rst_n_50_sync <= {rst_n_50_sync[1:0], rst_n}; // rst_n is from the 25MHz logic
		end
    end
    wire rst_n_50 = rst_n_50_sync[2];

    // drive 75MHz reset from the 25MHz reset.
    reg [2:0] rst_n_75_sync = 3'b0;
    always @(posedge pll2_clk) begin
		if (pll2_locked) begin
			rst_n_75_sync <= {rst_n_75_sync[1:0], rst_n}; // rst_n is from the 25MHz logic
		end
    end
    wire rst_n_75 = rst_n_75_sync[2];

    // drive 100MHz reset from the 25MHz reset.
    reg [2:0] rst_n_100_sync = 3'b0;
    always @(posedge pll3_clk) begin
		if (pll3_locked) begin
			rst_n_100_sync <= {rst_n_100_sync[1:0], rst_n}; // rst_n is from the 25MHz logic
		end
    end
    wire rst_n_100 = rst_n_100_sync[2];

    // drive 83.3333MHz reset from the 25MHz reset.
    reg [2:0] rst_n_83_sync = 3'b0;
    always @(posedge pll4_clk) begin
		if (pll4_locked) begin
			rst_n_83_sync <= {rst_n_83_sync[1:0], rst_n}; // rst_n is from the 25MHz logic
		end
    end
    wire rst_n_83 = rst_n_83_sync[2];

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

    wire [15:0] baud_div = 25_000_000 / 115_200;

    // These are the debug nodes, in a real design
    // there would be one of these (at least) per module that can be debugged with it
    // they wouldn't be placed all in the same module like this
    // node0 -- Runs at 50MHz
    serial_debug #(.BITS(BITS), .ENABLE(ENABLE)) node0(
        .clk(pll1_clk), .rst_n(rst_n_50),
        .prescaler(4'h4),									// 2x faster than base so prescale == 2 * 2 ==4
        .rx_data(node0_rx_data), .rx_clk(node0_rx_clk),
        .tx_data(node0_tx_data), .tx_clk(node0_tx_clk),
        .debug_outgoing_data(node0_outgoing_data),
        .debug_incoming_tgl(node0_incoming_tgl), .debug_incoming_data(node0_incoming_data),
        .identity(node0_identity));

    // node1 -- runs at 75MHz 
    serial_debug #(.BITS(BITS), .ENABLE(ENABLE)) node1(
        .clk(pll2_clk), .rst_n(rst_n_75),
        .prescaler(4'h6),                                   // node1 runs 3x faster than the other nodes so it needs a 3x prescaler
        .rx_data(node0_tx_data), .rx_clk(node0_tx_clk),
        .tx_data(node1_tx_data), .tx_clk(node1_tx_clk),
        .debug_outgoing_data(node1_outgoing_data),
        .debug_incoming_tgl(node1_incoming_tgl), .debug_incoming_data(node1_incoming_data),
        .identity(node1_identity));

    // node2 -- runs at 100MHz
    serial_debug #(.BITS(BITS), .ENABLE(ENABLE)) node2(
        .clk(pll3_clk), .rst_n(rst_n_100),
        .prescaler(4'h8),									// 4x faster than base so prescale == 2 * 4 == 8
        .rx_data(node1_tx_data), .rx_clk(node1_tx_clk),
        .tx_data(node2_tx_data), .tx_clk(node2_tx_clk),
        .debug_outgoing_data(node2_outgoing_data),
        .debug_incoming_tgl(node2_incoming_tgl), .debug_incoming_data(node2_incoming_data),
        .identity(node2_identity));

    // node3 -- runs at 83.3333MHz
    serial_debug #(.BITS(BITS), .ENABLE(ENABLE)) node3(
        .clk(pll4_clk), .rst_n(rst_n_83),
        .prescaler(4'h8),                               // at 83.333MHz we need 4x the prescaler since 3.33 isn't an option
        .rx_data(node2_tx_data), .rx_clk(node2_tx_clk),
        .tx_data(node3_tx_data), .tx_clk(node3_tx_clk),
        .debug_outgoing_data(node3_outgoing_data),
        .debug_incoming_tgl(node3_incoming_tgl), .debug_incoming_data(node3_incoming_data),
        .identity(node3_identity));

    // This is the UART that binds to the debugger input node0 and output node3
    // You'd put one of these per debug loop to grant access to the outside world to the 
    // debug loop.
    // uartdebug -- runs at 25MHz
    serial_debug_uart #(.BITS(BITS), .ENABLE(ENABLE)) debug_uart(
        .clk(clk), .rst_n(rst_n),
        .prescaler(4'h2),
        .debug_tx_data(node3_tx_data), .debug_tx_clk(node3_tx_clk),
        .debug_rx_data(node0_rx_data), .debug_rx_clk(node0_rx_clk),
        .uart_bauddiv(baud_div), .uart_rx_pin(uart_rx), .uart_tx_pin(uart_tx));

    // node1 resides in the pll_clk domain so we manipulate it here
    always @(posedge pll1_clk) begin
        if (!rst_n_50) begin
            node0_outgoing_data <= 0;
            node0_incoming_tgl_prev <= 0;
            node0_identity <= 32'h11223300;
        end else begin
            if (node0_incoming_tgl_prev != node0_incoming_tgl) begin
                node0_incoming_tgl_prev <= node0_incoming_tgl;
                node0_outgoing_data <= node0_incoming_data;
            end
        end
    end

    // node2 resides in the pll2_clk domain so we manipulate it here
    always @(posedge pll2_clk) begin
        if (!rst_n_75) begin
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

    // node3 resides in the pll3_clk domain so we manipulate it here
    always @(posedge pll3_clk) begin
        if (!rst_n_100) begin
            node2_outgoing_data <= 0;
            node2_incoming_tgl_prev <= 0;
            node2_identity <= 32'h11223302;
        end else begin
            if (node2_incoming_tgl_prev != node2_incoming_tgl) begin
                node2_incoming_tgl_prev <= node2_incoming_tgl;
                node2_outgoing_data <= node2_incoming_data;
            end
        end
    end

    // node4 resides in the pll4_clk domain so we manipulate it here
    always @(posedge pll4_clk) begin
        if (!rst_n_83) begin
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
    end
endmodule
