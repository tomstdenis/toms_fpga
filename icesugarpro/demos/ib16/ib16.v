// enable IRQs for UART supporting [0] = RX ready, [1] TX empty
//`define USE_UARTIRQ

// Simple IRQ, raises bus_irq if RX ready
`define USE_SIMPLE_UART_IRQ

`define STACK_ADDRESS (16'h0800 * `BLOCKS - 16'h0100)
`define IRQ_VECTOR    16'h1E00
`define BOOT_ROM_ADDR 16'hF000

module top(input clk, input uart_rx, output uart_tx, inout [15:0] gpio);
    localparam
        TIMER_ADDR       = 16'hFFF9,
        GPIO1_DATA_ADDR  = 16'hFFFA,
        GPIO0_DATA_ADDR  = 16'hFFFB,
        UART_INT_ADDR    = 16'hFFFC,
        UART_INTEN_ADDR  = 16'hFFFD,
        UART_STS_ADDR    = 16'hFFFE,
        UART_DATA_ADDR   = 16'hFFFF;

    wire pllclk;
	wire plllock;
	
	pll mypll(.clkin(clk), .clkout0(pllclk), .locked(plllock));

	reg [3:0] rst = 0;
	wire rst_n = rst[3];
	
	always @(posedge pllclk) begin
		if (plllock) begin
			rst <= {rst[2:0], 1'b1};
		end
	end

// TODO use primitive for this ...
    // GPIO
    reg [15:0] gpio_out;
    wire [15:0] gpio_in;

    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : gpio_en
            assign gpio[i] = gpio_out[i] ? 1'bz : 1'b0;         // requires PULL up 
        end
    endgenerate
    assign gpio_in = gpio;

    wire [15:0] baud_div = (`FREQ * 1_000_000) / 230_400;
    reg uart_tx_start;
    reg [7:0] uart_tx_data_in;
    wire uart_tx_fifo_full;
    wire uart_tx_fifo_empty;
    reg uart_rx_read;
    wire uart_rx_ready;
    wire [7:0] uart_rx_byte;
`ifdef USE_UARTIRQ
    reg uart_prev_tx_fifo_empty;
    reg uart_prev_rx_ready;
    reg [1:0] uart_int_enable;
    reg [1:0] uart_int_pending;
`endif

    uart #(.FIFO_DEPTH(4), .RX_ENABLE(1), .TX_ENABLE(1)) mrtalky (
        .clk(pllclk), .rst_n(rst_n),
        .baud_div(baud_div),
        .uart_tx_start(uart_tx_start),
        .uart_tx_data_in(uart_tx_data_in),
        .uart_tx_pin(uart_tx),
        .uart_tx_fifo_empty(uart_tx_fifo_empty),
        .uart_tx_fifo_full(uart_tx_fifo_full),
        .uart_rx_pin(uart_rx),
        .uart_rx_read(uart_rx_read),
        .uart_rx_ready(uart_rx_ready),
        .uart_rx_byte(uart_rx_byte));

    wire [7:0] bram_dout;
    reg bram_ce;
    reg bram_wre;
    reg [10+$clog2(`BLOCKS):0] bram_addr;
    reg [7:0] bram_din;

	// N*2048x8 memory
	bram_sp_nx2048x8 #(.N(`BLOCKS)) memory(
		.w_clk(pllclk),
		.w_clk_en(1'b1),
		.w_rst(~rst_n),
		.w_addr(bram_addr),
		.w_data(bram_din),
		.w_en(bram_wre),
		.r_clk(pllclk),
		.r_clk_en(1'b1),
		.r_rst(~rst_n),
		.r_addr(bram_addr),
		.r_data(bram_dout));

    wire ib16_bus_enable;
    wire ib16_bus_wr_en;
    wire [15:0] ib16_bus_address;
    wire [15:0] ib16_bus_data_in;
    reg ib16_bus_ready;
    reg [15:0] ib16_bus_data_out;
    reg ib16_bus_irq;
    wire ib16_bus_burst;
    reg [23:0] cycle_counter;

    reg [3:0] bus_cycle;
    ib16 #(
        .STACK_ADDRESS(`STACK_ADDRESS),
        .IRQ_VECTOR(`IRQ_VECTOR),
        .BOOT_ROM_ADDR(`BOOT_ROM_ADDR),
        .TWO_CYCLE(0)) ittybitty(
        .clk(pllclk), .rst_n(rst_n),
        .bus_enable(ib16_bus_enable),
        .bus_wr_en(ib16_bus_wr_en),
        .bus_address(ib16_bus_address),
        .bus_data_in(ib16_bus_data_in),
        .bus_ready(ib16_bus_ready),
        .bus_data_out(ib16_bus_data_out),
        .bus_burst(ib16_bus_burst),
        .bus_irq(ib16_bus_irq));

    // bus controller
    always @(posedge pllclk) begin
        if (!rst_n) begin
            uart_tx_start       <= 0;
            uart_tx_data_in     <= 0;
            uart_rx_read        <= 0;
            bram_ce             <= 0;
            bram_wre            <= 0;
            bram_addr           <= 0;
            bram_din            <= 0;
            ib16_bus_ready      <= 0;
            ib16_bus_data_out   <= 0;
            ib16_bus_irq        <= 0;
            bus_cycle           <= 0;
            gpio_out            <= 8'hFF;
            cycle_counter       <= 0;
`ifdef USE_UARTIRQ
            uart_prev_rx_ready  <= 0;
            uart_prev_tx_fifo_empty <= 0;
            uart_int_enable     <= 0;
            uart_int_pending    <= 0;
`endif
        end else begin
            cycle_counter <= cycle_counter + 1'b1;
`ifdef USE_UARTIRQ
            // trap uart IRQ
            uart_int_pending[0] <= (uart_prev_rx_ready != uart_rx_ready && uart_rx_ready) ? 1'b1 : 1'b0;
            uart_int_pending[1] <= (uart_prev_tx_fifo_empty != uart_tx_fifo_empty && uart_tx_fifo_empty) ? 1'b1 : 1'b0;
            uart_prev_rx_ready <= uart_rx_ready;
            uart_prev_tx_fifo_empty <= uart_tx_fifo_empty;
            ib16_bus_irq <= |(uart_int_pending & uart_int_enable);
`endif
`ifdef USE_SIMPLE_UART_IRQ
            ib16_bus_irq <= uart_rx_ready;
`endif
            // normal mode
            if (ib16_bus_enable && !ib16_bus_ready) begin
                // handle new command
                // GPIO port
                if (ib16_bus_address == GPIO0_DATA_ADDR) begin
                    if (ib16_bus_wr_en) begin
                        gpio_out[7:0] <= ib16_bus_data_in[7:0];
                    end else begin
                        ib16_bus_data_out <= gpio_in[7:0];
                    end
                    ib16_bus_ready <= 1;
                end
                // GPIO port
                if (ib16_bus_address == GPIO1_DATA_ADDR) begin
                    if (ib16_bus_wr_en) begin
                        gpio_out[15:8] <= ib16_bus_data_in[7:0];
                    end else begin
                        ib16_bus_data_out <= gpio_in[15:8];
                    end
                    ib16_bus_ready <= 1;
                end
`ifdef USE_UARTIRQ
                // UART Interrupt enable
                if (ib16_bus_address == UART_INT_ADDR) begin
                    if (ib16_bus_wr_en) begin
                        uart_int_pending <= uart_int_pending[1:0] & ~ib16_bus_data_in[1:0];
                    end else begin
                        ib16_bus_data_out <= {6'b0, uart_int_pending};
                    end
                    ib16_bus_ready <= 1;
                end
                // UART Interrupt enable
                if (ib16_bus_address == UART_INTEN_ADDR) begin
                    if (ib16_bus_wr_en) begin
                        uart_int_enable <= ib16_bus_data_in[1:0];
                    end else begin
                        ib16_bus_data_out <= {6'b0, uart_int_enable};
                    end
                    ib16_bus_ready <= 1;
                end
`endif
                // Timer
                if (ib16_bus_address == TIMER_ADDR) begin
                    ib16_bus_data_out <= cycle_counter[23:16];
                    ib16_bus_ready    <= 1;
                end 

                // UART Status register
                if (ib16_bus_address == UART_STS_ADDR) begin
                    ib16_bus_data_out <= {13'b0, uart_tx_fifo_empty, uart_tx_fifo_full, uart_rx_ready};
                    ib16_bus_ready    <= 1;
                end 
                // UART data register
                if (ib16_bus_address == UART_DATA_ADDR) begin
                    if (ib16_bus_wr_en) begin
                        case(bus_cycle[0])
                            0: // wait for a FIFO slot
                                begin
                                    if (!uart_tx_fifo_full) begin
                                        uart_tx_data_in <= ib16_bus_data_in[7:0];
                                        uart_tx_start   <= 1;
                                        bus_cycle       <= 1;
                                    end
                                end
                            1: // deassert and go to ready
                                begin
                                    uart_tx_start   <= 0;
                                    bus_cycle       <= 0;
                                    ib16_bus_ready  <= 1;
                                end
                        endcase
                    end else begin
                        case(bus_cycle[1:0])
                            0: // wait for incoming byte
                                begin
                                    if (uart_rx_ready) begin
                                        uart_rx_read    <= 1;
                                        bus_cycle       <= 1;
                                    end
                                end
                            1: // deassert read and delay for byte
                                begin
                                    uart_rx_read        <= 0;
                                    bus_cycle           <= 2;
                                end
                            2: // store byte and go back to idle
                                begin
                                    ib16_bus_data_out   <= uart_rx_byte;
                                    bus_cycle           <= 0;
                                    ib16_bus_ready      <= 1;
                                end
                        endcase
                    end
                end 
                // upto 2048 * BLOCKS is RAM
                if (ib16_bus_address < (16'h0800 * `BLOCKS)) begin
                    // BRAM block
                    case(bus_cycle[1:0])
                        0: // start transaction (this cycle delay handles the fact that bus_address is combinatorial)
                            begin
                                bram_ce     <= 1;
                                bram_wre    <= ib16_bus_wr_en;
                                bram_addr   <= ib16_bus_address[12:0];
                                bram_din    <= ib16_bus_data_in[7:0];
                                bus_cycle   <= bus_cycle + 1'b1;
                            end
                        1: // memory 2nd cycle
                            begin
                                if (bram_wre && !ib16_bus_burst) begin // 8-bit writes are done here
                                    bus_cycle       <= 0;
                                    bram_wre        <= 0;
                                    bram_ce         <= 0;
                                    ib16_bus_ready  <= 1;
                                end else begin                     // all reads take 3 cycles, burst writes take 3  
                                    bus_cycle       <= bus_cycle + 1'b1;
                                    bram_addr       <= bram_addr + 1'b1;
                                    bram_din        <= ib16_bus_data_in[15:8];
                                end
                            end
                        2: // memory 3rd cycle
                            begin
                                if (bram_wre) begin // writes are done here
                                    bram_ce             <= 0;
                                    bram_wre            <= 0;
                                    bus_cycle           <= 0;
                                    ib16_bus_ready      <= 1;
                                end else begin
                                    ib16_bus_data_out[7:0] <= bram_dout;
                                    if (!ib16_bus_burst) begin          // 8-bit reads are done here
                                        bus_cycle       <= 0;
                                        bram_ce         <= 0;
                                        ib16_bus_ready  <= 1;
                                    end else begin
                                        bus_cycle       <= bus_cycle + 1'b1;
                                    end
                                end
                            end
                        3: // memory 4th cycle (16-bit reads)
                            begin
                                ib16_bus_data_out[15:8] <= bram_dout;
                                bus_cycle               <= 0;
                                bram_ce                 <= 0;
                                ib16_bus_ready          <= 1;
                            end
                    endcase
                end

                // F000..F0FF is the boot ROM
                if (ib16_bus_address[15:8] == (`BOOT_ROM_ADDR >> 8)) begin
                    case(ib16_bus_address[5:0])
						8'h00: ib16_bus_data_out <= 16'h0eff;
						8'h02: ib16_bus_data_out <= 16'h0fff;
						8'h04: ib16_bus_data_out <= 16'h0cfb;
						8'h06: ib16_bus_data_out <= 16'h0dff;
						8'h08: ib16_bus_data_out <= 16'h0000;
						8'h0a: ib16_bus_data_out <= 16'h0100;
						8'h0c: ib16_bus_data_out <= 16'h021f;
						8'h0e: ib16_bus_data_out <= 16'h045a;
						8'h10: ib16_bus_data_out <= 16'h93fe;
						8'h12: ib16_bus_data_out <= 16'h7134;
						8'h14: ib16_bus_data_out <= 16'hd5fd;
						8'h16: ib16_bus_data_out <= 16'h93fe;
						8'h18: ib16_bus_data_out <= 16'ha3fe;
						8'h1a: ib16_bus_data_out <= 16'ha310;
						8'h1c: ib16_bus_data_out <= 16'h8050;
						8'h1e: ib16_bus_data_out <= 16'hd5fb;
						8'h20: ib16_bus_data_out <= 16'h8151;
						8'h22: ib16_bus_data_out <= 16'h8b71;
						8'h24: ib16_bus_data_out <= 16'habdc;
						8'h26: ib16_bus_data_out <= 16'h7112;
						8'h28: ib16_bus_data_out <= 16'hd5f6;
						8'h2a: ib16_bus_data_out <= 16'he008;
                        default: ib16_bus_data_out <= 16'h0000;
                    endcase
                    ib16_bus_ready <= 1;
                end
            end if (ib16_bus_ready && !ib16_bus_enable) begin
                ib16_bus_ready <= 0;
            end
        end
    end
endmodule 
