`default_nettype none
module top(
    input wire clk,
    input wire uart_rx,
    output wire uart_tx
);

    reg rst_n = 1'b0;

    localparam
        FREQ = 27_000_000,
        BAUD = 230_400,
        BRAM_WIDTH = 13;            // 8Kbyte

    // uart driven by uart_tx/uart_rx pins
    reg uart_tx_start;
    reg [7:0] uart_tx_data_in;
    wire uart_tx_fifo_empty;
    wire uart_tx_fifo_full;
    reg uart_rx_read;
    wire uart_rx_ready;
    wire [7:0] uart_rx_byte;

    localparam 
        bauddiv = FREQ / BAUD,
        baudwidth = $clog2(bauddiv);
    wire [baudwidth-1:0] baud_div = bauddiv;

    uart #(.FIFO_DEPTH(16), .RX_ENABLE(1), .TX_ENABLE(1), .BAUD_WIDTH(baudwidth)) mrtalky (
        .clk(clk), .rst_n(rst_n), .baud_div(baud_div),
        .uart_tx_start(uart_tx_start), .uart_tx_data_in(uart_tx_data_in),
        .uart_tx_pin(uart_tx), .uart_tx_fifo_empty(uart_tx_fifo_empty), .uart_tx_fifo_full(uart_tx_fifo_full),
        .uart_rx_pin(uart_rx), .uart_rx_read(uart_rx_read), .uart_rx_ready(uart_rx_ready), .uart_rx_byte(uart_rx_byte));

    // the memory to test
    wire [7:0] mem_dout;
    reg mem_wr_en;
    reg [7:0] mem_din;
    reg [BRAM_WIDTH-1:0] mem_addr;

    Gowin_SP mem(
        .dout(mem_dout), //output [7:0] dout
        .clk(clk), //input clk
        .oce(1'b1), //input oce
        .ce(1'b1), //input ce
        .reset(~rst_n), //input reset
        .wre(mem_wr_en), //input wre
        .ad(mem_addr), //input [12:0] ad
        .din(mem_din) //input [7:0] din
    );

    // test fsm stuff
    reg [3:0] fsm_state;
    reg [3:0] fsm_tag;
    reg [3:0] fsm_send_tag;
    reg [31:0] counter;
    reg [BRAM_WIDTH:0] test_addr;
    reg [7:0]          test_byte;
    reg [31:0] uart_msg;
    reg [1:0] uart_cnt;

    localparam
        FSM_START_LOOP = 0,
        FSM_TEST_1     = 1,
        FSM_TEST_2     = 2,
        FSM_TEST_3     = 3,
        FSM_SEND_MSG   = 4,
        FSM_DELAY      = 5;

    always @(posedge clk) begin
        if (!rst_n) begin
            rst_n         <= 1'b1;
            mem_wr_en     <= 1'b0;
            uart_tx_start <= 1'b0;
            uart_rx_read  <= 1'b0;
            fsm_state     <= FSM_START_LOOP;
            test_byte     <= 0;
        end else begin
            case (fsm_state)
                FSM_START_LOOP:
                    begin
                        test_addr <= 0;
                        test_byte <= test_byte + 1;
                        uart_msg  <= {test_byte, 24'hFFFFFF};
                        uart_cnt  <= 2'b11;
                        fsm_state <= FSM_SEND_MSG;
                        fsm_send_tag <= FSM_TEST_1;
                    end
                FSM_TEST_1: // start write, loop enough times
                    begin
                        if (test_addr < (1 << BRAM_WIDTH)) begin
                            mem_addr <= test_addr;
                            mem_wr_en <= 1;
                            mem_din <= test_byte;
                            fsm_state <= FSM_DELAY;
                            fsm_tag   <= fsm_state;
                            test_addr <= test_addr + 1'b1;
                        end else begin
                            // shift to reads
                            fsm_state   <= FSM_TEST_2;
                        end
                    end
                FSM_TEST_2: // start reads
                    begin
                        if (test_addr < (1 << BRAM_WIDTH)) begin
                            mem_addr <= test_addr;
                            fsm_state <= FSM_DELAY;
                            fsm_tag   <= FSM_TEST_3;
                            test_addr <= test_addr + 1'b1;
                        end else begin
                            // start loop over
                            fsm_state   <= FSM_START_LOOP;
                        end
                    end
                FSM_TEST_3: // compare
                    begin
                        if (mem_dout == test_byte) begin
                            // compares ok
                            fsm_state    <= FSM_TEST_2;
                        end else begin
                            // fails so send that out
                            uart_msg     <= {test_byte, 24'h0} | test_addr;
                            uart_cnt     <= 2'b11;
                            fsm_state    <= FSM_SEND_MSG;
                            fsm_send_tag <= FSM_TEST_2;
                        end
                    end
                FSM_SEND_MSG:
                    begin
                        if (!uart_tx_fifo_full) begin
                            // send the upper 8 bits
                            uart_tx_data_in <= uart_msg[31:24];
                            uart_msg        <= {uart_msg[23:0], 8'b0};
                            uart_tx_start   <= 1;
                            fsm_state       <= FSM_DELAY;
                            fsm_tag         <= fsm_state;
                            if (uart_cnt) begin
                                uart_cnt    <= uart_cnt - 1'b1;
                            end else begin
                                fsm_tag     <= fsm_send_tag;
                            end
                        end
                    end
                FSM_DELAY:
                    begin
                        mem_wr_en     <= 1'b0;
                        uart_tx_start <= 1'b0;
                        fsm_state     <= fsm_tag;
                    end
            endcase
        end
    end
endmodule