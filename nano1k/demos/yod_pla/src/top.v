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
    reg [PGM_BITS+16-1:0] fuses; // fuses plus output_ens
    assign gpio[0] = fuses[TOTAL_FUSES+0] ? out_sig[0] : 1'bz;
    assign gpio[1] = fuses[TOTAL_FUSES+1] ? out_sig[1] : 1'bz;
    assign gpio[2] = fuses[TOTAL_FUSES+2] ? out_sig[2] : 1'bz;
    assign gpio[3] = fuses[TOTAL_FUSES+3] ? out_sig[3] : 1'bz;
    assign gpio[4] = fuses[TOTAL_FUSES+4] ? out_sig[4] : 1'bz;
    assign gpio[5] = fuses[TOTAL_FUSES+5] ? out_sig[5] : 1'bz;
    assign gpio[6] = fuses[TOTAL_FUSES+6] ? out_sig[6] : 1'bz;
    assign gpio[7] = fuses[TOTAL_FUSES+7] ? out_sig[7] : 1'bz;
    assign gpio[8] = fuses[TOTAL_FUSES+8] ? out_sig[8] : 1'bz;
    assign gpio[9] = fuses[TOTAL_FUSES+9] ? out_sig[9] : 1'bz;
    assign gpio[10] = fuses[TOTAL_FUSES+10] ? out_sig[10] : 1'bz;
    assign gpio[11] = fuses[TOTAL_FUSES+11] ? out_sig[11] : 1'bz;
    assign gpio[12] = fuses[TOTAL_FUSES+12] ? out_sig[12] : 1'bz;
    assign gpio[13] = fuses[TOTAL_FUSES+13] ? out_sig[13] : 1'bz;
    assign gpio[14] = fuses[TOTAL_FUSES+14] ? out_sig[14] : 1'bz;
    assign gpio[15] = fuses[TOTAL_FUSES+15] ? out_sig[15] : 1'bz;

    assign in_sig = gpio;

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

    reg [7:0] byte_idx;
    reg [2:0] state;
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
                    if (byte_idx == (PGM_BYTES+2)) begin
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