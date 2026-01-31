// Serial 8N1 receive with variable baudrate
module rx_uart
(
    input clk,                          // assumes it's 27MHz
    input [15:0] baud_div,              // counter value for baud calculation (e.g. F_CLK/BAUD == baud_div)
    input rx_pin,                       // UART assigned pin
    input rx_read,                      // indicates when you read the byte to clear the rx_done pin
    output reg rx_done,                 // (out) indicates a character is ready
    output reg [7:0] rx_byte            // (out) the character that was read
);
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] START_BIT = 3'd1;
    localparam [2:0] DATA_BITS = 3'd2;
    localparam [2:0] STOP_BIT = 3'd3;
    reg [2:0] state;
    reg [15:0] bit_timer;
    reg [2:0] bit_index;

    initial begin
        state = IDLE;
        rx_done = 1'b0;
    end

    always @(posedge clk) begin
        if (rx_read) begin
            // clear done flag since we read the byte
            rx_done <= 0;
        end
        case (state)
            // IDLE waiting or a low pulse.  
            IDLE: begin
                if (~rx_pin) begin              // going low is the start of a byte
                    state <= START_BIT;
                    bit_timer <= (baud_div >> 1);  // wait half for a LOW START pulse
                    bit_index <= 0;
                    rx_byte <= 0;
                end
            end

            START_BIT: begin
                if (bit_timer == 0) begin
                    if (~rx_pin) begin // Verify it's still low (avoid glitches)
                        state <= DATA_BITS;
                        bit_timer <= baud_div;
                        bit_index <= 0;
                        rx_byte <= 0;
                    end else state <= IDLE;
                end else bit_timer <= bit_timer - 1'b1;
            end

            // read the 8 data bits
            DATA_BITS: begin
                if (!bit_timer) begin
                    // store the next bit
                    rx_byte[bit_index] <= rx_pin;
                    // reset the timer
                    bit_timer <= baud_div;
                    // if we have more bits increment the index and loop
                    if (bit_index < 7) begin
                        bit_index <= bit_index + 1'b1;
                    end else begin
                    // otherwise transition to waiting for the STOP bit
                        state <= STOP_BIT;
                    end
                end else begin
                    bit_timer <= bit_timer - 1'b1;
                end
            end

            // wait for the STOP bit, note we don't check if it's low...
            STOP_BIT: begin
                if (!bit_timer) begin
                    rx_done <= 1'b1;
                    state <= IDLE;
                end else begin
                    bit_timer <= bit_timer - 1'b1;
                end
            end
            default: state <= IDLE;
        endcase
    end
endmodule

// Serial 8N1 transmitter with variable baudrate
module tx_uart
(
    input clk,                          // assumes it's 27MHz
    input [15:0] baud_div,              // counter value for baud calculation (e.g. F_CLK/BAUD == baud_div)
    input start_tx,                     // start transmitting whatever is in data_in (which is latched after the first cycle)
    input [7:0] data_in,
    output reg tx_pin,                  // (out) the TX pin
    output reg tx_started,              // (out) Indicates transmission started
    output reg tx_done                  // (out) indicates TX done
);
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] START_BIT = 3'd1;
    localparam [2:0] DATA_BITS = 3'd2;
    localparam [2:0] STOP_BIT = 3'd3;
    reg [2:0] state;
    reg [15:0] bit_timer;
    reg [2:0] bit_index;
    reg [7:0] data_latch;

    initial begin
        state = IDLE;
        tx_pin = 1'b1;
        tx_done = 1'b1;
    end

    always @(posedge clk) begin
        case (state)
            IDLE: begin
                tx_pin <= 1'b1; // UART idle is HIGH
                if (start_tx) begin
                    data_latch <= data_in;
                    bit_timer  <= baud_div;
                    bit_index  <= 0;
                    state      <= START_BIT;
                    tx_started <= 1'b1;
                    tx_done    <= 1'b0;
                end
            end

            START_BIT: begin
                tx_pin <= 1'b0; // Pull low for START
                if (!bit_timer) begin
                    bit_timer <= baud_div;
                    state     <= DATA_BITS;
                end else begin
                    bit_timer <= bit_timer - 1'b1;
                end
            end

            DATA_BITS: begin
                tx_pin <= data_latch[bit_index]; // Send current bit
                if (!bit_timer) begin
                    bit_timer <= baud_div;
                    if (bit_index == 7) begin
                        state <= STOP_BIT;
                    end else begin
                        bit_index <= bit_index + 1'b1;
                    end
                end else begin
                    bit_timer <= bit_timer - 1'b1;
                end
            end

            STOP_BIT: begin
                tx_pin <= 1'b1; // Pull high for STOP
                if (!bit_timer) begin
                    tx_done <= 1'b1;
                    tx_started <= 1'b0;
                    state <= IDLE;
                end else begin
                    bit_timer <= bit_timer - 1'b1;
                end
            end
            default: state <= IDLE;
        endcase
    end
