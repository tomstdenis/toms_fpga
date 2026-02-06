`timescale 1ns/1ps
`include "uart_mem.vh"

module uart_mem
#(
    parameter ADDR_WIDTH=32,
    parameter DATA_WIDTH=32
)(
    // common bus in
    input clk,
    input rst_n,            // active low reset
    input enable,           // active high overall enable (must go low between commands)
    input wr_en,            // active high write enable (0==read, 1==write)
    input [ADDR_WIDTH-1:0] addr,
    input [DATA_WIDTH-1:0] i_data,
    input [DATA_WIDTH/8-1:0] be,       // lane 0 must be asserted, other lanes can be asserted but they're ignored.

    // common bus out
    output reg ready,       // active high signal when o_data is ready (or write is done)
    output reg [DATA_WIDTH-1:0] o_data,
    output wire irq,        // active high IRQ pin
    output wire bus_err,    // active high error signal

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
    reg error;
    reg delay;

    localparam
        ISSUE  = 0,
        RETIRE = 1;

    uart u1(
        .clk(clk), .rst_n(rst_n),
        .baud_div(bauddiv), 
        .uart_tx_start(uart_tx_start), .uart_tx_pin(tx_pin), .uart_tx_fifo_full(uart_tx_fifo_full), .uart_tx_fifo_empty(uart_tx_fifo_empty), .uart_tx_data_in(i_data_latch),
        .uart_rx_pin(rx_pin), .uart_rx_read(uart_rx_read), .uart_rx_ready(uart_rx_ready), .uart_rx_byte(rx_byte));

    // IRQ output is an OR of RX ready 
    assign irq = (int_enables[0] & int_pending[0]) | (int_enables[1] & int_pending[1]);

    // error output is only valid out of reset
    assign bus_err = enable & error & rst_n;

    always @(posedge clk) begin
        if (!rst_n) begin
            bauddiv <= 0;
            uart_tx_start <= 0;
            uart_rx_read <= 0;
            tx_fifo_empty_prev <= 0;
            rx_ready_prev <= 0;
            uart_rx_read <= 0;
            state <= ISSUE;
            i_data_latch <= 0;
            int_enables <= 0;
            int_pending <= 0;
            ready <= 0;
            error <= 0;
            o_data <= 0;
            delay <= 0;
        end else begin
            // step the IRQ system with edge detectors to ensure interrupts only trigger on transition.
            // detect edge of rx_ready and assert it in pending
            if (uart_rx_ready && !rx_ready_prev) begin
                int_pending[`UART_INT_RX_READY] <= 1'b1;
            end
            // detect edge of tx_fifo_empty and assert it in pending
            if (uart_tx_fifo_empty && !tx_fifo_empty_prev) begin
                int_pending[`UART_INT_TX_EMPTY] <= 1'b1;
            end
            tx_fifo_empty_prev <= uart_tx_fifo_empty;   // latch TX fifo empty
            rx_ready_prev <= uart_rx_ready;             // latch RX ready

            if (enable & ~be[0]) begin                           // we ignore bits [31:8] if they're enabled but you MUST enable bits [7:0]
                error <= 1;
                ready <= 1;                             // assert error and ready so the user knows we've responded
            end else begin
                if (!error & enable & !ready) begin     // only process the command if we're not in an error state and not waiting for the master to acknowledge the previous command
                    case(state)
                        ISSUE:                              // issue commands to the UART block
                            begin
                                if (wr_en) begin
                                    case(addr)
                                        `UART_BAUD_L_ADDR:
                                            begin // BAUD_L
                                                if (be[1]) begin
                                                    bauddiv[15:0] <= i_data[15:0];
                                                end else begin
                                                    bauddiv[7:0] <= i_data[7:0];
                                                end
                                            end
                                        `UART_BAUD_H_ADDR:
                                            begin // BAUD_H
                                                bauddiv[15:8] <= i_data[7:0];
                                            end
                                        `UART_STATUS_ADDR:
                                            begin // STATUS
                                            end
                                        `UART_DATA_ADDR: 
                                            begin // DATA
                                                if (!uart_tx_fifo_full) begin
													i_data_latch <= i_data[7:0];
                                                    uart_tx_start <= ~uart_tx_start;
                                                    delay <= 1;	// UART takes a cycle to consume new byte
                                                end
                                            end
                                        `UART_INT_ADDR:
                                            begin // INT enables
                                                int_enables <= i_data[1:0];
                                                delay <= 1;		// takes an extra cycle to change bus_irq
                                            end
                                        `UART_INT_PENDING_ADDR:
                                            begin // INT enables
                                                int_pending <= int_pending & ~i_data[1:0];
                                                delay <= 1;		// takes an extra cycle to change bus_irq
                                            end
                                        default:
                                            begin
                                                error <= 1; // invalid address
                                                ready <= 1;
                                            end
                                    endcase
                                end else begin // reads
                                    case(addr)
                                        `UART_BAUD_L_ADDR:
                                            begin // BAUD_L
                                                if (be[1]) begin
                                                    o_data <= {16'b0, bauddiv[15:0]};
                                                end else begin
                                                    o_data <= {24'b0, bauddiv[7:0]};
                                                end
                                            end
                                        `UART_BAUD_H_ADDR:
                                            begin // BAUD_H
                                                o_data <= {24'b0, bauddiv[15:8]};
                                            end
                                        `UART_STATUS_ADDR:
                                            begin // STATUS
                                                o_data <= {30'b0, uart_tx_fifo_full, uart_rx_ready};
                                            end
                                        `UART_DATA_ADDR:
                                            begin // DATA
                                                if (uart_rx_ready) begin
													$display("Toggling uart_rx_read...");
                                                    uart_rx_read <= ~uart_rx_read;      // tell the UART we read the byte
                                                    delay <= 1;							// uart needs it's own cycle to respond
                                                end
                                            end
                                        `UART_INT_ADDR:
                                            begin // INT enables
                                                o_data <= {30'b0, int_enables};
                                            end
                                        `UART_INT_PENDING_ADDR:
                                            begin // INT enables
												o_data <= {30'b0, int_pending};
                                            end
                                        default:
                                            begin
                                                error <= 1; // invalid address;
                                                ready <= 1;
                                            end
                                    endcase
                                end
                                state <= RETIRE;
                            end
                        RETIRE:
							begin
								if (delay) begin
									delay <= 0;
								end else begin
									if (wr_en == 0) begin
										case(addr)
											`UART_DATA_ADDR: o_data <= {24'b0, rx_byte};
										endcase
									end
                                    ready <= 1;
                                end
							end
                    endcase
                end else if (!enable) begin // !enable (need at least one cycle of !enable to clear the ready flag
                    ready <= 0;
                    error <= 0; // de-assert error to allow for retries
                    state <= ISSUE;
                end
            end
        end
    end
endmodule
