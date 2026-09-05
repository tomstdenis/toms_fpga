`default_nettype none

module top(
	input wire clk,
	output reg [1:0] vga_r,
	output reg [1:0] vga_g,
	output reg [1:0] vga_b,
	output reg  vga_v_pulse,
	output reg  vga_h_pulse
);
	reg         video_mode;
	reg [15:0]  host_addr;
	reg [31:0]  host_data_in;
	wire [31:0] host_data_out;
	reg [3:0]   host_write_mask;
	wire [3:0]  vga_out_r;
	wire [3:0]  vga_out_g;
	wire [3:0]  vga_out_b;
	wire        vga_out_v_pulse;
	wire        vga_out_h_pulse;
	
	vga myvga(
		.vga_clk(clk), .host_clk(clk), .rst_n(rst_n),
		.video_mode(video_mode),
		.host_addr(host_addr), .host_data_in(host_data_in), .host_data_out(host_data_out), .host_write_mask(host_write_mask),
		.vga_r(vga_out_r), .vga_g(vga_out_g), .vga_b(vga_out_b), .vga_v_pulse(vga_out_v_pulse), .vga_h_pulse(vga_out_h_pulse));

	always @(posedge clk) begin
		vga_r       <= vga_out_r[3:2];
		vga_g       <= vga_out_g[3:2];
		vga_b       <= vga_out_b[3:2];
		vga_v_pulse <= vga_out_v_pulse;
		vga_h_pulse <= vga_out_h_pulse;
	end
	
	reg rst_n;
	initial begin
		rst_n = 1'b0;
	end
	
	always @(posedge clk) begin
		if (!rst_n) begin
			host_write_mask <= 4'b1111;
			host_addr       <= 0;
			host_data_in    <= 32'h44434241;
			video_mode      <= 1'b0;
			rst_n           <= 1'b1;
		end else begin
			host_data_in    <= {host_data_in[23:0], host_data_in[31:24]};
			host_addr       <= host_addr + 16'd4;
		end
	end
endmodule

// simple vga module
module vga
#(
	// these parameters aren't really changeable...
	
    // Horizontal constants
    parameter H_VISIBLE    = 640,
    parameter H_FRONT      = 16,
    parameter H_SYNC       = 96,
    parameter H_BACK       = 48,
    parameter H_TOTAL      = 800,

    // Vertical constants
    parameter V_VISIBLE    = 480,
    parameter V_FRONT      = 10,
    parameter V_SYNC       = 2,
    parameter V_BACK       = 33,
    parameter V_TOTAL      = 525,
    
	// text mode parameter
	parameter TEXTCOLS   = 80,					// number of text columns
	parameter TEXTROWS   = 25,					// number of text rows
	parameter FONTWIDTH  = 8,					// font width in pixels
	parameter FONTHEIGHT = 16,					// font height in pixels (doubled, we're using an 8x8 font)
	
	// memory config
	parameter X_FETCH_DELAY = 2
)
(
	input wire vga_clk,
	input wire host_clk,
	input wire rst_n,
	
	input wire         video_mode,              // 0 == 80x25 text mode, 1 == 320x200 322 colour mode
	
	// host access to VGA memory
	input wire [15:0]  host_addr,				// address must be dword aligned
	input wire [31:0]  host_data_in,			// data to write if any from LSB up
	input wire [3:0]   host_write_mask,			// write mask 
	output reg [31:0]  host_data_out,			// data read from this address
	
	// VGA output
	output reg [3:0]   vga_r,
	output reg [3:0]   vga_g,
	output reg [3:0]   vga_b,
	output reg         vga_v_pulse,
	output reg         vga_h_pulse
);
	// VGA timing
    reg [9:0]   vga_x;
    reg [9:0]   vga_y;
    wire        active_video;

    // Active video flag
    assign active_video = (vga_x < H_VISIBLE) && (vga_y < V_VISIBLE);
    
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
	reg [7:0] vga_mem_lane0[0:16383];
	reg [7:0] vga_mem_lane1[0:16383];
	reg [7:0] vga_mem_lane2[0:16383];
	reg [7:0] vga_mem_lane3[0:16383];
	reg [7:0] vga_mem_lane0_tmp;
	reg [7:0] vga_mem_lane1_tmp;
	reg [7:0] vga_mem_lane2_tmp;
	reg [7:0] vga_mem_lane3_tmp;
	
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
		vga_mem_lane0_tmp <= vga_mem_lane0[host_addr[15:2]];
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
	reg [7:0] vga_symbol;
	wire [7:0] vga_data_out;
	reg [7:0] vga_disp_lane0_tmp;
	reg [7:0] vga_disp_lane1_tmp;
	reg [7:0] vga_disp_lane2_tmp;
	reg [7:0] vga_disp_lane3_tmp;
	always @(posedge vga_clk) begin
		// note you can't assign lane output to the same reg and infer a BRAM
		vga_disp_lane0_tmp <= vga_mem_lane0[vga_mem_addr[15:2]];
		vga_disp_lane1_tmp <= vga_mem_lane1[vga_mem_addr[15:2]];
		vga_disp_lane2_tmp <= vga_mem_lane2[vga_mem_addr[15:2]];
		vga_disp_lane3_tmp <= vga_mem_lane3[vga_mem_addr[15:2]];
		vga_mem_addr_lane  <= vga_mem_addr[1:0];
	end
	always @(*) begin
		case (vga_mem_addr_lane)
			2'b00: vga_data_out = vga_disp_lane0_tmp;
			2'b01: vga_data_out = vga_disp_lane1_tmp;
			2'b10: vga_data_out = vga_disp_lane2_tmp;
			2'b11: vga_data_out = vga_disp_lane3_tmp;
		endcase
	end	

	reg [3:0] x_cnt;
	reg [3:0] y_cnt;

	always @(posedge vga_clk) begin
		if (!rst_n) begin
			vga_mem_addr <= 0;
			x_cnt        <= 0;
			y_cnt        <= 0;
		end else if (video_mode == 0) begin
			// text mode (double height fonts...)
			if (vga_y < (TEXTROWS*FONTHEIGHT) && vga_x < (TEXTCOLS*FONTWIDTH)) begin
                x_cnt <= x_cnt + 1'b1;
                if (x_cnt == (FONTWIDTH-1)) begin
                    x_cnt   <= 1'b0;
                end
				if (vga_x[$clog2(FONTWIDTH)-1:0] == (FONTWIDTH-2-X_FETCH_DELAY)) begin
					vga_mem_addr <= vga_mem_addr + 1'b1;
				end
				// Latch symbol at the last column of font
				if (vga_x[$clog2(FONTWIDTH)-1:0] == (FONTWIDTH-X_FETCH_DELAY)) begin
					vga_symbol <= vga_data_out;
				end
			end else begin
                // we're either just entering HBLANK or VBLANK
                x_cnt <= 1'b0;
				if (vga_x == (H_TOTAL-3-X_FETCH_DELAY)) begin
					// set the next address for the next scanline which is either
                    // another line of the same text char row or the first row of the next row of text...
					if (vga_y >= ((TEXTROWS*FONTHEIGHT)-1)) begin
						vga_mem_addr <= 0;                                              // we're beyond the last row so start at 0
					end else begin
						if (vga_y[$clog2(FONTHEIGHT)-1:0] == (FONTHEIGHT-1)) begin      // next row of chars
							vga_mem_addr <= vga_mem_addr;
						end else begin
							vga_mem_addr <= vga_mem_addr - TEXTCOLS;                    // next font row of same text row
						end
					end
				end else if (vga_x == (H_TOTAL-1)) begin
                    y_cnt <= y_cnt + 1'b1;
                    if ((y_cnt == (FONTHEIGHT-1)) || (vga_y == (V_TOTAL-1))) begin
                        y_cnt <= 1'b0;
                    end
                    if (vga_y < (TEXTROWS*FONTHEIGHT-1) || vga_y == (V_TOTAL-1)) begin      // either we're in the first TEXTROWS OR the last line preparing for row 0
                        vga_symbol <= vga_data_out;
                    end else begin
                        vga_symbol <= 8'h20; // SPC
                    end
				end
			end
		end else begin
			// 320x200 video mode
		end
	end

	// drive RGB pins
	always @(*) begin
		{vga_r, vga_g, vga_b} = 12'b0;
		if (active_video) begin
			if (video_mode == 0) begin
				// text mode
				if (text_out) begin
					{vga_r, vga_g, vga_b} = {4'b1111, 4'b1111, 4'b1111};
				end
			end else begin
				// 320x200 322 mode
			end
		end
	end
endmodule	