endmodule

module uart#(parameter FIFO_DEPTH=64, RX_ENABLE=1, TX_ENABLE=1)
(
    input clk,                      // main clock
    input [15:0] baud_div,          // counter value for baud calculation (e.g. F_CLK/BAUD == baud_div)
    input uart_tx_start,            // signal we want to load uart_tx_data_in into the TX FIFO
    input [7:0] uart_tx_data_in,    // TX data
    output uart_tx_pin,             // (out) pin for transmitting on
    output uart_tx_fifo_full,       // (out) true if the FIFO is currently full

    input uart_rx_pin,              // pin to RX from
    input uart_rx_read,             // signal that we read a byte
    output uart_rx_ready,           // (out) signal that an output byte is available
    output [7:0] uart_rx_byte       // (out) the RX byte
);
    // note: things starting with uart_ are input/outputs to this module (other than clk)

    generate
        if (TX_ENABLE) begin : tx_gen
            // local TX state 
            reg [7:0] tx_fifo[FIFO_DEPTH-1:0];
            reg [7:0] tx_send;
            reg tx_start;
            wire tx_done;
            wire tx_started;
            reg [$clog2(FIFO_DEPTH)-1:0] tx_fifo_wptr;
            reg [$clog2(FIFO_DEPTH)-1:0] tx_fifo_rptr;

            // instantiate a transmitter and a receiver
            tx_uart txuart (
                .clk(clk),
                .baud_div(baud_div),
                .start_tx(tx_start), 
                .data_in(tx_send), 
                .tx_pin(uart_tx_pin), 
                .tx_started(tx_started), 
                .tx_done(tx_done)
            );

            initial begin
                tx_start = 0;
                tx_fifo_wptr = 0;
                tx_fifo_rptr = 0;
            end

            // Output signals are combinatorial
            assign uart_tx_fifo_full = ((tx_fifo_wptr + 1) == tx_fifo_rptr);

            always @(posedge clk) begin
                // ===== TX =====
                if (uart_tx_start && !uart_tx_fifo_full) begin
                    // user wants to transmit a byte and the fifo isn't full so store it in the fifo
                    tx_fifo[tx_fifo_wptr] <= uart_tx_data_in;
                    tx_fifo_wptr <= tx_fifo_wptr + 1'd1;
                end

                // if the transmitter started acknowledge it by stop requesting a transmit (otherwise it'll keep transmitting the same byte)
                if (tx_started) begin
                    tx_start <= 1'b0;
                end

                // if the transmission is done, and we haven't yet queued up a byte and there is a byte to send...
                if (tx_done && (tx_fifo_wptr != tx_fifo_rptr) && !tx_start) begin
                    tx_send <= tx_fifo[tx_fifo_rptr]; 
                    tx_fifo_rptr <= tx_fifo_rptr + 1'd1;
                    tx_start <= 1'b1;
                end
            end
        end else begin :tx_stub
            assign uart_tx_pin = 1'b1;
            assign uart_tx_fifo_full = 1'b1;
        end
    endgenerate

    generate
        if (RX_ENABLE) begin : rx_gen
            // local RX state
            reg [7:0] rx_fifo[FIFO_DEPTH-1:0];
            reg [$clog2(FIFO_DEPTH)-1:0] rx_fifo_wptr;
            reg [$clog2(FIFO_DEPTH)-1:0] rx_fifo_rptr;
            reg rx_read;
            wire rx_done;
            wire [7:0] rx_byte;
            reg [1:0] rx_sync_pipe;
            assign uart_rx_ready = (rx_fifo_wptr != rx_fifo_rptr);
            assign uart_rx_byte = rx_fifo[rx_fifo_rptr];

            initial begin
                rx_read = 0;
                rx_fifo_wptr = 0;
                rx_fifo_rptr = 0;
            end

            rx_uart rxuart (
                .clk(clk), 
                .baud_div(baud_div),
                .rx_pin(rx_sync_pipe[1]), 
                .rx_read(rx_read), 
                .rx_done(rx_done), 
                .rx_byte(rx_byte)
            );

            always @(posedge clk) begin
                // ===== RX =====
                rx_sync_pipe <= {rx_sync_pipe[0], uart_rx_pin};
                // if the user wants something from the fifo and there is a byte advance the read pointer
                if (uart_rx_read && rx_fifo_rptr != rx_fifo_wptr) begin
                    // note the output is combinatorial above ...
                    rx_fifo_rptr <= rx_fifo_rptr + 1'd1;
                end

                // if an RX finished store it in the fifo if room and then acknowledge the read
                if (rx_done && !rx_read) begin
                    // read a byte if we have room
                    if ((rx_fifo_wptr + 1) != rx_fifo_rptr) begin
                        rx_fifo[rx_fifo_wptr] <= rx_byte;
                        rx_fifo_wptr <= rx_fifo_wptr + 1'd1;
                    end
                    rx_read <= 1;
                end else begin
                    // clear the read acknowledgement
                    if (!rx_done) begin
                        rx_read <= 0;
                    end
                end
            end
        end else begin : rx_stub
            assign uart_rx_ready = 1'b0;
            assign uart_rx_byte = 8'h00;
        end
    endgenerate
