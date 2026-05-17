/*

    C-FLEA Top for Primer 25K

Simple memory map of 60K of RAM followed by 2K boot ROM (**only 512 bytes is pnr**), and 2K video memory

for I/O the following ports are used

   - 00h: uart data (non-blocking read => retursn FFFF is no char available on read, blocking writes)
   - 01h: gpio0
   - 02..04h: gpio1-3
   - 10h: uart status (uart_rx_ready, uart_tx_fifo_empty, uart_tx_fifo_full)
   - 11h: timer (counts 1ms ticks, writing anything to it resets to 0)
   - 12h: video mode (lsb == lrg_mode)
   
*/

`timescale 1ns/1ps
`default_nettype none

`define CF_TOP_VER 8'h01

`define BLOCKS 30
`define FREQ 90

module top(input wire clk, input wire s1,
	input wire uart_rx, output wire uart_tx, 
	inout wire [7:0] gpio,
	output reg [3:0] vga_r, output reg [3:0] vga_g, output reg   [3:0] vga_b, output wire vga_h_pulse, output wire vga_v_pulse);


    localparam
        bus_address_main_mem_top = 16'hEFFF,
		bus_address_text_mem_bot = 16'hF800,
		bus_address_text_mem_top = 16'hFFFF,
		bus_address_rom_mem_bot  = 16'hF000,
		bus_address_rom_mem_top  = 16'hF7FF;

	// Domain #1: CFLEA @`FREQ
    logic pllclk;
	
	reg [3:0] rst = 0;
    reg [1:0] reset_sw;
	wire rst_n = rst[3] & ~reset_sw[1]; // s1 is pulled up by the button so we want to pull reset low when the button is pressed
	
	always @(posedge pllclk) begin
        reset_sw = {reset_sw[0], s1 };
        rst <= {rst[2:0], 1'b1};
	end

	// Domain #2: VGA @ 25.175
    logic pll2clk;
	
	reg [3:0] rst2 = 0;
	wire rst2_n = rst2[3] & ~s1;
	
	always @(posedge pll2clk) begin
        rst2 <= {rst2[2:0], 1'b1};
	end
	
    // PLLs
    cflea_pll ms_minutes(
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

    logic uart_prev_tx_fifo_empty;
    logic uart_prev_rx_ready;

    uart #(.FIFO_DEPTH(8), .RX_ENABLE(1), .TX_ENABLE(1)) mrtalky (
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
	logic [15:0] main_mem_addr_a;
	logic [7:0] main_mem_din_a;
	logic main_mem_we_a;
	logic [7:0] main_mem_dout_a;
	
	logic [15:0] main_mem_addr_b;
	logic [7:0] main_mem_din_b;
	logic main_mem_we_b;
	logic [7:0] main_mem_dout_b;

    cflea_main_mem cflea_mem(
        .douta(main_mem_dout_a), //output [7:0] douta
        .clka(pllclk), //input clka
        .ocea(1'b1), //input ocea
        .cea(1'b1), //input cea
        .reseta(~rst_n), //input reseta
        .wrea(main_mem_we_a), //input wrea
        .ada(main_mem_addr_a), //input [15:0] ada
        .dina(main_mem_din_a), //input [7:0] dina

        .doutb(main_mem_dout_b), //output [7:0] doutb
        .clkb(pllclk), //input clkb
        .oceb(1'b1), //input oceb
        .ceb(1'b1), //input ceb
        .resetb(~rst_n), //input resetb
        .wreb(main_mem_we_b), //input wreb
        .adb(main_mem_addr_b), //input [15:0] adb
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
    text_font_rom madamme_font(
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
    logic lrg_mode_pll2;

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
	vga_text_driver #(.FONTHEIGHT(16)) textdrv(
		.clk(pll2clk), .rst_n(rst2_n),
		.x(vga_x), .y(vga_y), .active_video(vga_active), .lrg_mode(lrg_mode_pll2),
		.rd_addr(text_addr_b), .rd_data(text_dout_b),
		.symbol(text_symbol));

	// drive the RGB outputs
	always_comb begin
		vga_r = 0;
		vga_g = 0;
		vga_b = 0;
		
		if (vga_active) begin
			if (!lrg_mode) begin
				{vga_r, vga_g, vga_b} = text_out ? 12'b1111_1111_1111 : 12'b0;
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
    wire [7:0] boot_rom_out;
    reg [8:0] boot_rom_address;
    boot_rom mr_bootup(
        .dout(boot_rom_out), //output [7:0] dout
        .ad(boot_rom_address) //input [8:0] ad
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
    reg [3:0] bus_cycle;

    cf_cpu #(
        .TOP_VER(`CF_TOP_VER),
        .BOOT_VECTOR(bus_address_rom_mem_bot)) mr_thinky(
        .clk(pllclk), .rst_n(rst_n),
        .bus_address(cf_bus_address),
        .bus_wr_en(cf_bus_wr_en),
        .bus_io_flag(cf_bus_io_flag),
        .bus_burst(cf_bus_burst),
        .bus_data_in(cf_bus_data_in),
        .bus_enable(cf_bus_enable),
        .bus_ready(cf_bus_ready),
        .bus_data_out(cf_bus_data_out));

    localparam
		CYCLES_PER_TICK = ((`FREQ * 1_000_000) / 1000) * 1;					// tick every 1ms
    logic [7:0] tick_counter;
    logic [$clog2(CYCLES_PER_TICK):0] cycle_counter;

    always_ff @(posedge pll2clk) begin
        lrg_mode_pll2 <= lrg_mode;
    end

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
            bus_cycle           <= 0;
            gpio_out            <= 16'hFF;
            cf_bus_ready        <= 0;
            cf_bus_data_out     <= 0;
            tick_counter        <= 0;
            cycle_counter       <= 0;
            lrg_mode            <= 0;
        end else begin
			// tick counter logic
            if (cycle_counter == (CYCLES_PER_TICK-1)) begin
				cycle_counter <= 0;
				tick_counter  <= tick_counter + 1'b1;
			end else begin
				cycle_counter <= cycle_counter + 1'b1;
			end

            if (cf_bus_enable && !cf_bus_ready) begin
                if (cf_bus_io_flag) begin
                    // handle I/O
                    if (cf_bus_address[7:0] == 8'h00) begin // UART DATA
                        if (cf_bus_wr_en) begin // writes
                            if (bus_cycle == 0) begin
                                if (!uart_tx_fifo_full) begin
                                    uart_tx_data_in <= cf_bus_data_in[7:0];
                                    uart_tx_start <= 1'b1;
                                    bus_cycle <= 1;
                                end
                            end else if (bus_cycle == 1) begin
                                cf_bus_ready <= 1'b1;
                                uart_tx_start <= 1'b0;
                            end                            
                        end else begin // reads
                            if (bus_cycle == 0) begin
                                if (uart_rx_ready) begin
                                    uart_rx_read <= 1'b1;
                                    bus_cycle <= 1;
                                end else begin
                                    // Dave's model returns -1 if there's no char...
                                    cf_bus_ready <= 1'b1;
                                    cf_bus_data_out <= 16'hFFFF; // note this must be 16 bit since his INC/JZ/DEC test relies on FFFF rolling to 0
                                end
                            end else if (bus_cycle == 1) begin
                                uart_rx_read <= 1'b0;
                                bus_cycle <= 2;
                            end else if (bus_cycle == 2) begin
                                cf_bus_ready <= 1'b1;
                                cf_bus_data_out <= { 8'h00, uart_rx_byte };
                            end
                        end
                    end else if (cf_bus_address[7:0] == 8'h10) begin // uart status
                        if (cf_bus_wr_en) begin
                        end else begin
                            cf_bus_data_out <= { 8'h00, 5'b0, uart_rx_ready, uart_tx_fifo_empty, uart_tx_fifo_full };
                        end
                        cf_bus_ready <= 1'b1;
                    end else if (cf_bus_address[7:0] == 8'h11) begin // timer 1ms tick
                        if (cf_bus_wr_en) begin
                            tick_counter <= 0;
                        end else begin
                            cf_bus_data_out <= { 8'h00, tick_counter };
                        end
                        cf_bus_ready <= 1'b1;
                    end else if (cf_bus_address[7:0] == 8'h12) begin // video flags 
                        if (cf_bus_wr_en) begin
                            lrg_mode <= cf_bus_data_in[0];
                        end else begin
                            cf_bus_data_out <= {15'b0, lrg_mode};
                        end
                    end else if (cf_bus_address[7:0] == 8'h01) begin // GPIO0
                        if (cf_bus_wr_en) begin
                            gpio_out <= cf_bus_data_in[7:0];
                        end else begin
                            cf_bus_data_out <= { 8'h00, gpio_in };
                        end
                        cf_bus_ready <= 1'b1;
                    end else begin
                        // default to just ack the bus
                        cf_bus_ready <= 1'b1;
                    end
                end else begin
                    // handle memory (we fold 128K to 64K)
                    if (cf_bus_address[15:0] <= bus_address_main_mem_top) begin
                        // main mem
                        if (bus_cycle == 0) begin
                            main_mem_addr_a <= cf_bus_address[15:0];
                            main_mem_addr_b <= cf_bus_address[15:0] + 1'b1;
                            main_mem_din_a <= cf_bus_data_in[7:0];
                            main_mem_din_b <= cf_bus_data_in[15:8];
                            main_mem_we_a  <= cf_bus_wr_en;
                            main_mem_we_b  <= cf_bus_burst ? cf_bus_wr_en : 1'b0;
                            bus_cycle <= 1;
                        end else if (bus_cycle == 1) begin
                            main_mem_we_a <= 1'b0;
                            main_mem_we_b <= 1'b0;
                            if (cf_bus_wr_en) begin
                                cf_bus_ready <= 1;
                            end else begin
                                bus_cycle <= 2;
                            end
                        end else if (bus_cycle == 2) begin
                            cf_bus_ready <= 1;
                            cf_bus_data_out = { cf_bus_burst ? main_mem_dout_b : 8'b00, main_mem_dout_a };
                        end
                    end else if (cf_bus_address[15:0] <= bus_address_rom_mem_top) begin
                        // rom memory
                        if (cf_bus_wr_en) begin
                            cf_bus_ready <= 1'b1;
                        end else begin
                            if (bus_cycle == 0) begin
                                boot_rom_address <= cf_bus_address[8:0];
                                bus_cycle <= 1;
                            end else if (bus_cycle == 1) begin
                                cf_bus_data_out   <= {8'h00, boot_rom_out};
                                boot_rom_address  <= boot_rom_address + 1'b1;
                                if (cf_bus_burst) begin
                                    bus_cycle <= 2;
                                end else begin
                                    cf_bus_ready <= 1'b1;
                                end
                            end else if (bus_cycle == 2) begin
                                cf_bus_data_out[15:8] <= boot_rom_out;
                                cf_bus_ready <= 1'b1;
                            end
                        end
                    end else if (cf_bus_address[15:0] <= bus_address_text_mem_top) begin
                        // video memory
                        if (bus_cycle == 0) begin
                            bus_cycle <= 1;
                            text_addr_a <= cf_bus_address[10:0];
                            text_din_a  <= cf_bus_data_in[7:0];
                            text_we_a   <= cf_bus_wr_en;
                        end else if (bus_cycle == 1) begin
                            bus_cycle <= 2;
                            text_addr_a <= text_addr_a + 1'b1;
                            text_din_a  <= cf_bus_data_in[15:8];
                            if (!cf_bus_burst && cf_bus_wr_en) begin
                                text_we_a <= 1'b0;
                                cf_bus_ready <= 1'b1;
                            end
                        end else if (bus_cycle == 2) begin
                            text_we_a <= 1'b0;
                            bus_cycle <= 3;
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
