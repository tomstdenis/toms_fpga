/* IttyBitty SoC for ECP5 */
// enable IRQs for UART supporting [0] = RX ready, [1] TX empty
`timescale 1ns/1ps
`default_nettype none
`define BLOCKS 16
`define FREQ 100

// place stack at top of memory - 256 bytes, and the ISR 256 bytes before that
`define STACK_ADDRESS (16'h0800 * `BLOCKS - 16'h0100)
`define IRQ_VECTOR    (16'h0800 * `BLOCKS - 16'h0200)

// ROM is fixed into the first 256 bytes of the reserved F000..FFFF space
`define BOOT_ROM_ADDR 16'hF000

module top(input wire clk, 
	input wire uart_rx, output wire uart_tx, 
	inout wire [7:0] gpio,
	output reg [3:0] vga_r, output reg [3:0] vga_g, output reg   [3:0] vga_b, output wire vga_h_pulse, output wire vga_v_pulse);

    localparam
		TEXTMEM			 	  = 16'hE800,
		VIDEO_MODE_FLAG_ADDR  = 16'hFFF8,
        TIMER_ADDR       = 16'hFFF9,
        GPIO1_DATA_ADDR  = 16'hFFFA,
        GPIO0_DATA_ADDR  = 16'hFFFB,
        UART_INT_ADDR    = 16'hFFFC,
        UART_INTEN_ADDR  = 16'hFFFD,
        UART_STS_ADDR    = 16'hFFFE,
        UART_DATA_ADDR   = 16'hFFFF,
        bus_address_main_mem_top = `BLOCKS * 16'h0800,
		bus_address_text_mem_bot = 16'hE800,
		bus_address_text_mem_top = 16'hEFFF,
		bus_address_rom_mem_bot  = 16'hF000,
		bus_address_rom_mem_top  = 16'hF0FF;

	// Domain #1: IttyBitty @`FREQ
    logic pllclk;
	
	reg [3:0] rst = 0;
	wire rst_n = rst[3];
	
	always @(posedge pllclk) begin
        rst <= {rst[2:0], 1'b1};
	end

	// Domain #2: VGA @ 25.175
    logic pll2clk;
	
	reg [3:0] rst2 = 0;
	wire rst2_n = rst2[3];
	
	always @(posedge pll2clk) begin
        rst2 <= {rst2[2:0], 1'b1};
	end
	
    // PLLs
    Gowin_PLL ms_minutes(
        .clkin(clk), //input  clkin
        .clkout0(pllclk), //output  clkout0
        .clkout1(pll2clk), //output  clkout1
        .mdclk()); //input  mdclk

    // ### GPIO ###
    reg [7:0] gpio_out;
    wire [7:0] gpio_in;

    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin : gpio_en
            assign gpio[i] = gpio_out[i] ? 1'bz : 1'b0;         // requires PULL up 
        end
    endgenerate
    assign gpio_in = gpio;

	// ### UART ###
    wire [15:0] baud_div = (`FREQ * 1_000_000) / 230_400;
    logic uart_tx_start;
    logic [7:0] uart_tx_data_in;
    logic uart_tx_fifo_full;
    logic uart_tx_fifo_empty;
    logic uart_rx_read;
    logic uart_rx_ready;
    logic [7:0] uart_rx_byte;

	// trap IRQs
	localparam
		IRQ_UART_RX_READY      = 0,
		IRQ_UART_TX_FIFO_EMPTY = 1,
		IRQ_TIMER              = 2,
		IRQ_VSYNC              = 3;

    logic uart_prev_tx_fifo_empty;
    logic uart_prev_rx_ready;
    logic [7:0] int_enable;
    logic [7:0] int_pending;

    uart #(.FIFO_DEPTH(64), .RX_ENABLE(1), .TX_ENABLE(1)) mrtalky (
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
	logic [10+$clog2(`BLOCKS):0] main_mem_addr_a;
	logic [7:0] main_mem_din_a;
	logic main_mem_we_a;
	logic [7:0] main_mem_dout_a;
	
	logic [10+$clog2(`BLOCKS):0] main_mem_addr_b;
	logic [7:0] main_mem_din_b;
	logic main_mem_we_b;
	logic [7:0] main_mem_dout_b;

    main_memory so_many_ib16_memories(
        .douta(main_mem_dout_a), //output [7:0] douta
        .doutb(main_mem_dout_b), //output [7:0] doutb
        .clka(pllclk), //input clka
        .ocea(1'b1), //input ocea
        .cea(1'b1), //input cea
        .reseta(~rst_n), //input reseta
        .wrea(main_mem_we_a), //input wrea
        .clkb(pllclk), //input clkb
        .oceb(1'b1), //input oceb
        .ceb(1'b1), //input ceb
        .resetb(~rst_n), //input resetb
        .wreb(main_mem_we_b), //input wreb
        .ada(main_mem_addr_a), //input [14:0] ada
        .dina(main_mem_din_a), //input [7:0] dina
        .adb(main_mem_addr_b), //input [14:0] adb
        .dinb(main_mem_din_b) //input [7:0] dinb
    );

    // bit widths are for 640x480 VGA
	logic [10:0] vga_x;
	logic [10:0] vga_y;
	logic vga_h_sync;
	logic vga_v_sync;
	logic vga_v_sync_prev;
	logic vga_active;
	
	always_ff @(posedge pll2clk) begin
		vga_v_sync_prev <= vga_v_sync;
	end
	
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

	logic [7:0] text_symbol;
	logic text_out;
	
	// ### font rom ### (note we scale y by 2 to fit the 80x25 chars onto 640x480 a bit nicer)
	// this module takes in the symbol value and x/y pixel position relative to the top left corner of the symbol
//	vga_8x8_font_256 font(.symbol(text_symbol), .x(vga_x[2:0]), .y(vga_y[3:1]), .out(text_out));	

    // on Gowin a Shadow ROM is better as it's both faster and smaller (and faster to compile)
    wire [7:0] font_dout;                           // output of rom
    wire [10:0] font_ad = {text_symbol, vga_y[3:1]};     // address into the rom, it's 11 bits of which the top 8 are the symbol and bottom 3 are the row
    assign text_out = font_dout[7 - vga_x[2:0]];    // bit of output indexed from the ROM output

    // our 256 symbol 8x8 CP437 font
    font_rom madamme_font(
        .dout(font_dout), //output [7:0] dout
        .ad(font_ad) //input [10:0] ad
    );

	logic [10:0] text_addr_a;
	logic [7:0] text_din_a;
	logic text_we_a;
	logic [7:0] text_dout_a;

	logic [10:0] text_addr_b;
	logic [7:0] text_dout_b;
	
	logic lrg_mode;

    text_mem reliving_my_childhood (
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
        .dinb(text_dout_b), //input [7:0] dinb
        .doutb(text_dout_b), //output [7:0] doutb
        .oceb(1'b1), //input oceb
        .resetb(~rst2_n), //input resetb
        .wreb(1'b0) //input wreb
    );

	// ### VGA text mode driver ###, defaults to 80x25 using an 8x8 font
	// notice we're scaling the font by 2 so we change the height to 16 here
	// also since we don't use the full y resolution anyways we shift things down so the overscan doesn't eat the first line
	vga_text_driver #(.FONTHEIGHT(16)) textdrv(
		.clk(pll2clk), .rst_n(rst2_n),
		.x(vga_x), .y(vga_y), .active_video(vga_active), .lrg_mode(lrg_mode),
		.rd_addr(text_addr_b), .rd_data(text_dout_b),
		.symbol(text_symbol));

	// drive the RGB outputs
	always_comb begin
		vga_r = 0;
		vga_g = 0;
		vga_b = 0;
		
		if (vga_active) begin
			if (!lrg_mode) begin
				{vga_r, vga_g, vga_b} = text_out ? 12'b1111_1111_1111 : 12'b1_0001_0001;
			end else begin
				{vga_r, vga_g, vga_b} = {
					{ text_symbol[2:0], &text_symbol[2:0] }, 
					{ text_symbol[5:3], &text_symbol[5:3] }, 
					{ text_symbol[7:6], text_symbol[7:6] }
				};
			end
		end
	end

	// ### IttyBitty Device ###
    logic ib16_bus_enable;
    logic ib16_bus_enable_prev;
    logic ib16_bus_wr_en;
    logic [15:0] ib16_bus_address;
    logic [15:0] ib16_bus_address_l;
    logic [15:0] ib16_bus_data_in;
    logic ib16_bus_ready;
    logic [15:0] ib16_bus_data_out_reg;
    logic [15:0] ib16_bus_data_out;
    logic [7:0] ib16_bus_irq;
    logic ib16_bus_burst;

	// we use a combinatorial bus output to allow cutting 1 cycle on the return path
    always_comb begin
		ib16_bus_data_out = 16'b0; // default
		if (!ib16_bus_wr_en) begin // only assign on reads
			if (ib16_bus_address_l < bus_address_main_mem_top) begin
				// main memory
				ib16_bus_data_out = {ib16_bus_burst ? main_mem_dout_b : 8'b0, main_mem_dout_a};
			end else if ((ib16_bus_address_l >= bus_address_text_mem_bot) && (ib16_bus_address_l <= bus_address_text_mem_top)) begin
				// for text video memory we handle 8 and 16 bit differently
				if (!ib16_bus_burst) begin
					ib16_bus_data_out = {8'b0, text_dout_a};
				end else begin
					ib16_bus_data_out = {text_dout_a, ib16_bus_data_out_reg[7:0]};
				end
			end else begin
				// default reads (mmio) are registered
				ib16_bus_data_out = ib16_bus_data_out_reg;
			end
		end
	end

    localparam
		CYCLES_PER_TICK = ((`FREQ * 1_000_000) / 1000) * 1;					// tick every 1ms
    logic [7:0] tick_counter;
    logic [$clog2(CYCLES_PER_TICK):0] cycle_counter;
    logic [3:0] bus_cycle;
    
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
    always_ff @(posedge pllclk) begin
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
            ib16_bus_data_out_reg <= 0;
            ib16_bus_irq        <= 0;
            bus_cycle           <= 0;
            ib16_bus_enable_prev <= 0;
            gpio_out            <= 16'hFF;
            cycle_counter       <= 0;
            tick_counter		<= 0;
            uart_prev_rx_ready  <= 0;
            uart_prev_tx_fifo_empty <= 0;
            int_enable     		<= 0;
            int_pending    		<= 0;
            lrg_mode			<= 1'b0;
        end else begin
			// tick counter logic
            if (cycle_counter == (CYCLES_PER_TICK-1)) begin
				cycle_counter <= 0;
				tick_counter  <= tick_counter + 1'b1;
			end else begin
				cycle_counter <= cycle_counter + 1'b1;
			end

            // latch bus address on posedge of enable
            if (ib16_bus_enable_prev != ib16_bus_enable && ib16_bus_enable) begin
				ib16_bus_address_l <= ib16_bus_address;
			end
			ib16_bus_enable_prev <= ib16_bus_enable;
			
			int_pending <= int_pending;
			if (uart_prev_rx_ready != uart_rx_ready && uart_rx_ready) begin
				int_pending[IRQ_UART_RX_READY] <= int_enable[IRQ_UART_RX_READY];
			end
			if (uart_prev_tx_fifo_empty != uart_tx_fifo_empty && uart_tx_fifo_empty) begin
				int_pending[IRQ_UART_TX_FIFO_EMPTY] <= int_enable[IRQ_UART_TX_FIFO_EMPTY];
			end
			if (cycle_counter == (CYCLES_PER_TICK-1)) begin
				int_pending[IRQ_TIMER] <= int_enable[IRQ_TIMER];
			end
			if (vga_v_sync != vga_v_sync_prev && ~vga_v_sync) begin			// v_sync is inverted (active low)
				int_pending[IRQ_VSYNC] <= int_enable[IRQ_VSYNC];
			end
            uart_prev_rx_ready 		<= uart_rx_ready;
            uart_prev_tx_fifo_empty <= uart_tx_fifo_empty;
            ib16_bus_irq 			<= int_pending;

            // normal mode
            if (ib16_bus_enable && !ib16_bus_ready) begin
                // handle new command
                // VIDEO flags
                if (ib16_bus_address == VIDEO_MODE_FLAG_ADDR) begin
					if (ib16_bus_wr_en) begin
						lrg_mode <= ib16_bus_data_in[0];
					end else begin
						ib16_bus_data_out_reg <= {15'b0, lrg_mode};
					end
					ib16_bus_ready <= 1;
				end
                // GPIO port
                if (ib16_bus_address == GPIO0_DATA_ADDR) begin
                    if (ib16_bus_wr_en) begin
                        gpio_out[7:0] <= ib16_bus_data_in[7:0];
                    end else begin
                        ib16_bus_data_out_reg <= {8'b0, gpio_in[7:0]};
                    end
                    ib16_bus_ready <= 1;
                end
                // GPIO port
                if (ib16_bus_address == GPIO1_DATA_ADDR) begin
                    // no GPIO1 for now but I want to use ecp5 demos ...
                    ib16_bus_ready <= 1;
                end
                // Interrupt pending
                if (ib16_bus_address == UART_INT_ADDR) begin
                    if (ib16_bus_wr_en) begin
                        int_pending <= int_pending & ~ib16_bus_data_in[7:0];
                    end else begin
                        ib16_bus_data_out_reg <= {8'b0, int_pending};
                    end
                    ib16_bus_ready <= 1;
                end
                // Interrupt enable
                if (ib16_bus_address == UART_INTEN_ADDR) begin
                    if (ib16_bus_wr_en) begin
                        int_enable <= ib16_bus_data_in[7:0];
                    end else begin
                        ib16_bus_data_out_reg <= {8'b0, int_enable};
                    end
                    ib16_bus_ready <= 1;
                end
                // Timer
                if (ib16_bus_address == TIMER_ADDR) begin
					if (ib16_bus_wr_en) begin
						tick_counter  <= 0;
						cycle_counter <= 0;
					end else begin					
						ib16_bus_data_out_reg <= {8'b0, tick_counter};
					end
                    ib16_bus_ready    <= 1;
                end 

                // UART Status register
                if (ib16_bus_address == UART_STS_ADDR) begin
					if (!ib16_bus_wr_en) begin
						ib16_bus_data_out_reg <= {13'b0, uart_tx_fifo_empty, uart_tx_fifo_full, uart_rx_ready};
					end
                    ib16_bus_ready    <= 1;
                end 
                // UART data register
                if (ib16_bus_address == UART_DATA_ADDR) begin
                    if (ib16_bus_wr_en) begin
						if (bus_cycle[0] == 0) // wait for a FIFO slot
							begin
								if (!uart_tx_fifo_full) begin
									uart_tx_data_in <= ib16_bus_data_in[7:0];
									uart_tx_start   <= 1;
									bus_cycle       <= 1;
								end
							end
						if (bus_cycle[0] == 1) // deassert and go to ready
							begin
								uart_tx_start   <= 0;
								bus_cycle       <= 0;
								ib16_bus_ready  <= 1;
							end
                    end else begin
						if (bus_cycle[1:0] == 0) // wait for incoming byte
							begin
								if (uart_rx_ready) begin
									uart_rx_read    <= 1;
									bus_cycle       <= 1;
								end
							end
						if (bus_cycle[1:0] == 1) // deassert read and delay for byte
							begin
								uart_rx_read        <= 0;
								bus_cycle           <= 2;
							end
						if (bus_cycle[1:0] == 2) // store byte and go back to idle
							begin
								ib16_bus_data_out_reg   <= uart_rx_byte;
								bus_cycle           <= 0;
								ib16_bus_ready      <= 1;
							end
                    end
                end 
                // upto 2048 * BLOCKS is RAM
                if (ib16_bus_address < bus_address_main_mem_top) begin
                    // BRAM block
					if (bus_cycle[0] == 0) // start transaction (this cycle delay handles the fact that bus_address is combinatorial)
						begin
							main_mem_we_a   <= ib16_bus_wr_en;
							main_mem_we_b   <= ib16_bus_burst ? ib16_bus_wr_en : 1'b0;
							main_mem_addr_a <= ib16_bus_address[10+$clog2(`BLOCKS):0];
							main_mem_addr_b <= ib16_bus_address[10+$clog2(`BLOCKS):0] + 1'b1;
							main_mem_din_a  <= ib16_bus_data_in[7:0];
							main_mem_din_b  <= ib16_bus_data_in[15:8];
							bus_cycle       <= bus_cycle + 1'b1;
						end
					if (bus_cycle[0] == 1) // memory 2nd cycle
						begin
							bus_cycle       <= 0;
							main_mem_we_a	<= 0;
							main_mem_we_b 	<= 0;
							ib16_bus_ready  <= 1;
						end
                end

                // TEXT VIDEO memory from E800..EFFF
                if ((ib16_bus_address_l >= bus_address_text_mem_bot) && (ib16_bus_address_l <= bus_address_text_mem_top)) begin
                    // TEXT MEM  block
					if (bus_cycle[1:0] == 0) // start transaction (this cycle delay handles the fact that bus_address is combinatorial)
						begin
							text_we_a     <= ib16_bus_wr_en;
                            text_addr_a   <= ib16_bus_address[10+$clog2(`BLOCKS):0];
							text_din_a    <= ib16_bus_data_in[7:0];
							bus_cycle     <= bus_cycle + 1'b1;
						end
					if (bus_cycle[1:0] == 1) // memory 2nd cycle (we're done here if it's a 8-bit)
						begin
							if (!ib16_bus_burst) begin
								text_we_a 		<= 0;
								bus_cycle 		<= 0;
								ib16_bus_ready	<= 1;
							end else begin
								bus_cycle		<= bus_cycle + 1'b1;
								text_addr_a		<= text_addr_a + 1'b1;
								text_din_a		<= ib16_bus_data_in[15:8];
							end
						end
					if (bus_cycle[1:0] == 2) // memory 3rd cycle (done if writing, store first 8 bits if reading)
						begin
							bus_cycle           <= 0;
							ib16_bus_ready      <= 1;
							text_we_a           <= 0;
							if (~text_we_a) begin // writes are done here
								ib16_bus_data_out_reg[7:0] <= text_dout_a;
							end
						end
                end

                // F000..F0FF is the boot ROM
                if ((ib16_bus_address >= bus_address_rom_mem_bot) && (ib16_bus_address <= bus_address_rom_mem_top)) begin
                    case(ib16_bus_address[7:0])
                        8'h00: ib16_bus_data_out_reg <= 16'h0000;
                        8'h02: ib16_bus_data_out_reg <= 16'h0fff;
                        8'h04: ib16_bus_data_out_reg <= 16'h0efc;
                        8'h06: ib16_bus_data_out_reg <= 16'h01ff;
                        8'h08: ib16_bus_data_out_reg <= 16'ha1fe;
                        8'h0a: ib16_bus_data_out_reg <= 16'h0fff;
                        8'h0c: ib16_bus_data_out_reg <= 16'h0efd;
                        8'h0e: ib16_bus_data_out_reg <= 16'ha0fe;
                        8'h10: ib16_bus_data_out_reg <= 16'h0eff;
                        8'h12: ib16_bus_data_out_reg <= 16'h0fff;
                        8'h14: ib16_bus_data_out_reg <= 16'h0cfb;
                        8'h16: ib16_bus_data_out_reg <= 16'h0dff;
                        8'h18: ib16_bus_data_out_reg <= 16'h0100;
                        8'h1a: ib16_bus_data_out_reg <= 16'h045a;
                        8'h1c: ib16_bus_data_out_reg <= 16'h93fe;
                        8'h1e: ib16_bus_data_out_reg <= 16'h7134;
                        8'h20: ib16_bus_data_out_reg <= 16'hd5fd;
                        8'h22: ib16_bus_data_out_reg <= 16'h92fe;
                        8'h24: ib16_bus_data_out_reg <= 16'h93fe;
                        8'h26: ib16_bus_data_out_reg <= 16'ha3fe;
                        8'h28: ib16_bus_data_out_reg <= 16'h3534;
                        8'h2a: ib16_bus_data_out_reg <= 16'h8545;
                        8'h2c: ib16_bus_data_out_reg <= 16'h93fe;
                        8'h2e: ib16_bus_data_out_reg <= 16'ha3fe;
                        8'h30: ib16_bus_data_out_reg <= 16'h3334;
                        8'h32: ib16_bus_data_out_reg <= 16'h6335;
                        8'h34: ib16_bus_data_out_reg <= 16'ha310;
                        8'h36: ib16_bus_data_out_reg <= 16'h8050;
                        8'h38: ib16_bus_data_out_reg <= 16'hd5f5;
                        8'h3a: ib16_bus_data_out_reg <= 16'h8151;
                        8'h3c: ib16_bus_data_out_reg <= 16'h8b71;
                        8'h3e: ib16_bus_data_out_reg <= 16'habdc;
                        8'h40: ib16_bus_data_out_reg <= 16'h7112;
                        8'h42: ib16_bus_data_out_reg <= 16'hd402;
                        8'h44: ib16_bus_data_out_reg <= 16'h4000;
                        8'h46: ib16_bus_data_out_reg <= 16'he008;
                        8'h48: ib16_bus_data_out_reg <= 16'h93fe;
                        8'h4a: ib16_bus_data_out_reg <= 16'h3534;
                        8'h4c: ib16_bus_data_out_reg <= 16'h8545;
                        8'h4e: ib16_bus_data_out_reg <= 16'h93fe;
                        8'h50: ib16_bus_data_out_reg <= 16'h3334;
                        8'h52: ib16_bus_data_out_reg <= 16'h6335;
                        8'h54: ib16_bus_data_out_reg <= 16'ha310;
                        8'h56: ib16_bus_data_out_reg <= 16'h8050;
                        8'h58: ib16_bus_data_out_reg <= 16'hd5f7;
                        8'h5a: ib16_bus_data_out_reg <= 16'hd1ef;
                        default: ib16_bus_data_out_reg <= 16'h0000;
                    endcase
                    ib16_bus_ready <= 1;
                end
            end if (ib16_bus_ready && !ib16_bus_enable) begin
                ib16_bus_ready <= 0;
            end
        end
    end
endmodule 
