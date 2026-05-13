module top
(
    input clk,
    input rx_pin,
    output tx_pin
);
    wire [15:0] uart_baud_div = 50_000_000 / 115_200; // 115,200 baud @ 50MHz
    wire rst_n;
    reg [3:0] rstcnt = 4'b0;

    assign rst_n = rstcnt[3];

    always @(posedge clk) begin
        rstcnt <= {rstcnt[2:0], 1'b1};
    end

    `include "uart_mem.vh"

    // memory mapped UART demo (echoes what it receives)
    reg enable;
    reg wr_en;
    reg [31:0] addr;
    reg [31:0] i_data;
    wire ready;
    wire irq;
    wire [31:0] o_data;
    reg [7:0] o_data_latch;
    reg [7:0] state;
    reg [7:0] tag;
    reg [31:0] counter;
    wire bus_err;

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
        CLEAR_INT        = 8'd11;

    uart_mem uartmem(
        .clk(clk), .rst_n(rst_n), .irq(irq), .bus_err(bus_err), .be(4'b0001),
        .enable(enable), .wr_en(wr_en), .addr(addr), .i_data(i_data), .ready(ready), .o_data(o_data),
        .tx_pin(tx_pin), .rx_pin(rx_pin));

    always @(posedge clk) begin
        if (!rst_n) begin
            enable          <= 0;
            wr_en           <= 0;
            addr            <= 0;
            i_data          <= 0;
            o_data_latch    <= 0;
            counter         <= 0;
            state           <= INIT;
            tag             <= INIT;
        end else begin
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
                        if (ready) begin
                            o_data_latch <= o_data[7:0];
                            enable       <= 0;          // disable core
                            wr_en        <= 0;          // deassert write
                            state        <= tag;        // jump to tag state
                        end
                    end
                INIT: // write BAUD_L
                    begin
                        wr_en  <= 1;                    // write
                        addr   <= `UART_BAUD_L_ADDR;    // to BAUD_L
                        i_data <= uart_baud_div[7:0];     // the lower 8 bits
                        enable <= 1;                    // enable peripheral bus

                        tag    <= WRITE_BAUD_H;         // next state is writing BAUD_H
                        state  <= WAIT;                 // wait for block to acknowledge
                    end
                WRITE_BAUD_H: // write BAUD_H
                    begin
                        wr_en  <= 1;                    // write
                        addr   <= `UART_BAUD_H_ADDR;    // to BAUD_H
                        i_data <= uart_baud_div[15:8];    // upper 8 bits
                        enable <= 1;                    // enable peripheral bus

                        tag    <= WRITE_INT_ENABLE;     // next state is writing the Interrupt Enables
                        state  <= WAIT;                 // wait for block to acknowledge
                    end
                WRITE_INT_ENABLE: // write interrupt enables
                    begin
                        wr_en  <= 1;                    // write
                        addr   <= `UART_INT_ADDR;       // to interrupt enable
                        i_data <= 2'b11;                // enable both interrupts
                        enable <= 1;                    // enable peripheral bus

                        tag    <= READ_STATUS;          // next state is reading the status register
                        state  <= WAIT;                 // wait for block to acknowledge
                    end
                READ_STATUS: // READ STATUS
                    begin
                        wr_en  <= 0;                    // read
                        addr   <= `UART_STATUS_ADDR;    // from status register
                        enable <= 1;                    // enable peripheral bus

                        tag    <= COMP_STATUS;          // next state is compare status
                        state  <= WAIT;                 // wait for block to acknowledge
                    end
                COMP_STATUS: // compare rx_ready bit..
                    begin
                        if (o_data_latch[0] && !o_data_latch[1]) begin // there's an RX bit and TX fifo is not full
                            counter <= 50_000_000/64;   // wait a bit
                            tag     <= START_ECHO;
                            state   <= WAIT_DELAY;
                        end else begin
                            state <= READ_STATUS;       // re-read STATUS since conditions aren't met for echoing
                        end
                    end
                START_ECHO: // read the UART
                    begin
                        wr_en  <= 0;                    // read
                        addr   <= `UART_DATA_ADDR;      // from the data register
                        enable <= 1;                    // enable peripheral bus

                        tag    <= WAIT_BEFORE_ECHO;     // next state is a brief pause before writing
                        state  <= WAIT;                 // wait for block to acknowledge
                    end
                WAIT_BEFORE_ECHO:                       // we want the LED to stay on for a bit before writing back
                    begin
                        counter <= 50_000_000/64;       // wait a bit
                        tag     <= WRITE_ECHO;
                        state   <= WAIT_DELAY;
                    end
                WRITE_ECHO: // write it back
                    begin
                        wr_en  <= 1;                    // write
                        addr   <= `UART_DATA_ADDR;      // to data register
                        i_data <= o_data_latch;         // the previously latched output from the read of the data register
                        enable <= 1;                    // enable peripheral bus

                        tag    <= CLEAR_INT;            // next state is clearing the interrupt flags
                        state  <= WAIT;                 // wait for block to acknowledge
                    end
                CLEAR_INT: // write interrupt enables
                    begin
                        wr_en  <= 1;                       // write
                        addr   <= `UART_INT_PENDING_ADDR;  // to interrupt pending register
                        i_data <= 2'b11;                   // clear both interrupts (write 1 to clear, there are 2 flags)
                        enable <= 1;                       // enable peripheral bus

                        tag    <= READ_STATUS;             // next state is back to reading the status register
                        state  <= WAIT;                    // wait for block to acknowledge
                    end
            endcase
        end
    end        
endmodule