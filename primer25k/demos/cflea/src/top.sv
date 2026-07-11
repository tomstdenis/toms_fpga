/*

    C-FLEA Top for Primer 25K + my rev3 PMOD Hat

Simple memory map of 60K of RAM followed by 2K boot ROM, and 2K video memory

    - 0000..EFFF: Main system RAM
    - F000..F7FF: Boot ROM
    - F800..FFFF: Text/LRG video memory

If you're not using the VGA output you can use it as "more memory" just keep in mind
that it's slower than main memory since it's single ported (to the cpu).  

Currently cycle counts as follows:

Current timing:
Cycle counts:
        RDTSC: 3
        CALL: 11
        RET: 8
        ADD #FFFF: 8
        LD 0000: 12
        ST 8000: 11
        LD 2,S: 8
        LT: 4
        CLR: 4
        ST $F800: 13
        LD $F800: 14
        LD $F000: 12
        TSA: 4
        OUT $01: 7
        DIV $FFFF/$11 (+LD 0000): 47
        ADDB #$FF: 5
        SHL #5: 5
        ST 2,S: 8
        SJMP NEXT: 5

Keep in mind ALU opcodes (LD, ADD, SUB, etc...) have all the same timing (except DIV) which means LD 0000 takes the same time as ADD 0000, etc.
Similarly, LEI, ST/STB/STI opcodes have similar timing.

Main memory and boot rom have the same timing.  Video memory is slower since we only have 1 port to work with.

for I/O the following ports are used

   - 00h: uart data (non-blocking read => returns FFFF is no char available on read, blocking writes if FIFO is full)
          UART has an 8 byte RX and 8 byte TX FIFO and is set to 230400 baud 8N1
   - 01h...04h: gpio0-gpio4 data pins.  Bits [7:0] are the data, and bits [15:8] are writemasks (0 == write, 1 == ignore)
   - 05h...08h: gpio0-gpio4 direction pins.  Bits [7:0] control whether the pin is output (1) or input (0)
   - 10h: uart status (uart_rx_ready, uart_tx_fifo_empty, uart_tx_fifo_full)
   - 11h: timer (counts 1us ticks, writing anything to it resets to 0)
   - 12h: video mode (lsb == lrg_mode (48x40 8-bit colour mode, text mode is 1 byte per character 80x25 mode using CP437)
   - 13h: WDT, non-zero value means if the tick_counter (11h) matches it triggers a reset.  A zero value disables the WDT
          The idea is you write to 11h before the tick counter matches 
   
   - F0h..F3h: Digilent SPI PMOD optimized block, use with OUT, upper 8 bits divide core clock so you get `FREQ / (2 * (data_out[15:8] + 1))
               For instance at the stock FREQ=125 putting [say] the value '3' in the upper 8 bits would result in an SCK frequency of
               (125MHz / 2) / (3 + 1) == 15.625MHz
*/

`timescale 1ns/1ps
`default_nettype none

// version of TOP to report to the ISA
`define CF_TOP_VER 8'h03

// number of 2KB blocks in main memory
`define BLOCKS 30

// core clock frequency the PLL is tuned to 
`define FREQ 130

// UART fifo depth for both RX and TX
`define UART_FIFO_DEPTH 8

