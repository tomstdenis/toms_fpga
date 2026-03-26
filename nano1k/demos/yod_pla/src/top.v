
// in USE_8GPIO mode we only use 8 total GPIO as inout pins with bit enables
// when this is undefined we use 16 board pins, 8 for input, 8 for output, (in both cases an additional for pla_clk)
`define USE_8GPIO

module top(input clk, input rst_n, input uart_rx, inout [15:0] gpio, input pla_clk);

    localparam
        PINS = 8,
        TERMS = 15,
        W_WIDTH = 2 * (PINS + PINS + 3), 							// width of the AND block input (determines how many fuses are needed per AND)
        TOTAL_FUSES	= 2 * PINS + PINS * TERMS + (1 + W_WIDTH) * TERMS;

    localparam
        PGM_BYTES = (TOTAL_FUSES+7)/8,
        PGM_BITS = 8*(PGM_BYTES);

    wire [15:0] in_sig;
    wire [15:0] out_sig;
    reg [PGM_BITS+8-1:0] fuses; // fuses plus output_ens

`ifdef USE_8GPIO
    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin : gpio_mux
            assign gpio[i] = fuses[TOTAL_FUSES+i] ? out_sig[i] : 1'bz;
        end
    endgenerate
    assign in_sig = gpio;
`else
    assign gpio[15:8] = out_sig[7:0];
    assign in_sig[7:0] = gpio[7:0];
`endif
    pla #(.PINS(PINS), .TERMS(TERMS)) (
        .clk(pla_clk), .rst_n(rst_n),
        .in_sig(in_sig), .out_sig(out_sig),
        .fuses(fuses));

    reg uart_rx_read;
    wire uart_rx_ready;
    wire [7:0] uart_rx_byte;
    wire [15:0] uart_baud = 27_000_000 / 115_200;

    uart #(.FIFO_DEPTH(2), .RX_ENABLE(1), .TX_ENABLE(0)) (
        .clk(clk), .rst_n(rst_n),
        .baud_div(uart_baud),
        .uart_rx_pin(uart_rx),
        .uart_rx_read(uart_rx_read),
        .uart_rx_ready(uart_rx_ready),
        .uart_rx_byte(uart_rx_byte));

    reg [$clog2((PGM_BYTES+1)):0] byte_idx;
    reg [1:0] state;
    localparam
        STATE_IDLE=0,
        STATE_WAIT=1,
        STATE_STORE=2;
    always @(posedge clk) begin
        if (!rst_n) begin
            byte_idx <= 0;
            state <= STATE_IDLE;
        end else begin
            case(state)
                STATE_IDLE:
                begin
                    if (byte_idx == (PGM_BYTES+1)) begin
                        byte_idx <= 0;
                    end
                    if (uart_rx_ready) begin
                        uart_rx_read <= 1;
                        state <= STATE_WAIT;
                    end
                end
                STATE_WAIT:
                begin
                    uart_rx_read <= 0;
                    state <= STATE_STORE;
                end
                STATE_STORE:
                begin
                    fuses[byte_idx * 8 +: 8] <= uart_rx_byte;
                    state <= STATE_IDLE;
                    byte_idx <= byte_idx + 1;
                end
                default: begin end
            endcase
        end
    end
endmodule