// Simple TX only module that lets you trivially fling out a 16-bit HEX code that can be used to log where in the design you are.
module uart_hex_logger
(
    input clk,
    input rst,              // active low reset
    input [15:0] baud_div,  // counter value for baud calculation (e.g. F_CLK/BAUD == baud_div)
    input trigger,          // active high trigger
    input [15:0] hex_val,   // The code you want to print (e.g., 0xABCD)
    output tx_pin,          // pin for the UART 8N1 output
    output reg busy         // Tells the top module we are currently printing
);

    reg [7:0]  tx_data;
    reg        tx_start;
    wire       tx_fifo_full;

    // Instantiate your existing UART
    uart #(.FIFO_DEPTH(8), .RX_ENABLE(0)) logger_uart (
        .clk(clk),
        .rst(rst),
        .baud_div(baud_div),
        .uart_tx_start(tx_start),
        .uart_tx_data_in(tx_data),
        .uart_tx_pin(tx_pin),
        .uart_tx_fifo_full(tx_fifo_full),
        .uart_rx_pin(1'b1), .uart_rx_read(1'b1), .uart_rx_ready(), .uart_rx_byte()); // assign defaults so they're driven

    reg [2:0] state;
    reg [2:0] digit_count; // 0 to 4 (4 digits + maybe a space or newline)
    reg [15:0] val_latch;

    localparam 
        IDLE       = 0,
        CONVERT    = 1,
        WAIT_UART  = 2,
        SEND_CR    = 3,
        SEND_LF    = 4,
        WAIT_LF    = 5;

    // Helper logic to get the current 4-bit nibble
    reg [3:0] current_nibble;
    always @(*) begin
        case(digit_count)
            3'd0: current_nibble = val_latch[15:12];
            3'd1: current_nibble = val_latch[11:8];
            3'd2: current_nibble = val_latch[7:4];
            3'd3: current_nibble = val_latch[3:0];
            default: current_nibble = 4'h0;
        endcase
    end

    always @(posedge clk) begin
        if (!rst) begin 
            state <= 0;
            digit_count <= 0;
            val_latch <= 0;
            tx_data <= 0;
            tx_start <= 0;
        end else begin
            case(state)
                IDLE: begin
                    busy <= 0;
                    tx_start <= 0;
                    if (trigger) begin
                        val_latch <= hex_val;
                        digit_count <= 0;
                        busy <= 1;
                        state <= CONVERT;
                    end
                end

                CONVERT: begin
                    tx_start <= 0;
                    if (!tx_start && !tx_fifo_full) begin
                        // ASCII Conversion math
                        tx_data <= (current_nibble < 4'hA) ? (8'h30 + current_nibble) 
                                                           : (8'h37 + current_nibble);
                        tx_start <= 1;
                        state <= WAIT_UART;
                    end
                end

                WAIT_UART: begin
                    tx_start <= 0;
                    if (digit_count == 3) begin
                        state <= SEND_CR; // Or add a state to send a space/newline
                    end else begin
                        digit_count <= digit_count + 1'b1;
                        state <= CONVERT;
                    end
                end

                SEND_CR: begin
                    tx_start <= 0;
                    if (!tx_start && !tx_fifo_full) begin
                        tx_data <= 8'h0D; // Carriage Return (\r)
                        tx_start <= 1;
                        state <= SEND_LF;
                    end else begin
                        tx_start <= 0;
                    end
                end

                SEND_LF: begin
                    tx_start <= 0;
                    if (!tx_start && !tx_fifo_full) begin
                        tx_data <= 8'h0A; // Line Feed (\n)
                        tx_start <= 1;
                        state <= WAIT_LF;    // Now we are actually done
                    end else begin
                        tx_start <= 0;
                    end
                end
                WAIT_LF: begin
                    tx_start <= 0;
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule
