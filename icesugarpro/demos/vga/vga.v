`default_nettype none
module top(
	input wire clk,
	output reg [1:0] vga_r,
	output reg [1:0] vga_g,
	output reg [1:0] vga_b,
	output reg  vga_v_pulse,
	output reg  vga_h_pulse
);

	wire host_clk;
	wire vga_clk;

	pll1 hostpll (.clkin(clk), .clkout0(host_clk));
	pll2 vgapll  (.clkin(clk), .clkout0(vga_clk));
	
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
		.vga_clk(vga_clk), .host_clk(host_clk), .rst_n(rst_n),
		.video_mode(video_mode),
		.host_addr(host_addr), .host_data_in(host_data_in), .host_data_out(host_data_out), .host_write_mask(host_write_mask),
		.vga_r(vga_out_r), .vga_g(vga_out_g), .vga_b(vga_out_b), .vga_v_pulse(vga_out_v_pulse), .vga_h_pulse(vga_out_h_pulse));

	// register the VGA signals so there's less jitter on the display
	always @(posedge vga_clk) begin
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
	
	reg [6:0] cnt;
    reg [26:0] demo_counter;
	always @(posedge host_clk) begin
		if (!rst_n) begin
			host_write_mask <= 4'b1111;
			host_addr       <= -4;
			host_data_in    <= 32'hFFE01C03;
			//host_data_in    <= 32'h44434241;
			video_mode      <= 1'b1;
			rst_n           <= 1'b1;
			cnt             <= 0;
            demo_counter    <= 0;
		end else begin
            demo_counter    <= demo_counter + 1;
            if (demo_counter == 75_000_000) begin
                demo_counter <= 0;
                video_mode   <= ~video_mode;
                host_addr    <= -4;
                host_write_mask <= 4'b1111;
                cnt          <= 0;
                if (video_mode) begin
                    // moving to text mode
                    host_data_in    <= 32'hC642F941; // regular white on bright blue A and bright red on regular yellow B
                end else begin
                    // moving to graphical mode
                    host_data_in    <= 32'hFFE01C03;
                end
            end else begin
                host_addr       <= host_addr + 16'd4;
                cnt             <= cnt + 1;
                if (video_mode) begin
                    if (cnt == 79) begin
                        cnt <= 0;
                    end
                    if (host_addr == (320 * 200) - 4) begin
                        host_write_mask <= 4'b0000;
                    end
                    if (cnt == 0) begin
                        host_data_in <= {host_data_in[23:0], host_data_in[31:24]};
                    end
                end else begin
                    if (cnt == 39) begin
                        cnt <= 0;
                    end
                    if (host_addr == (80*25*2) - 4) begin
                        host_write_mask <= 4'b0000;
                    end
                    if (cnt == 0) begin
                        host_data_in <= {host_data_in[15:0], host_data_in[31:16]};
                    end
                end
            end
		end
	end
endmodule
