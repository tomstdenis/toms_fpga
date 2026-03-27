
module top(input clk, output uart_tx, input uart_rx, inout [7:0] gpio, input pla_clk);

    localparam
        PINS = 16,
        TERMS = 32,
        W_WIDTH = 2 * (PINS + PINS + 3), 							// width of the AND block input (determines how many fuses are needed per AND)
        TOTAL_FUSES	= 2 * PINS + PINS * TERMS + (1 + W_WIDTH) * TERMS;

    localparam
        PGM_BITS = TOTAL_FUSES + PINS;

    reg [3:0] rst_a = 4'b0000;
    wire rst_n = rst_a[3];

    always @(posedge clk) begin
        rst_a <= {rst_a[2:0], 1'b1};
    end

    wire [PINS-1:0] in_sig;
    wire [PINS-1:0] out_sig;
    reg [PGM_BITS-1:0] fuses; // fuses plus output_ens

    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin : gpio_mux
            assign gpio[i] = fuses[TOTAL_FUSES+i] ? out_sig[i] : 1'bz;
        end
    endgenerate
    assign in_sig[7:0] = gpio[7:0];
    assign in_sig[PINS-1:8] = out_sig[PINS-1:8];

    pla #(.PINS(PINS), .TERMS(TERMS)) demo_pla(
        .clk(pla_clk), .rst_n(rst_n),
        .in_sig(in_sig), .out_sig(out_sig),
        .fuses(fuses[TOTAL_FUSES-1:0]));

    reg uart_tx_start;
    reg [7:0] uart_tx_data_in;
    wire uart_tx_fifo_full;
    wire uart_tx_fifo_empty;

    reg uart_rx_read;
    wire uart_rx_ready;
    wire [7:0] uart_rx_byte;
    wire [15:0] uart_baud = 27_000_000 / 115_200;

    uart #(.FIFO_DEPTH(4), .RX_ENABLE(1), .TX_ENABLE(1)) mr_talky (
        .clk(clk), .rst_n(rst_n),
        .baud_div(uart_baud),
        .uart_tx_start(uart_tx_start),
        .uart_tx_data_in(uart_tx_data_in),
        .uart_tx_pin(uart_tx),
        .uart_tx_fifo_full(uart_tx_fifo_full),
        .uart_tx_fifo_empty(uart_tx_fifo_empty),
        .uart_rx_pin(uart_rx),
        .uart_rx_read(uart_rx_read),
        .uart_rx_ready(uart_rx_ready),
        .uart_rx_byte(uart_rx_byte));

    reg [7:0] fuses_sum;
    reg [15:0] bit_idx;
    reg [3:0] state;
    localparam
        STATE_IDLE=0,
        STATE_WAIT=1,
        STATE_STORE=2,
        STATE_SEND_SUM=3,
        STATE_SEND_WAIT=4;
    always @(posedge clk) begin
        if (!rst_n) begin
            bit_idx   <= 0;
            fuses_sum <= 0;
            state     <= STATE_IDLE;
        end else begin
            case(state)
                STATE_IDLE:
                begin
                    if (bit_idx == PGM_BITS) begin
                        bit_idx  <= 0;
                        state    <= STATE_SEND_SUM;
                    end else begin
                        if (uart_rx_ready) begin
                            uart_rx_read <= 1;
                            state        <= STATE_WAIT;
                        end
                    end
                end
                STATE_WAIT:
                begin
                    uart_rx_read <= 0;
                    state        <= STATE_STORE;
                end
                STATE_STORE:
                begin
                    fuses          <= {fuses[PGM_BITS-2:0], uart_rx_byte == 8'hAA ? 1'b0 : 1'b1};
                    fuses_sum      <= (fuses_sum + fuses_sum + fuses_sum + uart_rx_byte);
                    state          <= STATE_IDLE;
                    bit_idx        <= bit_idx + 1'b1;
                end
                STATE_SEND_SUM:
                begin
                    uart_tx_data_in <= fuses_sum;
                    uart_tx_start   <= 1;
                    state           <= STATE_SEND_WAIT;
                end
                STATE_SEND_WAIT:
                begin
                    uart_tx_start   <= 0;
                    fuses_sum       <= 0;
                    state           <= STATE_IDLE;
                end
                default: begin end
            endcase
        end
    end
endmodule