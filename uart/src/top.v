//`define USE_HEX_LOGGER
module top
(
    input clk,
    input rx_pin,
    output tx_pin,
    output led
);
    wire [15:0] uart_baud_div = 16'd469; // 115,200 baud @ 54MHz with the PLL (I'm using the PLL for no reason other than to use it...)
    wire pll_clk;
    wire rst;
    reg [3:0] rstcnt = 4'b0;
    reg ledstatus;

    assign rst = rstcnt[3];
    assign led = ledstatus;

    Gowin_rPLL pll(.clkout(pll_clk), .clkin(clk));

    always @(posedge pll_clk) begin
        rstcnt = {rstcnt[2:0], 1'b1};
    end

`ifdef USE_HEX_LOGGER
    // --- HEX LOGGER MODE ---
    reg  [15:0] debug_val;
    reg         log_trigger;
    wire        log_busy;
    reg [23:0]  counter;

    uart_hex_logger logger (
        .clk(pll_clk),
        .rst(rst),
        .baud_div(uart_baud_div),
        .trigger(log_trigger),
        .hex_val(debug_val),
        .tx_pin(tx_pin),
        .busy(log_busy)
    );

    always @(posedge pll_clk) begin
        if (!rst) begin
            counter <= 0;
            log_trigger <= 0;
            debug_val <= 0;
        end else begin
            counter <= counter + 1'b1;
            if (counter[23]) begin
                 case(counter[0])
                    1'b0: begin                                 // trigger a log event
                            log_trigger <= 1'b1;
                            debug_val <= debug_val + 1'b1;
                          end
                    1'b1: begin                                 // reset the master counter and deassert trigger
                            counter <= 0;
                            log_trigger <= 1'b0;
                          end
                endcase
            end
        end
    end

`else

    // memory mapped UART demo (echoes what it receives)
    wire [15:0] target_baud = 16'd469; // 115,200 baud @ 54MHz

    reg enable;
    reg wr_en;
    reg [2:0] addr;
    reg [7:0] i_data;
    wire ready;
    wire irq;
    wire [7:0] o_data;
    reg [7:0] o_data_latch;
    reg [7:0] state;
    reg [7:0] tag;
    reg [31:0] counter;

    localparam 
        WAIT             = 8'd0,
        WAIT_DELAY       = 8'd1,
        INIT             = 8'd2,
        WRITE_BAUD_L     = 8'd3,
        WRITE_BAUD_H     = 8'd4,
        WRITE_INT_ENABLE = 8'd5,
        READ_STATUS      = 8'd6,
        COMP_STATUS      = 8'd7,
        START_ECHO       = 8'd8,
        WAIT_BEFORE_ECHO = 8'd9,
        WRITE_ECHO       = 8'd10,
        CLEAR_INT       = 8'd11;

    localparam
        UART_BAUD_L_ADDR      = 3'b000,
        UART_BAUD_H_ADDR      = 3'b001,
        UART_STATUS_ADDR      = 3'b010,
        UART_DATA_ADDR        = 3'b011,
        UART_INT_ADDR         = 3'b100,
        UART_INT_PENDING_ADDR = 3'b101;

    uart_mem uartmem(
        .clk(pll_clk), .rst(rst), .irq(irq),
        .enable(enable), .wr_en(wr_en), .addr(addr), .i_data(i_data), .ready(ready), .o_data(o_data),
        .tx_pin(tx_pin), .rx_pin(rx_pin));

    always @(posedge pll_clk) begin
        if (!rst) begin
            enable <= 0;
            wr_en <= 0;
            addr <= 0;
            i_data <= 0;
            o_data_latch <= 0;
            ledstatus <= 1'b1; // turn LED off 
            counter <= 0;
            state <= INIT;
            tag <= INIT;
        end else begin
            ledstatus <= ~irq; // copy IRQ to LED
            case(state)
                WAIT_DELAY: // simple counter based wait to the next state
                    begin
                        if (!counter) begin
                            state <= tag;
                        end else begin
                            counter <= counter - 1'b1;
                        end
                    end
                WAIT: // generic wait and then jump to tag state
                    begin
                        if (!enable) begin
                            enable <= 1;
                        end else if (ready) begin
                            o_data_latch <= o_data;
                            enable <= 0;        // disable core
                            wr_en <= 0;         // deassert write
                            state <= tag;       // jump to tag state
                        end
                    end
                INIT: // write BAUD_L
                    begin
                        wr_en <= 1;
                        addr <= UART_BAUD_L_ADDR;
                        i_data <= target_baud[7:0];
                        tag <= WRITE_BAUD_H;
                        state <= WAIT;
                    end
                WRITE_BAUD_H: // write BAUD_H
                    begin
                        wr_en <= 1;
                        addr <= UART_BAUD_H_ADDR;
                        i_data <= target_baud[15:8];
                        tag <= WRITE_INT_ENABLE;
                        state <= WAIT;
                    end
                WRITE_INT_ENABLE: // write interrupt enables
                    begin
                        wr_en <= 1;
                        addr <= UART_INT_ADDR;
                        i_data <= 2'b11; // enable both interrupts
                        tag <= READ_STATUS;
                        state <= WAIT;
                    end
                READ_STATUS: // READ STATUS
                    begin
                        wr_en <= 0;
                        addr <= UART_STATUS_ADDR;
                        tag <= COMP_STATUS;
                        state <= WAIT;
                    end
                COMP_STATUS: // compare rx_ready bit..
                    begin
                        if (o_data_latch[0] && !o_data_latch[1]) begin // there's an RX bit and TX fifo is not full
                            counter <= 54_000_000/8; // wait 1/8'th second
                            tag <= START_ECHO;
                            state <= WAIT_DELAY;
                        end else begin
                            state <= READ_STATUS; // re-read STATUS if not
                        end
                    end
                START_ECHO: // read the UART
                    begin
                        wr_en <= 0;
                        addr <= UART_DATA_ADDR;
                        tag <= WAIT_BEFORE_ECHO;
                        state <= WAIT;
                    end
                WAIT_BEFORE_ECHO:
                    begin
                        counter <= 54_000_000/8; // wait 1/8'th second
                        tag = WRITE_ECHO;
                        state <= WAIT_DELAY;
                    end
                WRITE_ECHO: // write it back
                    begin
                        wr_en <= 1;
                        addr <= UART_DATA_ADDR;
                        i_data <= o_data_latch;
                        tag <= CLEAR_INT; // go back to waiting on status
                        state <= WAIT;
                    end
                CLEAR_INT: // write interrupt enables
                    begin
                        wr_en <= 1;
                        addr <= UART_INT_PENDING_ADDR;
                        i_data <= 2'b11; // clear both interrupts
                        tag <= READ_STATUS;
                        state <= WAIT;
                    end
            endcase
        end
    end        
`endif
endmodule