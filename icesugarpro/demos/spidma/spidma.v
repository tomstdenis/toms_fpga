/*

Setup to use the right most PMOD header (J4).

*/

`include "spidma.vh"


module top(input wire clk, inout wire [3:0] sio, output wire cs, output wire sck, input wire uart_rx, output wire uart_tx);

	localparam
        FREQ = `FREQ,
		SRAM_ADDR_WIDTH = `SRAM_ADDR_WIDTH,
        HOST_MEM_ADDR = 11;

    reg [3:0] rstcnt = 4'b0;
    wire rst_n;
    assign rst_n = rstcnt[3];
    wire pll_clk;
	wire pll_locked;

	pll1 pll(.clkin(clk), .clkout0(pll_clk), .locked(pll_locked));

    always @(posedge pll_clk) begin
		if (pll_locked) begin
			rstcnt <= {rstcnt[2:0], 1'b1};
		end
    end

    // *** UART ***
	wire [15:0] uart_bauddiv = (FREQ * 1_000_000) / 115_200;
    reg uart_tx_start;
    reg [7:0] uart_tx_data_in;
    wire uart_tx_fifo_full;
    wire uart_tx_fifo_empty;
    reg uart_rx_read;
    wire uart_rx_ready;
    wire [7:0] uart_rx_byte;

    uart #(.FIFO_DEPTH(2), .RX_ENABLE(1), .TX_ENABLE(1)) mrtalky(
        .clk(pll_clk), .rst_n(rst_n), .baud_div(uart_bauddiv),
        .uart_tx_start(uart_tx_start), .uart_tx_pin(uart_tx),
        .uart_tx_data_in(uart_tx_data_in), .uart_tx_fifo_empty(uart_tx_fifo_empty),
        .uart_tx_fifo_full(uart_tx_fifo_full),
        .uart_rx_pin(uart_rx), .uart_rx_read(uart_rx_read), .uart_rx_ready(uart_rx_ready),
        .uart_rx_byte(uart_rx_byte));

    // *** Host Memory ***
    reg host_mem_wr_en;
    reg [HOST_MEM_ADDR-1:0] host_mem_addr;
    reg [7:0] host_mem_data_in;
    wire [7:0] host_mem_data_out;

    wire spi_mem_wr_en;
    wire [HOST_MEM_ADDR-1:0] spi_mem_addr;
    wire [7:0] spi_mem_data_in;
    wire [7:0] spi_mem_data_out;

	bram_dp_2048x8 #(.REGMODE_A("OUTREG"), .REGMODE_B("OUTREG")) mem(
		.clk_a(pll_clk), .clk_en_a(1'b1), .rst_a(~rst_n),
		.addr_a(host_mem_addr), .din_a(host_mem_data_in),
		.we_a(host_mem_wr_en), .dout_a(host_mem_data_out),
		
		.clk_b(pll_clk), .clk_en_b(1'b1), .rst_b(~rst_n),
		.addr_b(spi_mem_addr), .din_b(spi_mem_data_in),
		.we_b(spi_mem_wr_en), .dout_b(spi_mem_data_out));

    // *** SPI DMA ***
    wire spidma_ready;
    reg [3:0] spidma_cmd_value;
    reg spidma_cmd_valid;
    reg [SRAM_ADDR_WIDTH-1:0] spidma_cmd_spi_address;
    reg [10:0] spidma_cmd_host_address;
    reg [7:0] spidma_cmd_burst_len;

    // wiring to our pins from the SPI block
    wire [3:0] sio_din;
    wire [3:0] sio_dout;
    wire sram_sck;
    wire sram_cs;
    wire [3:0] sio_en;
    
    // either output to sio or set to high impedence state
    assign sio[0] = sio_en[0] ? sio_dout[0] : 1'bz;
    assign sio[1] = sio_en[1] ? sio_dout[1] : 1'bz;
    assign sio[2] = sio_en[2] ? sio_dout[2] : 1'bz;
    assign sio[3] = sio_en[3] ? sio_dout[3] : 1'bz;
    // sio input is always just the sio pins
    assign sio_din = sio;
    assign sck = sram_sck;
    assign cs = sram_cs;

    spidma 
        #(
            // PSRAM configuration (Some chips allow 1 Tclk between CS low but ESP-PSRAM requires 50ns)
            .CLK_FREQ_MHZ(FREQ),
            .SRAM_ADDR_WIDTH(SRAM_ADDR_WIDTH), .HOST_MEM_ADDR(HOST_MEM_ADDR),
            .DUMMY_CYCLES(6), 
            
            .CMD_READ(8'hEB), .CMD_WRITE(8'h38), .CMD_EQIO(8'h35), .CMD_QMEX(8'hF5),
            .CMD_RESETEN(8'h66), .CMD_RESET(8'h99),

            .MIN_CPH_NS(50), .SPI_TIMER_BITS(3), .QPI_TIMER_BITS(0), .MIN_WAKEUP_NS(150_000)
        ) sdma(
            .clk(pll_clk), .rst_n(rst_n),
            .ready(spidma_ready),
            .host_mem_addr(spi_mem_addr), .host_mem_wr_en(spi_mem_wr_en),
            .host_mem_data_in(spi_mem_data_in), .host_mem_data_out(spi_mem_data_out),
            .cmd_value(spidma_cmd_value), .cmd_valid(spidma_cmd_valid),
            .cmd_spi_address(spidma_cmd_spi_address), .cmd_host_address(spidma_cmd_host_address),
            .cmd_burst_len(spidma_cmd_burst_len),
            .sio_din(sio_din), .sio_dout(sio_dout), .sio_en(sio_en),
            .cs_pin(sram_cs), .sck_pin(sram_sck)
        );

    // *** Test Regs ***
    reg [HOST_MEM_ADDR-1:0] test_host_mem_src;
    reg [HOST_MEM_ADDR-1:0] test_spi_mem_target;
    reg [HOST_MEM_ADDR-1:0] test_host_mem_target;
    reg [7:0] test_burst_len;
    reg [HOST_MEM_ADDR:0] test_X;
    reg [7:0] test_Y;
    reg [31:0] test_LFSR;

/* Test plan:

    - we have a 2KB memory but because I'm lazy we're going split it in half
      so it's really a 1KB memory where the top 1KB is a manually mirrored copy

    - the gist of the test is to fill 1K with random data
    - then repeatedly copy a part of the lower 1K to somewhere in SPI memory
    - then copy that back out randomly to somewhere in the top 1K
    - then read back the written to 1K part against the source in the bottom 1K

    1. Using a 32-bit LFSR clocked each cycle
    2. For x = 0 to 1023 do
       2.1 host_mem[x] = lfsr[7:0]
    3. Wait for UART char 'G'
    4. Forever
       4.1 host_mem_src    = lfsr[9:0]
       4.2 spi_mem_target  = lfsr[19:10]
       4.3 burst_len       = lfsr[24:20]
       4.4 host_mem_target = host_mem_src ^ spi_mem_target
       4.6 Issue spi_write (copy from host to spi)
       4.7 issue spi_read (copy from spi to host)
       4.8 Compare, for X = 0 to burst_len
          4.8.1 Y = host_mem[host_mem_src + X]                   <--- maybe have a FSM state dedicate to the dummy cycle
          4.8.2 Z = host_mem[host_mem_target + X + 1024]
          4.8.3 if Y != Z output '2' and stop in a failed state
       4.9 uart out '1' and goto 4
*/

    reg [4:0] fsm_state;
    reg [4:0] fsm_tag;

    localparam
        FSM_INIT        = 0,
        FSM_ISSUE_RESET = 1,
        FSM_ISSUE_EQIO  = 3,
        FSM_START_TEST  = 4,
        FSM_ISSUE_WRITE = 5,
        FSM_ISSUE_READ  = 6,
        FSM_COMPARE_TOP = 7,
        FSM_READ_TGT    = 8,
        FSM_COMPARE     = 9,
        FSM_GOOD        = 10,
        FSM_BAD         = 11,
        FSM_STOP        = 12,
        FSM_DELAY_1C    = 13,
        FSM_DELAY_0C    = 14,
        FSM_DELAY_READY = 15;
    
    wire lfsr_tap = ~(test_LFSR[31] ^ test_LFSR[21] ^ test_LFSR[1] ^ test_LFSR[0]);
    always @(posedge pll_clk) begin
        if (!rst_n) begin
            uart_tx_start           <= 0;
            uart_tx_data_in         <= 0;
            uart_rx_read            <= 0;
            host_mem_wr_en          <= 0;
            host_mem_addr           <= 0;
            host_mem_data_in        <= 0;
            spidma_cmd_value        <= 0;
            spidma_cmd_valid        <= 0;
            spidma_cmd_spi_address  <= 0;
            spidma_cmd_host_address <= 0;
            spidma_cmd_burst_len    <= 0;
            test_host_mem_src       <= 0;
            test_spi_mem_target     <= 0;
            test_host_mem_target    <= 0;
            test_burst_len          <= 0;
            test_X                  <= 0;
            test_Y                  <= 0;
            test_LFSR               <= 32'hDEADF001; 
            fsm_state               <= FSM_INIT;
            fsm_tag                 <= 0;
        end else begin
            // step LFSR
            test_LFSR <= {test_LFSR[30:0], lfsr_tap};

            // fsm
            case(fsm_state)
                FSM_DELAY_1C:                                   // delay for 1 cycle for host mem reads
                    begin
                        uart_tx_start <= 0;
                        fsm_state     <= FSM_DELAY_0C;
                    end
                FSM_DELAY_0C:
                    begin
                        fsm_state     <= fsm_tag;
                    end

                FSM_DELAY_READY:                                // wait for spidma_ready and jump to tag
                    begin
                        if (spidma_ready) begin
                            spidma_cmd_valid <= 1'b0;
                            fsm_state        <= fsm_tag;
                        end
                    end

                FSM_INIT:                                       // fill first 1K
                    begin
                        host_mem_data_in   <= test_LFSR[7:0];
                        host_mem_addr[9:0] <= test_X[9:0];
                        host_mem_wr_en     <= 1'b1;
                        if (test_X == 1024) begin
                            host_mem_wr_en <= 1'b0;
                            test_X         <= 0;
                            fsm_state      <= FSM_ISSUE_RESET;
                        end else begin
                            test_X         <= test_X + 1'b1;
                        end
                    end

                FSM_ISSUE_RESET:                                // issue reset command
                    begin
                        spidma_cmd_value <= `spidma_reset;
                        spidma_cmd_valid <= 1'b1;
                        fsm_tag          <= FSM_ISSUE_EQIO;
                        fsm_state        <= FSM_DELAY_READY;
                    end

                FSM_ISSUE_EQIO:                                 // issue EQIO (enter quad io) command
                    begin
                        spidma_cmd_value <= `spidma_eqio;
                        spidma_cmd_valid <= 1'b1;
                        fsm_tag          <= FSM_START_TEST;
                        fsm_state        <= FSM_DELAY_READY;
                    end

                FSM_START_TEST:                                 // we choose our test parameters here
                    begin
						if (uart_rx_ready) begin
							uart_rx_read <= 1;
							test_host_mem_src    <= test_LFSR[8:0];
							test_spi_mem_target  <= test_LFSR[18:10];
							test_burst_len       <= test_LFSR[24:20];
							test_host_mem_target <= 1024 + (test_LFSR[8:0] ^ test_LFSR[18:10]); // host_mem_src ^ spi_mem_target
							test_X               <= 0;
							test_Y               <= 0;
							fsm_state            <= FSM_ISSUE_WRITE;
						end
                    end

                FSM_ISSUE_WRITE:                                // issue write to spi command
                    begin
						uart_rx_read			<= 0;
                        spidma_cmd_burst_len    <= test_burst_len;
                        spidma_cmd_value        <= `spidma_cmd_write;
                        spidma_cmd_host_address <= test_host_mem_src;
                        spidma_cmd_spi_address  <= test_spi_mem_target;
                        spidma_cmd_valid        <= 1'b1;
                        fsm_tag                 <= FSM_ISSUE_READ;
                        fsm_state               <= FSM_DELAY_READY;
                    end

                FSM_ISSUE_READ:                                 // issue read from spi
                    begin
                        spidma_cmd_burst_len    <= test_burst_len;
                        spidma_cmd_value        <= `spidma_cmd_read;
                        spidma_cmd_host_address <= test_host_mem_target;
                        spidma_cmd_spi_address  <= test_spi_mem_target;
                        spidma_cmd_valid        <= 1'b1;
                        fsm_tag                 <= FSM_COMPARE_TOP;
                        fsm_state               <= FSM_DELAY_READY;
                    end

                FSM_COMPARE_TOP:                                // issue read from bottom 1K
                    begin
                        host_mem_addr           <= test_host_mem_src + test_X;
                        fsm_tag                 <= FSM_READ_TGT;
                        fsm_state               <= FSM_DELAY_1C;
                    end

                FSM_READ_TGT:                                   // issue read from top 1K
                    begin
                        test_Y                  <= host_mem_data_out;                   // save first read
                        host_mem_addr           <= test_host_mem_target + test_X;       // read from top 1K
//                        host_mem_addr           <= test_host_mem_src + test_X;        // <<< JUST TESTING THE FSM!!!
                        fsm_tag                 <= FSM_COMPARE;
                        fsm_state               <= FSM_DELAY_1C;
                    end

                FSM_COMPARE:                                    // 
                    begin
                        if (test_Y != host_mem_data_out) begin
                            fsm_state <= FSM_BAD;
                        end else begin
                            fsm_state <= FSM_GOOD;
                        end
                    end

                FSM_GOOD:                                       // echo 1 and go back to TOP or START_TEST
                    begin
                        if (test_X >= test_burst_len) begin
                            if (!uart_tx_fifo_full) begin
                                uart_tx_data_in <= 8'h31;               // '1'
                                uart_tx_start   <= 1;
                                fsm_tag         <= FSM_START_TEST;
                                fsm_state       <= FSM_DELAY_1C;
                            end
                        end else begin
                            test_X              <= test_X + 1;
                            fsm_state           <= FSM_COMPARE_TOP;
                        end
                    end

                FSM_BAD:                                        // echo 2 and then stop
                    begin
                        if (!uart_tx_fifo_full) begin
                            uart_tx_data_in <= 8'h32;               // '2'
                            uart_tx_start   <= 1;
                            fsm_tag         <= FSM_START_TEST;
                            fsm_state       <= FSM_DELAY_1C;
                        end
                    end

                default: begin fsm_state <= FSM_INIT; end
            endcase
        end
    end
endmodule
