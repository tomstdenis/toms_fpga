// memory wrapper around uart
module uart_mem
(
    // common bus in
    input clk,
    input rst,          // active low reset
    input enable,       // active high overall enable
    input wr_en,        // active high write enable (0==read, 1==write)
    input [2:0] addr,   // (000 == baud_l, 001 == baud_h, 010 == status, 011 == data, 100 == int_enables
    input [7:0] i_data,

    // common bus out
    output reg ready,   // active high signal when o_data is ready (or write is done)
    output reg [7:0] o_data,
    output wire irq,    // active high IRQ pin

    // peripheral specific
    input rx_pin,
    output tx_pin
);
    reg [15:0] bauddiv;
    reg uart_tx_start;
    wire uart_tx_fifo_full;
    wire uart_tx_fifo_empty;
    reg tx_fifo_empty_prev;
    wire uart_rx_ready;
    reg rx_ready_prev;
    reg uart_rx_read;
    reg [2:0] state;
    reg [7:0] i_data_latch;
    wire [7:0] rx_byte;
    reg [1:0] int_enables;
    reg [1:0] int_pending;

    localparam
        ISSUE  = 0,
        RETIRE = 1;

    localparam
        UART_BAUD_L_ADDR      = 3'b000,
        UART_BAUD_H_ADDR      = 3'b001,
        UART_STATUS_ADDR      = 3'b010,
        UART_DATA_ADDR        = 3'b011,
        UART_INT_ADDR         = 3'b100,
        UART_INT_PENDING_ADDR = 3'b101;

    localparam
        UART_INT_RX_READY = 2'b01,
        UART_INT_TX_EMPTY = 2'b10;

    uart u1(
        .clk(clk), .rst(rst),
        .baud_div(bauddiv), 
        .uart_tx_start(uart_tx_start), .uart_tx_pin(tx_pin), .uart_tx_fifo_full(uart_tx_fifo_full), .uart_tx_fifo_empty(uart_tx_fifo_empty), .uart_tx_data_in(i_data_latch),
        .uart_rx_pin(rx_pin), .uart_rx_read(uart_rx_read), .uart_rx_ready(uart_rx_ready), .uart_rx_byte(rx_byte));

    // IRQ output is an OR of RX ready 
    assign irq = (int_enables[0] & int_pending[0]) | (int_enables[1] & int_pending[1]);

    always @(posedge clk) begin
        if (!rst) begin
            uart_rx_read <= 0;
            bauddiv <= 0;
            ready <= 0;
            i_data_latch <= 0;
            int_enables <= 0;
            int_pending <= 0;
            tx_fifo_empty_prev <= 1;
            rx_ready_prev <= 0;
            state <= ISSUE;
        end else begin
            // step the IRQ system
            // detect edge of rx_ready and assert it in pending
            if (uart_rx_ready && !rx_ready_prev) begin
                int_pending[0] <= 1'b1;
            end
            // detect edge of tx_fifo_empty and assert it in pending
            if (uart_tx_fifo_empty && !tx_fifo_empty_prev) begin
                int_pending[1] <= 1'b1;
            end
            tx_fifo_empty_prev <= uart_tx_fifo_empty;   // latch TX fifo empty
            rx_ready_prev <= uart_rx_ready;             // latch RX ready

            if (enable && !ready) begin
                case(state)
                    ISSUE:                              // issue commands to the UART block
                        begin
                            i_data_latch <= i_data;
                            if (wr_en) begin
                                case(addr)
                                    UART_BAUD_L_ADDR:
                                        begin // BAUD_L
                                            bauddiv[7:0] <= i_data;
                                        end
                                    UART_BAUD_H_ADDR:
                                        begin // BAUD_H
                                            bauddiv[15:8] <= i_data;
                                        end
                                    UART_STATUS_ADDR:
                                        begin // STATUS
                                        end
                                    UART_DATA_ADDR: 
                                        begin // DATA
                                            if (!uart_tx_fifo_full) begin
                                                uart_tx_start <= 1;
                                            end
                                        end
                                    UART_INT_ADDR:
                                        begin // INT enables
                                            int_enables <= i_data[1:0];
                                        end
                                    UART_INT_PENDING_ADDR:
                                        begin // INT enables
                                            int_pending <= int_pending & ~i_data[1:0];
                                        end
                                    default:
                                        begin end
                                endcase
                            end else begin // reads
                                case(addr)
                                    UART_BAUD_L_ADDR:
                                        begin // BAUD_L
                                            o_data <= bauddiv[7:0];
                                        end
                                    UART_BAUD_H_ADDR:
                                        begin // BAUD_H
                                            o_data <= bauddiv[15:8];
                                        end
                                    UART_STATUS_ADDR:
                                        begin // STATUS
                                            o_data <= {6'b0, uart_tx_fifo_full, uart_rx_ready};
                                        end
                                    UART_DATA_ADDR:
                                        begin // DATA
                                            if (uart_rx_ready) begin
                                                o_data <= rx_byte;
                                                uart_rx_read <= 1;      // tell the UART we read the byte
                                            end
                                        end
                                    UART_INT_ADDR:
                                        begin // INT enables
                                            o_data <= {6'b0, int_enables};
                                        end
                                    UART_INT_PENDING_ADDR:
                                        begin // INT enables
                                            o_data <= {6'b0, int_pending};
                                        end
                                    default:
                                        begin end
                                endcase
                            end
                            state <= RETIRE;
                        end
                    RETIRE: begin                           // de-assert the UART and assert ready
                                uart_rx_read <= 0;
                                uart_tx_start <= 0;
                                ready <= 1;
                            end
                endcase
            end else if (!enable) begin // !enable (need at least one cycle of !enable to clear the ready flag
                ready <= 0;
                state <= ISSUE;
            end
        end
    end
endmodule