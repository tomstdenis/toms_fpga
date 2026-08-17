module top(
    input wire clk,

    output wire uart_tx,
    input wire uart_rx,

    output wire sck_pin,
	output wire sck8_pin,
    output wire cs_pin,
    inout wire [3:0] sio
);

    localparam
        PSRAM      = 1,   // 1 == use PSRAM, 0 == SRAM
        FREQ       = `FREQ * 1000,  // clock rate in LHz
        RUNLEN     = 32;   // how many bytes to transfer (7 so the addresses come out of alignment)

    wire pllclk;
	wire pll_locked;

	pll1 pll(.clkin(clk), .clkout0(pllclk), .locked(pll_locked));

    reg rst_n = 1'b0;

    localparam
        baud     = 230_400,
        baud_div = (FREQ * 1_000) / baud,
        baud_width = $clog2(baud_div);

    wire [baud_width-1:0] bauddiv = baud_div;

    reg uart_tx_start;
    reg [7:0] uart_tx_data_in;
    wire uart_tx_fifo_full;
    wire uart_tx_fifo_empty;

    uart #(.FIFO_DEPTH(8), .RX_ENABLE(0), .TX_ENABLE(1), .BAUD_WIDTH(baud_width)) MrTalky(
        .clk(pllclk), .rst_n(rst_n),
        .baud_div(bauddiv), .uart_tx_start(uart_tx_start), .uart_tx_data_in(uart_tx_data_in),
        .uart_tx_pin(uart_tx), .uart_tx_fifo_empty(uart_tx_fifo_empty), .uart_tx_fifo_full(uart_tx_fifo_full));

    reg [23:0] sram_addr;
    reg [7:0]  sram_din;
    wire [7:0] sram_dout;
    reg        sram_wr_en;
    reg        sram_start_trans;
    wire       sram_ready;
    wire       sram_busy;
    wire       sram_idle;
    wire       sram_read_strobe;
    wire       sram_write_strobe;

    wire [3:0] sio_din;
    wire [3:0] sio_dout;
    wire       sio_en;

    assign sio     = sio_en ? sio_dout : 4'bzzzz;
    assign sio_din = sio;

    nanosram #(.PSRAM(PSRAM), .FREQ(FREQ/1000)) emm386 (
        .clk(pllclk), .rst_n(rst_n),
        .addr(sram_addr), .data_in(sram_din), .data_out(sram_dout), .wr_en(sram_wr_en),
        .start_trans(sram_start_trans), .ready(sram_ready), .busy(sram_busy), .idle(sram_idle),
        .read_strobe(sram_read_strobe), .write_strobe(sram_write_strobe),
        .sio_din(sio_din), .sio_dout(sio_dout), .sio_en(sio_en), .cs_pin(cs_pin), .sck_pin(sck_pin));

    // simple test go to address 16'h1234 and write 16 bytes starting at value 8'h55 increasing by 1 per bytes
    reg [2:0] test_state;
    reg [2:0] test_tag;
    reg [4:0] test_cycle;
    reg [7:0] test_byte;
    
    localparam
        STATE_START_WRITE = 0,
        STATE_LOOP_WRITE  = 1,
        STATE_START_READ  = 2,
        STATE_LOOP_READ   = 3,
        STATE_DONE        = 4;

    always @(posedge pllclk) begin
        if (!rst_n) begin
            rst_n            <= pll_locked;
            sram_start_trans <= 1'b0;
            sram_wr_en       <= 1'b0;
            test_state       <= STATE_START_WRITE;
            uart_tx_start    <= 1'b0;
            sram_addr        <= 0;
            test_byte        <= 0;
        end else begin
            case (test_state)
                STATE_START_WRITE:
                    begin
                        uart_tx_start <= 1'b0;
                        if (sram_idle) begin
                            sram_din              <= test_byte;
                            sram_start_trans      <= 1'b1;
                            sram_wr_en            <= 1'b1;
                            test_state            <= STATE_LOOP_WRITE;
                            test_cycle            <= RUNLEN-1;
                        end
                    end
                STATE_LOOP_WRITE:                                               // by this point we're in SHIFT_QUAD
                    begin
                        if (sram_ready & sram_write_strobe) begin
                            test_cycle <= test_cycle - 1'b1;
                            sram_din   <= sram_din + 1'b1;
                            // the write strobe occurs BEFORE the current byte is finished so if we lower
                            // start_trans the FSM will stop writing with the current byte being shifted out
                            if (test_cycle == 0) begin
                                sram_start_trans <= 0;
                                test_state       <= STATE_START_READ;
                            end
                        end
                    end
                STATE_START_READ:
                    begin
                        if (sram_idle) begin
                            test_byte             <= test_byte + 1'b1;
                            sram_din              <= test_byte;
                            sram_wr_en            <= 1'b0;
                            sram_start_trans      <= 1'b1;
                            test_state            <= STATE_LOOP_READ;
                            test_cycle            <= RUNLEN-1;
                        end
                    end
                STATE_LOOP_READ:                                               // by this point we're in SHIFT_QUAD
                    begin
                        if (sram_ready & sram_read_strobe) begin
                            test_cycle <= test_cycle - 1'b1;
                            if (test_cycle == 0) begin
                                uart_tx_data_in       <= 8'h55;
                                test_state            <= STATE_DONE;
                                sram_addr             <= sram_addr + RUNLEN;
                            end else begin
                                sram_din <= sram_din + 1'b1;
								// we're at the 2nd last byte turn off the transaction so it stops reading once it reads
								// byte 1024.  Unlike write_strobe the read_strobe occurs on the cycle the latest byte is
                                // valid so we need to lower the start_trans reg on the count-1 byte.
                                if (test_cycle == 1) begin
                                    sram_start_trans      <= 1'b0;
                                end
                                if (sram_dout != sram_din) begin
                                    sram_start_trans      <= 1'b0;
                                    uart_tx_data_in       <= 8'hAA;
                                    test_state            <= STATE_DONE;
                                end
                            end
                        end
                    end
                STATE_DONE:
                    begin
                        if (!uart_tx_fifo_full) begin
                            uart_tx_start <= 1'b1;
                            test_state    <= STATE_START_WRITE;
                        end
                    end
            endcase
        end
    end
endmodule
