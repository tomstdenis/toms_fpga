// enable IRQs for UART supporting [0] = RX ready, [1] TX empty
//`define USE_UARTIRQ
`default_nettype none

// Simple IRQ, raises bus_irq if RX ready
`define USE_SIMPLE_UART_IRQ

// place stack at top of memory - 256 bytes, and the ISR 256 bytes before that
`define STACK_ADDRESS (16'h0800 * `BLOCKS - 16'h0100)
`define IRQ_VECTOR    (16'h0800 * `BLOCKS - 16'h0200)

// ROM is fixed into the first 256 bytes of the reserved F000..FFFF space
`define BOOT_ROM_ADDR 16'hF000

module top(input clk, 
	input uart_rx, output uart_tx, 
	inout [15:0] gpio,
	output reg [3:0] vga_r, output reg [3:0] vga_g, output reg [3:0] vga_b, output vga_h_pulse, output vga_v_pulse);

    localparam
		TEXTMEM			 = 16'hE800,
        TIMER_ADDR       = 16'hFFF9,
        GPIO1_DATA_ADDR  = 16'hFFFA,
        GPIO0_DATA_ADDR  = 16'hFFFB,
        UART_INT_ADDR    = 16'hFFFC,
        UART_INTEN_ADDR  = 16'hFFFD,
        UART_STS_ADDR    = 16'hFFFE,
        UART_DATA_ADDR   = 16'hFFFF;

	// Domain #1: IttyBitty @`FREQ
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

	// Domain #2: VGA @ 25.175
    wire pll2clk;
	wire pll2lock;
	
	pll2 mypll2(.clkin(clk), .clkout0(pll2clk), .locked(pll2lock));

	reg [3:0] rst2 = 0;
	wire rst2_n = rst2[3];
	
	always @(posedge pll2clk) begin
		if (pll2lock) begin
			rst2 <= {rst2[2:0], 1'b1};
		end
	end
	
    // ### GPIO ###
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


	// ### UART ###
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

	// ### main memory ###  we use a dual port 8-bit memory so we can do
	// 8 or 16 bit operations in the same amount of time
	reg [10+$clog2(`BLOCKS):0] main_mem_addr_a;
	reg [7:0] main_mem_din_a;
	reg main_mem_we_a;
	wire [7:0] main_mem_dout_a;
	
	reg [10+$clog2(`BLOCKS):0] main_mem_addr_b;
	reg [7:0] main_mem_din_b;
	reg main_mem_we_b;
	wire [7:0] main_mem_dout_b;

	bram_dp_nx2048x8 #(.N(`BLOCKS)) main_mem (
		.clk_a(pllclk), .clk_en_a(1'b1), .rst_a(~rst_n),
		.addr_a(main_mem_addr_a), .din_a(main_mem_din_a), .we_a(main_mem_we_a), .dout_a(main_mem_dout_a),
		
		.clk_b(pllclk), .clk_en_b(1'b1), .rst_b(~rst_n),
		.addr_b(main_mem_addr_b), .din_b(main_mem_din_b), .we_b(main_mem_we_b), .dout_b(main_mem_dout_b));
	// bit widths are for 640x480 VGA
	wire [9:0] vga_x;
	wire [9:0] vga_y;
	wire vga_h_sync;
	wire vga_v_sync;
	wire vga_active;
	
	assign vga_h_pulse = vga_h_sync;
	assign vga_v_pulse = vga_v_sync;

	// ### VGA ### this module produces the VGA timing signals other modules depend on
	vga_timing vga(
		.clk(pll2clk),
		.rst_n(rst2_n),
		.x(vga_x),
		.y(vga_y),
		.h_sync(vga_h_sync),
		.v_sync(vga_v_sync),
		.active_video(vga_active));

	wire [7:0] text_symbol;
	wire text_out;
	
	// ### font rom ### (note we scale y by 2 to fit the 80x25 chars onto 640x480 a bit nicer)
	// this module takes in the symbol value and x/y pixel position relative to the top left corner of the symbol
	vga_8x8_font_256 font(.symbol(text_symbol), .x(vga_x[2:0]), .y(vga_y[3:1]), .out(text_out));	

	reg [10:0] text_addr_a;
	reg [7:0] text_din_a;
	reg text_we_a;
	wire [7:0] text_dout_a;

	wire [10:0] text_addr_b;
	wire [7:0] text_dout_b;

	bram_dp_2048x8 text_mem(
		// IttyBitty Side
		.clk_a(pllclk), .clk_en_a(1'b1), .rst_a(~rst_n), 
		.addr_a(text_addr_a), .din_a(text_din_a), .we_a(text_we_a), .dout_a(text_dout_a),
		// Text Driver Side
		.clk_b(pll2clk), .clk_en_b(1'b1), .rst_b(~rst2_n), 
		.addr_b(text_addr_b), .din_b(), .we_b(1'b0), .dout_b(text_dout_b));

	// ### VGA text mode driver ###, defaults to 80x25 using an 8x8 font
	// notice we're scaling the font by 2 so we change the height to 16 here
	vga_text_driver #(.FONTHEIGHT(16)) textdrv(
		.clk(pll2clk), .rst_n(rst2_n),
		.x(vga_x), .y(vga_y), .active_video(vga_active),
		.rd_addr(text_addr_b), .rd_data(text_dout_b),
		.symbol(text_symbol));

	// drive the RGB outputs
	always @(*) begin
		vga_r = 0;
		vga_g = 0;
		vga_b = 0;
		
		if (vga_active) begin
			{vga_r, vga_g, vga_b} = text_out ? 12'b1111_1111_1111 : 12'b0;
		end
	end

	// ### IttyBitty Device ###
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
        .TWO_CYCLE(1)) ittybitty(
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
            main_mem_we_a 		<= 0;
            main_mem_addr_a		<= 0;
            main_mem_din_a		<= 0;
            main_mem_we_b 		<= 0;
            main_mem_addr_b		<= 0;
            main_mem_din_b		<= 0;
            ib16_bus_ready      <= 0;
            ib16_bus_data_out   <= 0;
            ib16_bus_irq        <= 0;
            bus_cycle           <= 0;
            gpio_out            <= 16'hFFFF;
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
								main_mem_we_a   <= ib16_bus_wr_en;
								main_mem_we_b   <= ib16_bus_burst ? ib16_bus_wr_en : 1'b0;
								main_mem_addr_a <= ib16_bus_address[10+$clog2(`BLOCKS):0];
								main_mem_addr_b <= ib16_bus_address[10+$clog2(`BLOCKS):0] + 1'b1;
                                main_mem_din_a  <= ib16_bus_data_in[7:0];
                                main_mem_din_b  <= ib16_bus_data_in[15:8];
                                bus_cycle       <= bus_cycle + 1'b1;
                            end
                        1: // memory 2nd cycle
                            begin
                                if (ib16_bus_wr_en) begin // writes are done here
                                    bus_cycle       <= 0;
                                    main_mem_we_a	<= 0;
                                    main_mem_we_b 	<= 0;
                                    ib16_bus_ready  <= 1;
                                end else begin                     // all reads take 3 cycles, burst writes take 3  
                                    bus_cycle       <= bus_cycle + 1'b1;
                                end
                            end
                        2: // memory 3rd cycle
                            begin
								ib16_bus_data_out[7:0]  <= main_mem_dout_a;
								ib16_bus_data_out[15:8] <= ib16_bus_burst ? main_mem_dout_b : 8'b0;
								bus_cycle               <= 0;
								ib16_bus_ready          <= 1;
							end
                    endcase
                end

                // TEXT VIDEO memory from E800..EFFF
                if (ib16_bus_address >= 16'hE800 && ib16_bus_address <= 16'hEFFF) begin
                    // TEXT MEM  block
                    case(bus_cycle[1:0])
                        0: // start transaction (this cycle delay handles the fact that bus_address is combinatorial)
                            begin
                                text_we_a     <= ib16_bus_wr_en;
                                text_addr_a   <= ib16_bus_address[10+$clog2(`BLOCKS):0];
                                text_din_a    <= ib16_bus_data_in[7:0];
                                bus_cycle     <= bus_cycle + 1'b1;
                            end
                        1: // memory 2nd cycle
                            begin
                                if (text_we_a && !ib16_bus_burst) begin // 8-bit writes are done here
                                    bus_cycle       <= 0;
                                    text_we_a       <= 0;
                                    ib16_bus_ready  <= 1;
                                end else begin                     // all reads take 3 cycles, burst writes take 3  
                                    bus_cycle       <= bus_cycle + 1'b1;
                                    text_addr_a     <= text_addr_a + 1'b1;
                                    text_din_a      <= ib16_bus_data_in[15:8];
                                end
                            end
                        2: // memory 3rd cycle
                            begin
                                if (text_we_a) begin // writes are done here
                                    text_we_a           <= 0;
                                    bus_cycle           <= 0;
                                    ib16_bus_ready      <= 1;
                                end else begin
                                    ib16_bus_data_out[7:0] <= text_dout_a;
                                    if (!ib16_bus_burst) begin          // 8-bit reads are done here
                                        bus_cycle       <= 0;
                                        ib16_bus_ready  <= 1;
                                    end else begin
                                        bus_cycle       <= bus_cycle + 1'b1;
                                    end
                                end
                            end
                        3: // memory 4th cycle (16-bit reads)
                            begin
                                ib16_bus_data_out[15:8] <= text_dout_a;
                                bus_cycle               <= 0;
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
						8'h0c: ib16_bus_data_out <= 16'h045a;
						8'h0e: ib16_bus_data_out <= 16'h93fe;
						8'h10: ib16_bus_data_out <= 16'h7134;
						8'h12: ib16_bus_data_out <= 16'hd5fd;
						8'h14: ib16_bus_data_out <= 16'h92fe;
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
						8'h2a: ib16_bus_data_out <= 16'h4000;
						8'h2c: ib16_bus_data_out <= 16'he008;
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
