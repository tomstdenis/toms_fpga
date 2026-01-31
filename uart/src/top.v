//`define USE_HEX_LOGGER
module top
(
    input clk,
    input rx_pin,
    output tx_pin
);
    wire [15:0] uart_baud_div = 16'd234; // at 27MHz this results in 115200 baud

`ifdef USE_HEX_LOGGER
    // --- HEX LOGGER MODE ---
    reg  [15:0] debug_val = 0;
    reg         log_trigger = 0;
    wire        log_busy;
    reg [31:0]  counter = 0;

    uart_hex_logger logger (
        .clk(clk),
        .baud_div(uart_baud_div),
        .trigger(log_trigger),
        .hex_val(debug_val),
        .tx_pin(tx_pin),
        .busy(log_busy)
    );

    always @(posedge clk) begin
        counter <= counter + 1;
        if (counter[23]) begin
             log_trigger <= 1'b1;
             counter <= 0;
             debug_val <= debug_val + 1'b1;
        end else begin
             log_trigger <= 1'b0;
        end
    end
`else
    reg uart_tx_start_bit = 'd0;
    reg [7:0] uart_tx_data_byte;
    wire uart_tx_fifo_full;
    wire uart_rx_ready;                  // the rx_uart's done pin (e.g. a byte is ready)

    reg uart_rx_read = 'd0;             // indicates to the rx_uart whether we read the byte or not
    wire [7:0] uart_rx_byte;            // the rx_uarts output byte

    // instantiate our baud rate configurable FIFO based UART
    uart myuart(.clk(clk), .baud_div(uart_baud_div),
                .uart_tx_start(uart_tx_start_bit), .uart_tx_data_in(uart_tx_data_byte), .uart_tx_pin(tx_pin), .uart_tx_fifo_full(uart_tx_fifo_full),
                .uart_rx_pin(rx_pin), .uart_rx_read(uart_rx_read), .uart_rx_ready(uart_rx_ready), .uart_rx_byte(uart_rx_byte));

    always @(posedge clk) begin
        // if there's a byte to read and we haven't read anything
        if (uart_rx_ready && !uart_rx_read) begin
            // latch the byte
            uart_tx_data_byte <= uart_rx_byte;
            
            // try to echo the character back
            if (!uart_tx_fifo_full) begin
                // wait for TX of any previous bytes to be done
                uart_tx_start_bit <= 1'b1; // Trigger the TX!
                uart_rx_read <= 1'b1;      // Acknowledge the RX
            end
        end else begin
            // clear the TX start bit
            uart_tx_start_bit <= 1'b0;
            if (!uart_rx_ready) begin
                uart_rx_read <= 1'b0;      // Reset the handshake
            end
        end
    end        
`endif
endmodule