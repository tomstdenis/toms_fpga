`default_nettype none

// All-in-one VGA module provides 80x25 text mode, and 320x200 8bpp mode (332)
// along with a 64KB memory which has a host access port suitable for a 32-bit
// bus.  Supports dual clock domains.  Memory is registered on the host side.
//
// For the 80x25 this module includes a 8x8 CP437 IBM PC font.  The module should
// infer one 18Kbit BRAM (ROM) for the font, and 32 18Kbit BRAMS (dual ported) for the 
// video memory.
//
// The video_mode net controls which is enabled, (0) for text mode and (1) for 320x200 mode.
// There's no "palette" like in a conventional VGA driver and we simply use a 332 palette 
// made up of rrrgggbb from the msb down for video and IRGBirgb (foreground then background) for
// text mode.  In text mode the symbol comes first then the colour.  The entire screen takes
// 80 * 25 * 2 == 4000 bytes.
//
// The underlying signal is a 640x480 timing signal.  In text mode we use a 8x16 font spacing
// (with the 8x8 font) to make up the 80x25 display which occupies 640x400 region of the display.  The
// 320x200 mode uses pixel dubbling occupying the same 640x400 region of the display.  Because it doesn't
// stretch the vertical the pixels are still square.
//
// Requires fontrom.vh for the CP437 font make sure you include that in your project.

module vga
(
	input wire vga_clk,                         // VGA dot clock (should be 25.170MHz)
	input wire host_clk,                        // Host clock
	input wire rst_n,
	
	input wire         video_mode,              // 0 == 80x25 text mode, 1 == 320x200 322 colour mode
	
	// host access to VGA 64KB memory (little endian)
	input wire [15:0]  host_addr,				// address must be dword aligned
	input wire [31:0]  host_data_in,			// data to write if any from LSB up
	input wire [3:0]   host_write_mask,			// write mask 
	output reg [31:0]  host_data_out,			// data read from this address
	
	// VGA output
	output reg [3:0]   vga_r,
	output reg [3:0]   vga_g,
	output reg [3:0]   vga_b,
	output reg         vga_v_pulse,
	output reg         vga_h_pulse,

    // VGA timing
    output wire        vga_v_blank,
    output wire        vga_h_blank
);
	// these parameters aren't really changeable...(they're just to make the code more legible)
    // Horizontal constants
    localparam H_VISIBLE    = 640;
    localparam H_FRONT      = 16;
    localparam H_SYNC       = 96;
    localparam H_BACK       = 48;
    localparam H_TOTAL      = 800;

    // Vertical constants
    localparam V_VISIBLE    = 480;
    localparam V_FRONT      = 10;
    localparam V_SYNC       = 2;
    localparam V_BACK       = 33;
    localparam V_TOTAL      = 525;
    
	// text mode parameter
	localparam TEXTCOLS   = 80;					// number of text columns
	localparam TEXTROWS   = 25;					// number of text rows
	localparam FONTWIDTH  = 8;					// font width in pixels
	localparam FONTHEIGHT = 16;					// font height in pixels (doubled, we're using an 8x8 font)
	
	// memory config
	localparam X_FETCH_DELAY = 2;

	// VGA timing
    reg [9:0]   vga_x;
    reg [9:0]   vga_y;
    wire        active_video;
    reg         prev_mode;

    assign vga_v_blank = (vga_y >= V_VISIBLE);
    assign vga_h_blank = (vga_x >= H_VISIBLE);

    // Active video flag
    assign active_video = (vga_x < H_VISIBLE) && (vga_y < V_VISIBLE);

    reg [1:0]   video_mode_l;
    always @(posedge vga_clk) begin
        video_mode_l <= {video_mode_l[0], video_mode};
    end
    
    always @(posedge vga_clk) begin
        if (!rst_n) begin
            vga_x       <= 0;
            vga_y       <= 0;
            vga_h_pulse <= 1;
            vga_v_pulse <= 1;
        end else begin
            // X and Y Counter Logic
            vga_x <= vga_x + 1'b1;
            if (vga_x == (H_TOTAL - 1)) begin
                vga_x <= 0;
                vga_y <= vga_y + 1'b1;
                if (vga_y == (V_TOTAL - 1)) begin
                    vga_y <= 0;
                end
            end

            // Horizontal Sync
            vga_h_pulse <= ~((vga_x >= (H_VISIBLE + H_FRONT)) && (vga_x < (H_VISIBLE + H_FRONT + H_SYNC)));

            // Vertical Sync
            vga_v_pulse <= ~((vga_y >= (V_VISIBLE + V_FRONT)) && (vga_y < (V_VISIBLE + V_FRONT + V_SYNC)));
        end
    end
    
    // font memory
    wire [10:0] font_addr;
    reg [7:0]   font_dout;
    reg [7:0]   font_rom[0:2047];
`include "fontrom.vh"
    always @(posedge vga_clk) begin
		font_dout <= font_rom[font_addr];
	end

	// font bit generator
    wire [9:0] vga_y_p1 = (vga_y + (vga_x == (H_TOTAL-1) ? 1'b1 : 1'b0));
    wire   text_out;
    assign font_addr = {vga_symbol[7:0], vga_y_p1[3:1]};     // address into the rom, it's 11 bits of which the top 8 are the symbol and bottom 3 are the row
    assign text_out  = font_dout[7 - vga_x[2:0]];            // bit of output indexed from the ROM output

	// vga memory organized as four lanes of 16KB
	// we present to the host using a 32-bit friendly map using registered outputs
	// and to the VGA we present a 64KB lane that is bypassed
	(* ram_style = "block" *)
	reg [7:0] vga_mem_lane0[0:16383];
	(* ram_style = "block" *)
	reg [7:0] vga_mem_lane1[0:16383];
	(* ram_style = "block" *)
	reg [7:0] vga_mem_lane2[0:16383];
	(* ram_style = "block" *)
	reg [7:0] vga_mem_lane3[0:16383];
	reg [7:0] vga_mem_lane0_tmp;
	reg [7:0] vga_mem_lane1_tmp;
	reg [7:0] vga_mem_lane2_tmp;
	reg [7:0] vga_mem_lane3_tmp;
	
	// host memory access
	always @(posedge host_clk) begin
		if (host_write_mask[0]) begin
			vga_mem_lane0[host_addr[15:2]] <= host_data_in[7:0];
		end
		if (host_write_mask[1]) begin
			vga_mem_lane1[host_addr[15:2]] <= host_data_in[15:8];
		end
		if (host_write_mask[2]) begin
			vga_mem_lane2[host_addr[15:2]] <= host_data_in[23:16];
		end
		if (host_write_mask[3]) begin
			vga_mem_lane3[host_addr[15:2]] <= host_data_in[31:24];
		end
		vga_mem_lane0_tmp <= vga_mem_lane0[host_addr[15:2]];         // registered outputs make routing sooo much faster
		vga_mem_lane1_tmp <= vga_mem_lane1[host_addr[15:2]];
		vga_mem_lane2_tmp <= vga_mem_lane2[host_addr[15:2]];
		vga_mem_lane3_tmp <= vga_mem_lane3[host_addr[15:2]];
		host_data_out[7:0]   <= vga_mem_lane0_tmp;
		host_data_out[15:8]  <= vga_mem_lane1_tmp;
		host_data_out[23:16] <= vga_mem_lane2_tmp;
		host_data_out[31:24] <= vga_mem_lane3_tmp;
	end
	
	// VGA driver memory interface
	reg [15:0] vga_mem_addr;			// the address this module is reading from
	reg [1:0]  vga_mem_addr_lane;
	reg [15:0] vga_symbol;
	reg [15:0] vga_data_out;
	reg [7:0] vga_disp_lane0_tmp;
	reg [7:0] vga_disp_lane1_tmp;
	reg [7:0] vga_disp_lane2_tmp;
	reg [7:0] vga_disp_lane3_tmp;
	always @(posedge vga_clk) begin
		// note you can't assign lane output to the same reg and infer a BRAM
		// so we copy out all of the lanes here 
		vga_disp_lane0_tmp <= vga_mem_lane0[vga_mem_addr[15:2]];
		vga_disp_lane1_tmp <= vga_mem_lane1[vga_mem_addr[15:2]];
		vga_disp_lane2_tmp <= vga_mem_lane2[vga_mem_addr[15:2]];
		vga_disp_lane3_tmp <= vga_mem_lane3[vga_mem_addr[15:2]];
		// and register the lane selector
		vga_mem_addr_lane  <= vga_mem_addr[1:0];
	end
	// and then drive the data out based on the lane selector
	always @(*) begin
		case (vga_mem_addr_lane)
			2'b00: vga_data_out = {vga_disp_lane1_tmp, vga_disp_lane0_tmp };
			2'b01: vga_data_out = {vga_disp_lane2_tmp, vga_disp_lane1_tmp };
			2'b10: vga_data_out = {vga_disp_lane3_tmp, vga_disp_lane2_tmp };
			2'b11: vga_data_out = {vga_disp_lane0_tmp, vga_disp_lane3_tmp };
		endcase
	end	

	// FSM's for the text and video modes.
	reg [3:0] x_cnt;
	reg [3:0] y_cnt;

	always @(posedge vga_clk) begin
		if (!rst_n || prev_mode != video_mode_l[1]) begin
			vga_mem_addr <= 0;
			x_cnt        <= 0;
			y_cnt        <= 0;
            prev_mode    <= video_mode_l[1];
		end else if (video_mode_l[0] == 0) begin
			// text mode 80x25 (double height fonts...)
			if (vga_y < (TEXTROWS*FONTHEIGHT) && vga_x < (TEXTCOLS*FONTWIDTH)) begin
                x_cnt <= x_cnt + 1'b1;
                if (x_cnt == (FONTWIDTH-1)) begin
                    x_cnt   <= 1'b0;
                end
				if (vga_x[$clog2(FONTWIDTH)-1:0] == (FONTWIDTH-2-X_FETCH_DELAY)) begin
					vga_mem_addr <= vga_mem_addr + 2;
				end
				// Latch symbol at the last column of font
				if (vga_x[$clog2(FONTWIDTH)-1:0] == (FONTWIDTH-X_FETCH_DELAY)) begin
					vga_symbol <= vga_data_out;
				end
			end else begin
                // we're either just entering HBLANK or VBLANK
                x_cnt <= 1'b0;
                // need to set address with enough time to wait 1 cycle then read symbol
                // but font then needs a cycle after that
				if (vga_x == (H_TOTAL-X_FETCH_DELAY-X_FETCH_DELAY)) begin
					// set the next address for the next scanline which is either
                    // another line of the same text char row or the first row of the next row of text...
					if (vga_y >= ((TEXTROWS*FONTHEIGHT)-1)) begin
						vga_mem_addr <= 0;                                              // we're beyond the last row so start at 0
					end else begin
						if (vga_y[$clog2(FONTHEIGHT)-1:0] == (FONTHEIGHT-1)) begin      // next row of chars
							vga_mem_addr <= vga_mem_addr;
						end else begin
							vga_mem_addr <= vga_mem_addr - (TEXTCOLS*2);                // next font row of same text row
						end
					end
				end else if (vga_x == (H_TOTAL-X_FETCH_DELAY)) begin
                    y_cnt <= y_cnt + 1'b1;
                    if ((y_cnt == (FONTHEIGHT-1)) || (vga_y == (V_TOTAL-1))) begin
                        y_cnt <= 1'b0;
                    end
                    if (vga_y < (TEXTROWS*FONTHEIGHT-1) || vga_y == (V_TOTAL-1)) begin      // either we're in the first TEXTROWS OR the last line preparing for row 0
                        vga_symbol <= vga_data_out;
                    end else begin
                        vga_symbol <= 16'h20; // SPC
                    end
				end
			end
		end else begin
			// 320x200 video mode, note we're doubled in both directions
			if (vga_x < 640 && vga_y < 400) begin
				// in region
				vga_symbol   <= vga_data_out;
				if (~vga_x[0]) begin
					vga_mem_addr <= vga_mem_addr + 1'b1;
				end
			end else begin
				// out of region (either H or V blank)
				vga_symbol <= 0;
				if (vga_y < 400) begin
					// H blank either duplicate line or next
					if ((vga_x == H_TOTAL - X_FETCH_DELAY - 1)) begin
						// only execute once per HBLANK
						if (vga_y[0]) begin
							// last line in the pair so we just advance
							vga_mem_addr <= vga_mem_addr;
						end else begin
							vga_mem_addr <= vga_mem_addr - 16'd320;		// go back 320 pixels
						end
					end
				end else begin
					// V blank region
					vga_mem_addr <= 0;
				end
			end
		end
	end

	// drive RGB pins
	always @(*) begin
		{vga_r, vga_g, vga_b} = 12'b0;
		if (active_video) begin
			if (video_mode_l[0] == 0) begin
				// text mode uses upper 8 bits of vga_symbol as colour in the form of IRGBirgb foreground then background
				if (text_out) begin
					{vga_r, vga_g, vga_b} = { 
                        vga_symbol[14], vga_symbol[15] & vga_symbol[14], vga_symbol[15] & vga_symbol[14], vga_symbol[15] & vga_symbol[14],
                        vga_symbol[13], vga_symbol[15] & vga_symbol[13], vga_symbol[15] & vga_symbol[13], vga_symbol[15] & vga_symbol[13], 
                        vga_symbol[12], vga_symbol[15] & vga_symbol[12], vga_symbol[15] & vga_symbol[12], vga_symbol[15] & vga_symbol[12] };
				end else begin
                    // background
					{vga_r, vga_g, vga_b} = { 
                        vga_symbol[10], vga_symbol[11] & vga_symbol[10], vga_symbol[11] & vga_symbol[10], vga_symbol[11] & vga_symbol[10], 
                        vga_symbol[9], vga_symbol[11] & vga_symbol[9], vga_symbol[11] & vga_symbol[9], vga_symbol[11] & vga_symbol[9], 
                        vga_symbol[8], vga_symbol[11] & vga_symbol[8], vga_symbol[11] & vga_symbol[8], vga_symbol[11] & vga_symbol[8] };
                end
			end else begin
				// 332 colour mode
				{vga_r, vga_g, vga_b} = {
											vga_symbol[7:5], &vga_symbol[7:5],                  // red is 3-bits
											vga_symbol[4:2], &vga_symbol[4:2],                  // green is 3-bits
											vga_symbol[1:0], |vga_symbol[1:0], &vga_symbol[1:0] // blue is 2-bits
										};
			end
		end
	end
endmodule	