// UART baud rate
`define UART_BAUD 230_400

module top(input wire clk, input wire s1,
	input wire uart_rx, output wire uart_tx, 
	inout wire [31:0] gpio, output wire [7:0] mon,
	output reg [3:0] vga_r, output reg [3:0] vga_g, output reg   [3:0] vga_b, output wire vga_h_pulse, output wire vga_v_pulse);

    // Should the main mem be combinatorial or synchronous
    localparam
        MAIN_MEM_COMB = 0;

    // I/O space addresses for various functions
    localparam
        io_port_uart  = 8'h00,                  // uart DATA, used to read/write serial data
        io_port_gpio0 = 8'h01,                  // GPIO0..3 data ports
        io_port_gpio1 = 8'h02,
        io_port_gpio2 = 8'h03,
        io_port_gpio3 = 8'h04,
        io_port_gpio0_oe = 8'h05,               // GPIO0..3 output enables
        io_port_gpio1_oe = 8'h06,
        io_port_gpio2_oe = 8'h07,
        io_port_gpio3_oe = 8'h08,
        io_port_uart_status = 8'h10,            // UART status port
        io_port_timer = 8'h11,                  // 1uS timer port
        io_port_video = 8'h12,                  // video signalling/mode setting ported
        io_port_wdt   = 8'h13;                  // uS based WDT (0==disable==default)

    localparam
        bus_address_main_mem_top = (16'h0800 * `BLOCKS - 16'd1),    // top of system memory
		bus_address_text_mem_bot = 16'hF800,                // bottom of video memory (2KB)
		bus_address_text_mem_top = 16'hFFFF,                // top of video memory 
		bus_address_rom_mem_bot  = 16'hF000,                // bottom of BOOT ROM space (2KB)
		bus_address_rom_mem_top  = 16'hF7FF;                // top of BOOT ROM space

    // Digilent PMOD SPI configured devices 
    localparam
        gpio_spi_sck  = 3'd0,                   // SCK pin
        gpio_spi_miso = 3'd1,                   // MISO pin
        gpio_spi_mosi = 3'd2,                   // MOSI pin
        gpio_spi_cs   = 3'd3;                   // CS pin

	// Domain #1: CFLEA @`FREQ
    logic pllclk;
	
    // reset control, reset is asserted for first few cycles also if the reset_sw is held down
	reg [3:0] rst = 0;
    reg [1:0] reset_sw;
    localparam
		CYCLES_PER_TICK = `FREQ; // ticks per uS
    reg [15:0] tick_counter;
    reg [$clog2(CYCLES_PER_TICK):0] cycle_counter;

    reg [15:0] wdt;
    wire wdt_reset = ~(wdt > 0 && wdt == tick_counter);
	wire rst_n = rst[3] & ~reset_sw[1] & wdt_reset; // s1 is pulled up by the button so we want to pull reset low when the button is pressed
	
	always @(posedge pllclk) begin
        reset_sw <= {reset_sw[0], s1 };
        rst <= {rst[2:0], 1'b1};
	end

	// Domain #2: VGA @ 25MHz
    logic pll2clk;
	
	reg [3:0] rst2 = 0;
	wire rst2_n = rst2[3] & ~s1;
	
	always @(posedge pll2clk) begin
        rst2 <= {rst2[2:0], 1'b1};
	end
	
    // PLLs
    cflea_pll ms_minutes(
        .clkin(clk),        //input  clkin      (50MHz XTAL)
        .clkout0(pllclk),   //output  clkout0   (125MHz CFLEA clock)
        .clkout1(pll2clk),  //output  clkout1   (25MHz VGA clock)
        .mdclk());          //input  mdclk

    // ### GPIO ###
    reg [31:0] gpio_oe;
    reg [31:0] gpio_out;
    wire [31:0] gpio_in;

    genvar i;
    generate
        for (i = 0; i < 32; i = i + 1) begin : gpio_en
            assign gpio[i] = gpio_oe[i] ? gpio_out[i] : 1'bz;         // requires PULL up 
        end
    endgenerate
    assign gpio_in = gpio;
    assign mon = gpio[7:0];

	// ### UART ###
    localparam
        baud_width = $clog2((`FREQ * 1_000_000) / `UART_BAUD);

    wire [baud_width-1:0] baud_div = (`FREQ * 1_000_000) / `UART_BAUD;
    logic uart_tx_start;
    logic [7:0] uart_tx_data_in;
    logic uart_tx_fifo_full;
    logic uart_tx_fifo_empty;
    logic uart_rx_read;
    logic uart_rx_ready;
    logic [7:0] uart_rx_byte;

    logic uart_prev_tx_fifo_empty;
    logic uart_prev_rx_ready;

    uart #(.BAUD_WIDTH(baud_width), .FIFO_DEPTH(`UART_FIFO_DEPTH), .RX_ENABLE(1), .TX_ENABLE(1)) mrtalky (
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
	logic [7:0] main_mem_dout_a;
	logic [7:0] main_mem_dout_b;

    // detect writes to main memory
    wire main_mem_wr_en = (cf_bus_io_flag == 0 && cf_bus_address[15:0] <= bus_address_main_mem_top && cf_bus_wr_en);

    cflea_main_mem cflea_mem(
        .douta(main_mem_dout_a), //output [7:0] douta
        .clka(pllclk), //input clka
        .ocea(1'b1), //input ocea
        .cea(1'b1), //input cea
        .reseta(~rst_n), //input reseta
        .wrea(main_mem_wr_en), //input wrea
        .ada(cf_bus_address[15:0]), //input [15:0] ada
        .dina(cf_bus_data_in[7:0]), //input [7:0] dina

        .doutb(main_mem_dout_b), //output [7:0] doutb
        .clkb(pllclk), //input clkb
        .oceb(1'b1), //input oceb
        .ceb(1'b1), //input ceb
        .resetb(~rst_n), //input resetb
        .wreb(cf_bus_burst && main_mem_wr_en), //input wreb
        .adb(cf_bus_address[15:0] + 1'b1), //input [15:0] adb
        .dinb(cf_bus_data_in[15:8]) //input [7:0] dinb
    );

    // bit widths are for 640x480 VGA
	logic [10:0] vga_x;                     // VGA X position
	logic [10:0] vga_y;                     // VGA Y position
	logic vga_h_sync;                       // VGA H sync (active low)
	logic vga_v_sync;                       // VGA V sync (active low)
	logic vga_active;                       // VGA in display region
    reg vga_active_1;
    reg vga_v_sync_1;
    reg vga_h_sync_1;
	
	always_ff @(posedge pll2clk) begin
        vga_active_1    <= vga_active;
        vga_v_sync_1    <= vga_v_sync;
        vga_h_sync_1    <= vga_h_sync;
    end
	
	assign vga_h_pulse = vga_h_sync;        // assign syncs to I/O pins
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

    // text rendering
	logic [7:0] text_symbol;                // The current symbol to draw
	logic text_out;                         // The current pixel to draw
	
    // for performance we're using a BRAM in pROM mode for the font
    // this incurs the 1 cycle latency which means we need some trickery
    // with the y position...
    // vga_y_p1 accounts for the fact we need the value of y the next cycle to account
    // for the fact the font rom is synchronous.
    wire [10:0] vga_y_p1 = (vga_y + (vga_x == 799 ? 1'b1 : 1'b0));
    wire [7:0] font_dout;                           // output of rom
    wire [10:0] font_ad = {text_symbol, vga_y_p1[3:1]};     // address into the rom, it's 11 bits of which the top 8 are the symbol and bottom 3 are the row
    assign text_out = font_dout[7 - vga_x[2:0]];    // bit of output indexed from the ROM output

    // our 256 symbol 8x8 CP437 font
    text_font_rom madamme_font(
        .dout(font_dout), //output [7:0] dout
        .clk(pll2clk), //input clk
        .oce(1'b1), //input oce
        .ce(1'b1), //input ce
        .reset(~rst2_n), //input reset
        .wre(1'b0), //input wre
        .ad(font_ad), //input [10:0] ad
        .din(8'b0) //input [7:0] din
    );

    // video memory ports
	logic [10:0] text_addr_a;                   // CPU bound port A allows SW to read/write from video memory
	logic [7:0] text_din_a;
	logic text_we_a;
	logic [7:0] text_dout_a;

	logic [10:0] text_addr_b;                   // VGA bound port B allows the video to access video ram
	logic [7:0] text_dout_b;
	
	logic lrg_mode, lrg_mode_1;                             // 0 == 80x25, 1 == 48x40 LRG
    logic [1:0] lrg_mode_pll2;                  // 2-FF chain to bring signal into VGA clock domain

    // The 2KB bram for video memory
    video_mem reliving_my_childhood (
        .ada(text_addr_a), //input [10:0] ada
        .cea(1'b1), //input cea
        .clka(pllclk), //input clka
        .dina(text_din_a), //input [7:0] dina
        .douta(text_dout_a), //output [7:0] douta
        .ocea(1'b1), //input ocea
        .reseta(~rst_n), //input reseta
        .wrea(text_we_a), //input wrea

        .adb(text_addr_b), //input [10:0] adb
        .ceb(1'b1), //input ceb
        .clkb(pll2clk), //input clkb
        .dinb(8'b0), //input [7:0] dinb
        .doutb(text_dout_b), //output [7:0] doutb
        .oceb(1'b1), //input oceb
        .resetb(~rst2_n), //input resetb
        .wreb(1'b0) //input wreb
    );

	// ### VGA text mode driver ###, defaults to 80x25 using an 8x8 font
	// notice we're scaling the font by 2 so we change the height to 16 here
	// also since we don't use the full y resolution anyways we shift things down so the overscan doesn't eat the first line
	vga_text_driver #(.FONTHEIGHT(16), .X_FETCH_DELAY(2)) textdrv(
		.clk(pll2clk), .rst_n(rst2_n),
		.x(vga_x), .y(vga_y), .active_video(vga_active), .lrg_mode(lrg_mode_pll2[1]),
		.rd_addr(text_addr_b), .rd_data(text_dout_b),
		.symbol(text_symbol));

	// drive the RGB outputs
	always_comb begin
		vga_r = 0;
		vga_g = 0;
		vga_b = 0;
		
		if (vga_active) begin
			if (!lrg_mode) begin
				{vga_r, vga_g, vga_b} = text_out ? 12'b1111_1111_1111 : 12'b0001_0001_0001;
			end else begin
				{vga_r, vga_g, vga_b} = {
					{ text_symbol[2:0], &text_symbol[2:0] }, 
					{ text_symbol[5:3], &text_symbol[5:3] }, 
					{ text_symbol[7:6], text_symbol[7:6] }
				};
			end
		end
	end

    // ### boot rom

    // This is wire up the CF bus directly so we don't need an extra bus cycle to latch address
    wire [7:0] boot_rom_dout_a;
    wire [7:0] boot_rom_dout_b;

    boot_rom mr_bootup(
        .douta(boot_rom_dout_a), //output [7:0] douta
        .doutb(boot_rom_dout_b), //output [7:0] doutb
        .clka(pllclk), //input clka
        .ocea(1'b1), //input ocea
        .cea(1'b1), //input cea
        .reseta(~rst_n), //input reseta
        .wrea(1'b0), //input wrea
        .clkb(pllclk), //input clkb
        .oceb(1'b1), //input oceb
        .ceb(1'b1), //input ceb
        .resetb(~rst_n), //input resetb
        .wreb(1'b0), //input wreb
        .ada(cf_bus_address[10:0]), //input [10:0] ada
        .dina(8'b0), //input [7:0] dina
        .adb(cf_bus_address[10:0] + 1'b1), //input [10:0] adb
        .dinb(8'b0) //input [7:0] dinb
    );

    // ### CFLEA core
    wire [16:0] cf_bus_address;
    wire cf_bus_wr_en;
    wire cf_bus_io_flag;
    wire cf_bus_burst;
    wire [15:0] cf_bus_data_in;
    wire cf_bus_enable;
    reg cf_bus_ready;
    reg [15:0] cf_bus_data_out;
    reg [1:0] bus_cycle;
    reg [15:0] cf_bus_data_out_comb;

    cf_cpu #(
        .TOP_VER(`CF_TOP_VER),
        .BOOT_VECTOR(bus_address_rom_mem_bot),
        .USE_BARREL(1)) mr_thinky(
        .clk(pllclk), .rst_n(rst_n),
        .bus_address(cf_bus_address),
        .bus_wr_en(cf_bus_wr_en),
        .bus_io_flag(cf_bus_io_flag),
        .bus_burst(cf_bus_burst),
        .bus_data_in(cf_bus_data_in),
        .bus_enable(cf_bus_enable),
        .bus_ready(cf_bus_ready),
        .bus_data_out(cf_bus_data_out_comb));

    always_ff @(posedge pll2clk) begin
        lrg_mode_pll2 <= {lrg_mode_pll2[0], lrg_mode_1};
    end

    always_comb begin
        cf_bus_data_out_comb = cf_bus_data_out;
        if (MAIN_MEM_COMB == 1 && cf_bus_io_flag == 0) begin
            if (cf_bus_address[15:0] <= bus_address_main_mem_top) begin
                cf_bus_data_out_comb = { cf_bus_burst ? main_mem_dout_b : 8'b00, main_mem_dout_a };
            end
        end
    end

    reg [1:0] vga_v_sync_cf;
    reg [1:0] vga_h_sync_cf;
    reg [1:0] vga_active_cf;

    wire [7:0] cur_gpio_bits = gpio_out[(cf_bus_address[7:0] - io_port_gpio0) * 8 +: 8];

    reg [7:0] spi_sr;
    reg [7:0] spi_timer;
    reg [2:0] spi_cnt;

    // bus controller
    always_ff @(posedge pllclk) begin
        if (!rst_n) begin
            uart_tx_start       <= 0;
            uart_tx_data_in     <= 0;
            uart_rx_read        <= 0;
            bus_cycle           <= 0;
            gpio_out            <= 32'hFFFFFFFF;
            gpio_oe             <= 32'h00000000;
            cf_bus_ready        <= 0;
            cf_bus_data_out     <= 0;
            tick_counter        <= 0;
            cycle_counter       <= 0;
            lrg_mode            <= 0;
            vga_v_sync_cf       <= 0;
            vga_h_sync_cf       <= 0;
            wdt                 <= 0;
        end else begin
            lrg_mode_1    <= lrg_mode;
            vga_v_sync_cf <= {vga_v_sync_cf[0], vga_v_sync_1};  // 2-DFF sync the VGA V Sync into the CFLEA clock domain
            vga_h_sync_cf <= {vga_h_sync_cf[0], vga_h_sync_1};  // same for hsync
            vga_active_cf <= {vga_active_cf[0], vga_active_1};  // same for vga_active

			// tick counter logic
            if (cycle_counter == (CYCLES_PER_TICK-1)) begin
				cycle_counter <= 0;
				tick_counter  <= tick_counter + 1'b1;
			end else begin
				cycle_counter <= cycle_counter + 1'b1;
			end

            if (cf_bus_enable && !cf_bus_ready) begin
                bus_cycle <= bus_cycle + 1'b1;
                if (cf_bus_io_flag) begin
                    // handle I/O
                    if (cf_bus_address[7:0] == io_port_uart) begin // UART DATA
                        if (cf_bus_wr_en) begin // writes
                            if (bus_cycle == 0) begin
                                if (!uart_tx_fifo_full) begin
                                    uart_tx_data_in <= cf_bus_data_in[7:0];
                                    uart_tx_start   <= 1'b1;
                                end else begin
                                    bus_cycle <= bus_cycle;
                                end
                            end else if (bus_cycle == 1) begin
                                cf_bus_ready  <= 1'b1;
                                uart_tx_start <= 1'b0;
                            end                            
                        end else begin // reads
                            if (bus_cycle == 0) begin
                                if (uart_rx_ready) begin
                                    uart_rx_read <= 1'b1;
                                end else begin
                                    // Dave's model returns -1 if there's no char...
                                    cf_bus_ready    <= 1'b1;
                                    cf_bus_data_out <= 16'hFFFF; // note this must be 16 bit since his INC/JZ/DEC test relies on FFFF rolling to 0
                                end
                            end else if (bus_cycle == 1) begin
                                uart_rx_read <= 1'b0;
                            end else if (bus_cycle == 2) begin
                                cf_bus_ready    <= 1'b1;
                                cf_bus_data_out <= { 8'h00, uart_rx_byte };
                            end
                        end
                    end else if (cf_bus_address[7:0] <= io_port_gpio3) begin // GPIO0..GPIO3
                        if (cf_bus_wr_en) begin
                            gpio_out[(cf_bus_address[7:0] - io_port_gpio0) * 8 +: 8] <= 
                                (cur_gpio_bits & cf_bus_address[15:8]) | (~cf_bus_address[15:8] & cf_bus_data_in[7:0]);
                        end else begin
                            gpio_out[(cf_bus_address[7:0] - io_port_gpio0) * 8 +: 8] <= cur_gpio_bits ^ cf_bus_data_in[15:8];
                            cf_bus_data_out <= { 8'b0, gpio_in[(cf_bus_address[7:0] - io_port_gpio0) * 8 +: 8] ^ cf_bus_data_in[15:8]};
                        end
                        cf_bus_ready    <= 1'b1;
                    end else if (cf_bus_address[7:0] <= io_port_gpio3_oe) begin // GPIO0..GPIO3
                        if (cf_bus_wr_en) begin
                            gpio_oe[(cf_bus_address[7:0] - io_port_gpio0_oe) * 8 +: 8] <= cf_bus_data_in[7:0];
                        end else begin
                            cf_bus_data_out <= { 8'b0, gpio_oe[(cf_bus_address[7:0] - io_port_gpio0_oe) * 8 +: 8] };
                        end
                        cf_bus_ready    <= 1'b1;
                    end else if (cf_bus_address[7:0] == io_port_uart_status) begin // uart status
                        cf_bus_data_out <= { 8'h00, 5'b0, uart_rx_ready, uart_tx_fifo_empty, uart_tx_fifo_full };
                        cf_bus_ready    <= 1'b1;
                    end else if (cf_bus_address[7:0] == io_port_timer) begin // timer 1us tick
                        if (cf_bus_wr_en) begin
                            tick_counter <= 0;
                        end
                        cf_bus_data_out <= tick_counter;
                        cf_bus_ready    <= 1'b1;
                    end else if (cf_bus_address[7:0] == io_port_video) begin // video flags 
                        if (cf_bus_wr_en) begin
                            lrg_mode <= cf_bus_data_in[0];
                        end
                        cf_bus_data_out <= {12'b0, vga_active_cf[1], vga_h_sync_cf[1], vga_v_sync_cf[1], lrg_mode};
                        cf_bus_ready    <= 1'b1;
                    end else if (cf_bus_address[7:0] == io_port_wdt) begin // WDT
                        if (cf_bus_wr_en) begin
                            wdt          <= cf_bus_data_in;
                        end
                        cf_bus_data_out <= wdt; 
                        cf_bus_ready    <= 1'b1;
                    end else if (cf_bus_address[7:2] == 6'b111100) begin // SPI ports (0xF0..0xF3)
                        if (bus_cycle[0] == 0) begin
                            spi_cnt                                        <= 7;
                            spi_sr                                         <= cf_bus_data_in[7:0];
                            spi_timer                                      <= cf_bus_data_in[15:8];
                            gpio_out[{cf_bus_address[1:0], gpio_spi_sck}]  <= 1'b0;
                            gpio_out[{cf_bus_address[1:0], gpio_spi_mosi}] <= cf_bus_data_in[7];
                        end else if (bus_cycle[0] == 1) begin
                            // do SPI protocol
                            bus_cycle <= bus_cycle;                         // stay on this bus cycle
                            spi_timer <= spi_timer - 1'b1;
                            if (spi_timer == 0) begin
                                spi_timer                                     <= cf_bus_data_in[15:8];
                                gpio_out[{cf_bus_address[1:0], gpio_spi_sck}] <= ~gpio_out[{cf_bus_address[1:0], gpio_spi_sck}];
                            end

                            if (gpio_out[{cf_bus_address[1:0], gpio_spi_sck}] == 1'b0) begin
                                // SCK low
//                                gpio_out[{cf_bus_address[1:0], gpio_spi_mosi] <= spi_sr[7];
                            end else begin
                                // SCK high
                                if (spi_timer == 0) begin
                                    // last cycle that SCK will be high still
                                    spi_sr                                         <= {spi_sr[6:0], gpio[{cf_bus_address[1:0], gpio_spi_miso}]};
                                    gpio_out[{cf_bus_address[1:0], gpio_spi_mosi}] <= spi_sr[6];
                                    spi_cnt                                        <= spi_cnt - 1'b1;
                                    if (spi_cnt == 0) begin
                                        cf_bus_data_out                               <= {8'b0, spi_sr[6:0], gpio[{cf_bus_address[1:0], gpio_spi_miso}]};
                                        cf_bus_ready                                  <= 1'b1;
                                        gpio_out[{cf_bus_address[1:0], gpio_spi_sck}] <= 1'b0;
                                    end
                                end
                            end
                        end
                    end else begin
                        // default to just ack the bus
                        cf_bus_ready <= 1'b1;
                    end
                end else begin
                    // handle memory (we fold 128K to 64K)
                    if (cf_bus_address[15:0] <= bus_address_main_mem_top) begin
                        // main mem
                        if (MAIN_MEM_COMB == 1) begin
                            cf_bus_ready <= 1;
                        end else begin
                            if (bus_cycle[0] == 0) begin
                                if (cf_bus_wr_en) begin
                                    cf_bus_ready <= 1'b1;
                                end
                            end else if (bus_cycle[0] == 1) begin
                                cf_bus_ready    <= 1;
                                cf_bus_data_out <= { cf_bus_burst ? main_mem_dout_b : 8'b00, main_mem_dout_a };
                            end
                        end
                    end else if (cf_bus_address[15:0] <= bus_address_rom_mem_top) begin
                        // rom memory
                        if (bus_cycle[0] == 0) begin
                        end else if (bus_cycle[0] == 1) begin
                            cf_bus_ready    <= 1;
                            cf_bus_data_out <= { cf_bus_burst ? boot_rom_dout_b : 8'b00, boot_rom_dout_a };
                        end
                    end else if (cf_bus_address[15:0] <= bus_address_text_mem_top) begin
                        // video memory
                        if (bus_cycle == 0) begin
                            text_addr_a <= cf_bus_address[10:0];
                            text_din_a  <= cf_bus_data_in[7:0];
                            text_we_a   <= cf_bus_wr_en;
                        end else if (bus_cycle == 1) begin
                            text_addr_a <= text_addr_a + 1'b1;
                            text_din_a  <= cf_bus_data_in[15:8];
                            if (!cf_bus_burst && cf_bus_wr_en) begin
                                text_we_a <= 1'b0;
                                cf_bus_ready <= 1'b1;
                            end
                        end else if (bus_cycle == 2) begin
                            text_we_a <= 1'b0;
                            if (cf_bus_wr_en) begin
                                cf_bus_ready <= 1'b1;
                            end else begin
                                cf_bus_data_out <= { 8'h00, text_dout_a };
                                if (!cf_bus_burst) begin
                                    cf_bus_ready <= 1'b1;
                                end
                            end
                        end else if (bus_cycle == 3) begin
                            cf_bus_data_out[15:8] <= text_dout_a;
                            cf_bus_ready <= 1'b1;
                        end
                    end else begin
                        // if we have gaps later...
                        cf_bus_ready <= 1'b1;
                    end
                end
            end
            if (!cf_bus_enable && cf_bus_ready) begin
                cf_bus_ready <= 1'b0;
                bus_cycle <= 0;
            end
        end
    end
endmodule 
