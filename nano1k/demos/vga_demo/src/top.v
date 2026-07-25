module top(input wire clk, output reg [7:0] gpio, output reg [3:0] vga_r, output reg [3:0] vga_g, output reg [3:0] vga_b, output wire  vga_h_pulse, output wire vga_v_pulse);
    reg [3:0] rstcnt = 4'b0000;
    wire rst_n;
    assign rst_n = rstcnt[3];

    // dropped the PLL for this demo since it native runs at 27MHz and the PLL can't target 25MHz anyways...
    wire pll_clk = clk;
	wire pll_locked = 1'b1;

    always @(posedge pll_clk) begin
		if (pll_locked) begin
			rstcnt <= {rstcnt[2:0], 1'b1};
		end
    end

	// bit widths are for 640x480 VGA
	wire [10:0] vga_x;
	wire [9:0] vga_y;
	wire vga_h_sync;
	wire vga_v_sync;
	wire vga_active;
	
	assign vga_h_pulse = vga_h_sync;
	assign vga_v_pulse = vga_v_sync;

	// this module produces the VGA timing signals other modules depend on
	vga_timing vga(
		.clk(pll_clk),
		.rst_n(rst_n),
		.x(vga_x),
		.y(vga_y),
		.h_sync(vga_h_sync),
		.v_sync(vga_v_sync),
		.active_video(vga_active));

	wire [15:0] symbol;
	wire text_out;
	
/*
	// font rom (note we scale y by 2 to fit the 80x25 chars onto 640x480 a bit nicer)
	// this module takes in the symbol value and x/y pixel position relative to the top left corner of the symbol
	vga_8x8_font_256 font(.symbol(symbol), .x(vga_x[2:0]), .y(vga_y[3:1]), .out(text_out));	
*/

    // here we're using a BRAM in rom mode ...
    wire [7:0] font_dout;                            // output of rom
    wire [10:0] font_ad = {symbol[7:0], vga_y[3:1]}; // address into the rom, it's 11 bits of which the top 8 are the symbol and bottom 3 are the row
    assign text_out = font_dout[7 - vga_x[2:0]];     // bit of output indexed from the ROM output

    // our 256 symbol 8x8 CP437 font
    Gowin_pROM madamme_font(
        .dout(font_dout), //output [7:0] dout
        .ad(font_ad), //input [10:0] ad
        .clk(pll_clk), //input clk
        .oce(1'b1), //input oce
        .ce(1'b1) //input ce
    );

	reg [10:0] wr_addr;			// our write port to fill it
	reg [15:0] wr_data;
	reg wr_en;
	
	wire [10:0] rd_addr;		// the read port the vga_text_driver reads from
	wire [15:0] rd_data;
	
    // A semi dual ported memory which we can write(portA) and the VGA can read(portB)
    Gowin_SDPB mr_memory(
        .dout(rd_data), //output [7:0] dout
        .clka(pll_clk), //input clka
        .cea(wr_en), //input cea                    // write enable is clock enable A (cea)
        .clkb(pll_clk), //input clkb
        .ceb(1'b1), //input ceb
        .oce(1'b1), //input oce // (leave this as 1 if not pipelining)
//        .reset(~rst_n), //input reset
        .ada(wr_addr), //input [10:0] ada
        .din(wr_data), //input [7:0] din
        .adb(rd_addr) //input [10:0] adb
    );

	// VGA text mode driver, defaults to 80x25 using an 8x8 font
	// notice we're scaling the font by 2 so we change the height to 16 here
	vga_text_driver #(.FONTHEIGHT(16), .X_FETCH_DELAY(2), .SYMBOL_BITS(16)) textdrv(
		.clk(pll_clk), .rst_n(rst_n),
		.x(vga_x), .y(vga_y), .active_video(vga_active),
		.rd_addr(rd_addr), .rd_data(rd_data),
		.symbol(symbol), .lrg_mode(1'b0));

	// So the pipe is vga() produces the timing that
	// textdrv() uses produces the next 'symbol' that
	// font() uses to produce the next black/white signal fed to the VGA RGB output
	
	reg [31:0] counter;
    wire [7:0] colour;
    assign colour = counter[31:24] + wr_addr[7:0];          // use colours for characters
	always @(posedge pll_clk) begin
		if (!rst_n) begin
			wr_addr <= -1;
			wr_data <= 0;
			wr_en   <= 1;
            counter <= 0;
		end else begin
			counter <= counter + 1;
			// advance to next address
			wr_addr <= counter[10:0];
			wr_data <= 8'h20; // default space
			if (wr_addr == 2000) begin
				// we hit the end of the text buffer turn writes off
//				wr_en <= 0;
			end
			
			// what value to write in the next cycle
			case (wr_addr + 1)				
				// first row (start on row 6/col 6)
				80*5 + 5: wr_data <= 16'hFF54; // T			//80 * 5 + 5 is TEXTCOLS * vga_y/FONTHEIGHT + vga_x/FONTWIDTH
				80*5 + 6: wr_data <= 16'hFF6F; // o
				80*5 + 7: wr_data <= 16'hFF6d; // m
				// space
				80*5 + 9: wr_data <= 16'hFF77; // w
				80*5 + 10: wr_data <= 16'hFF61; // a
				80*5 + 11: wr_data <= 16'hFF73; // s
				// space
				80*5 + 13: wr_data <= 16'hFF68; // h
				80*5 + 14: wr_data <= 16'hFF65; // e
				80*5 + 15: wr_data <= 16'hFF72; // r
				80*5 + 16: wr_data <= 16'hFF65; // e
                default: 
                    begin
                        wr_data[15:8] <= colour * (colour + colour + 1); // rc6 permutation polynomial because why not
                        wr_data[7:0]  <= wr_addr[7:0] + counter[31:24];
                    end
			endcase
		end
	end
	
    wire [2:0] text_r;
    wire [2:0] text_g;
    wire [1:0] text_b;
    reg [3:0] text_r_out;
    reg [3:0] text_g_out;
    reg [3:0] text_b_out;

    assign text_r = symbol[15:13];
    assign text_g = symbol[12:10];
    assign text_b = symbol[9:8];
    always @(posedge pll_clk) begin
        text_r_out <= text_r * 2;
        text_g_out <= text_g * 2;
        text_b_out <= text_b * 5;
    end

	always @(*) begin
		vga_r = 0;
		vga_g = 0;
		vga_b = 0;
		
		if (vga_active) begin
            {vga_r, vga_g, vga_b} = text_out ? {text_r_out, text_g_out, text_b_out} : 12'b0;
//			{vga_r, vga_g, vga_b} = text_out ? 12'b1111_1111_1111 : 12'b0;
//			{vga_r, vga_g, vga_b} = text_out ? 12'b0011_0011_0011 : 12'b0;
//			{vga_r, vga_g, vga_b} = text_out ? 12'b1111_0000_0000 : 12'b0;
//			{vga_r, vga_g, vga_b} = text_out ? 12'b0000_1111_0000 : 12'b0;
//			{vga_r, vga_g, vga_b} = text_out ? 12'b0000_0000_1111 : 12'b0;
		end
	end

endmodule