endmodule

module uart_hex_logger
(
    input clk,
    input [15:0] baud_div,// counter value for baud calculation (e.g. F_CLK/BAUD == baud_div)
    input trigger,
    input [15:0] hex_val, // The code you want to print (e.g., 0xABCD)
    output tx_pin,
    output reg busy       // Tells the top module we are currently printing
);

    reg [7:0]  tx_data;
    reg        tx_start;
    wire       tx_fifo_full;

    // Instantiate your existing UART
    uart #(.FIFO_DEPTH(16), .RX_ENABLE(0)) logger_uart (
        .clk(clk),
        .baud_div(baud_div),
        .uart_tx_start(tx_start),
        .uart_tx_data_in(tx_data),
        .uart_tx_pin(tx_pin),
        .uart_tx_fifo_full(tx_fifo_full),
        .uart_rx_pin(1'b1), .uart_rx_read(1'b1), .uart_rx_ready(), .uart_rx_byte()); // assign defaults so they're driven

    reg [2:0] state;
    reg [2:0] digit_count; // 0 to 4 (4 digits + maybe a space or newline)
    reg [15:0] val_latch;

    localparam IDLE = 0, CONVERT = 1, WAIT_UART = 2, SEND_CR = 3, SEND_LF = 4;

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
                if (!tx_fifo_full) begin
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
                if (!tx_fifo_full) begin
                    tx_data <= 8'h0D; // Carriage Return (\r)
                    tx_start <= 1;
                    state <= SEND_LF;
                end
            end

            SEND_LF: begin
                tx_start <= 0; // Clear the start from the CR cycle
                if (!tx_fifo_full) begin
                    tx_data <= 8'h0A; // Line Feed (\n)
                    tx_start <= 1;
                    state <= IDLE;    // Now we are actually done
                end
            end
    endcase
    end
endmodule

`define USE_HEX_LOGGER
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