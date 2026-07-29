`default_nettype none
module top(input wire clk, input wire uart_rx, output wire uart_tx, output reg [3:0] vga_r, output reg [3:0] vga_g, output reg [3:0] vga_b, output wire  vga_h_pulse, output wire vga_v_pulse);
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

    reg uart_tx_start;
    reg [7:0] uart_tx_data_in;
    wire uart_tx_fifo_empty;
    wire uart_tx_fifo_full;
    reg uart_rx_read;
    wire uart_rx_ready;
    wire [7:0] uart_rx_byte;


    localparam 
        freq = 27_000_000,
        baud = 230_400, // 1_000_000,
        bauddiv = freq / baud,
        baudwidth = $clog2(bauddiv);
    wire [baudwidth-1:0] baud_div = bauddiv;

    uart #(.FIFO_DEPTH(8), .RX_ENABLE(1), .TX_ENABLE(1), .BAUD_WIDTH(baudwidth)) mrtalky (
        .clk(pll_clk), .rst_n(rst_n), .baud_div(baud_div),
        .uart_tx_start(uart_tx_start), .uart_tx_data_in(uart_tx_data_in),
        .uart_tx_pin(uart_tx), .uart_tx_fifo_empty(uart_tx_fifo_empty), .uart_tx_fifo_full(uart_tx_fifo_full),
        .uart_rx_pin(uart_rx), .uart_rx_read(uart_rx_read), .uart_rx_ready(uart_rx_ready), .uart_rx_byte(uart_rx_byte));

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
    wire [10:0] vga_y_p1 = (vga_y + (vga_x == 799 ? 1'b1 : 1'b0));
    wire [7:0] font_dout;                           // output of rom
    wire [10:0] font_ad = {symbol, vga_y_p1[3:1]};     // address into the rom, it's 11 bits of which the top 8 are the symbol and bottom 3 are the row
    assign text_out = font_dout[7 - vga_x[2:0]];    // bit of output indexed from the ROM output

    // our 256 symbol 8x8 CP437 font
    Gowin_pROM madamme_font(
        .dout(font_dout), //output [7:0] dout
        .ad(font_ad), //input [10:0] ad
        .clk(pll_clk), //input clk
        .oce(1'b1), //input oce
        .ce(1'b1) //input ce
    );

    wire [15:0] mem_dout_a;
    reg mem_wr_en_a;
    reg [10:0] mem_addr_a;
    reg [15:0] mem_din_a;

    wire [15:0] mem_dout_b;
    wire [10:0] mem_addr_b;
	
    // video memory
    Gowin_DPB vt100_mem(
        // VT100
        .douta(mem_dout_a), //output [15:0] douta
        .clka(pll_clk), //input clka
        .ocea(1'b1), //input ocea
        .cea(1'b1), //input cea
        .reseta(~rst_n), //input reseta
        .wrea(mem_wr_en_a), //input wrea
        .ada(mem_addr_a), //input [10:0] ada
        .dina(mem_din_a), //input [15:0] dina

        // text driver
        .doutb(mem_dout_b), //output [15:0] doutb
        .clkb(pll_clk), //input clkb
        .oceb(1'b1), //input oceb
        .ceb(1'b1), //input ceb
        .resetb(~rst_n), //input resetb
        .wreb(1'b0), //input wreb
        .adb(mem_addr_b), //input [10:0] adb
        .dinb(16'b0) //input [15:0] dinb
    );


	// VGA text mode driver, defaults to 80x25 using an 8x8 font
	// notice we're scaling the font by 2 so we change the height to 16 here
	vga_text_driver #(.FONTHEIGHT(16), .X_FETCH_DELAY(2), .SYMBOL_BITS(16)) textdrv(
		.clk(pll_clk), .rst_n(rst_n),
		.x(vga_x), .y(vga_y), .active_video(vga_active),
		.rd_addr(mem_addr_b), .rd_data(mem_dout_b),
		.symbol(symbol), .lrg_mode(1'b0));

	// So the pipe is vga() produces the timing that
	// textdrv() uses produces the next 'symbol' that
	// font() uses to produce the next black/white signal fed to the VGA RGB output

    // this should be a module but I want to just hack stuff so leave me be hehehehe

    reg [6:0] vt100_x;
    reg [6:0] vt100_y;
    reg [7:0] vt100_colour;
    reg [3:0] vt100_fsm_state;
    reg [3:0] vt100_fsm_tag;
    reg [10:0] vt100_scroll;

    reg [7:0] vt100_term[7:0];
    reg [2:0] vt100_terms;
    reg vt100_term_default;
    reg [10:0] vt100_i;
    reg [10:0] vt100_j;
    reg [7:0] vt100_prev_char;

    localparam
        vt100_state_idle           = 0,
        vt100_state_rx_char        = 1,
        vt100_state_write_colour   = 2,
        vt100_state_scroll         = 3,
        vt100_state_scroll2        = 4,
        vt100_state_scroll3        = 5,
        vt100_state_csi_terms      = 6,
        vt100_state_csi_term_parse = 7,
        vt100_state_erase_cells    = 8,
        vt100_state_delay          = 9;
	
	always @(posedge pll_clk) begin
		if (!rst_n) begin
			mem_wr_en_a      <= 0;
            vt100_x          <= 0;
            vt100_y          <= 0;
            vt100_colour     <= 8'hFF;
            vt100_fsm_state  <= vt100_state_idle;
            vt100_terms      <= 0;
            vt100_i          <= 0;
            vt100_j          <= 0;
            vt100_prev_char  <= 0;
            uart_rx_read     <= 0;
            uart_tx_start    <= 0;
		end else begin
            case (vt100_fsm_state)
                vt100_state_idle:
                    begin
                        if (vt100_y == 25) begin
                            // initiate screen scroll fsm state
                            vt100_y         <= 24;
                            vt100_scroll    <= 0;  // read from scroll+80 and write to scroll 
                            vt100_fsm_state <= vt100_state_scroll;
                        end
                        if (uart_rx_ready) begin
                            uart_rx_read    <= 1;
                            vt100_fsm_tag   <= vt100_state_rx_char;
                            vt100_fsm_state <= vt100_state_delay;
                        end
                    end
                vt100_state_rx_char:
                    begin
                        vt100_prev_char <= uart_rx_byte;
                        uart_tx_start   <= 1;
                        uart_tx_data_in <= uart_rx_byte;
                        mem_addr_a      <= vt100_y * 80 + vt100_x;          // address for colour/symbol pair
                        mem_din_a       <= {vt100_colour, uart_rx_byte};
                        mem_wr_en_a     <= 1;
                        vt100_fsm_tag   <= vt100_state_idle;
                        vt100_fsm_state <= vt100_state_delay;
                        case (uart_rx_byte)
                            27: // ESC
                                begin
                                    mem_wr_en_a <= 0;
                                end
                            91: // [
                                begin
                                    if (vt100_prev_char == 27) begin
                                        // starting a CSI
                                        vt100_term[0]      <= 0;
                                        vt100_terms        <= 0;
                                        vt100_term_default <= 1;
                                        vt100_i            <= 0;
                                        vt100_j            <= 0;
                                        vt100_fsm_state    <= vt100_state_csi_terms;
                                        mem_wr_en_a        <= 0;
                                    end
                                end
                            10: // line feed
                                begin
                                    vt100_y     <= vt100_y + 1;
                                    vt100_x     <= 0;               // linux default
                                    mem_wr_en_a <= 0;
                                end
                            13: // carriage return
                                begin
                                    vt100_x     <= 0;
                                    mem_wr_en_a <= 0;
                                end
                            9: // tab
                                begin
                                    mem_din_a <= 0;
                                    if (vt100_x + 4 >= 80) begin
                                        vt100_x <= 79;
                                    end else begin
                                        vt100_x <= vt100_x + 4;
                                    end
                                end
                            8: // bs
                                begin
                                    if (vt100_x > 0) begin
                                        vt100_x     <= vt100_x - 1;
                                        mem_addr_a  <= mem_addr_a - 1;
                                        mem_din_a   <= 0;
                                    end else begin
                                        mem_wr_en_a <= 0;
                                    end
                                end
                            default:
                                begin
                                    // advance x/y
                                    if (vt100_x == 79) begin
                                        vt100_x <= 0;
                                        vt100_y <= vt100_y + 1;
                                    end else begin
                                        vt100_x <= vt100_x + 1;
                                    end
                                end
                        endcase
                    end
                vt100_state_scroll: // start read unless done
                    begin
                        if (vt100_scroll == (24 * 80)) begin
                            vt100_fsm_state <= vt100_state_scroll3;
                        end else begin
                            mem_addr_a      <= vt100_scroll + 80;
                            vt100_fsm_state <= vt100_state_delay;
                            vt100_fsm_tag   <= vt100_state_scroll2;
                        end
                    end
                vt100_state_scroll2: // start writee
                    begin
                        mem_addr_a   <= vt100_scroll;
                        mem_din_a    <= mem_dout_a;
                        mem_wr_en_a  <= 1;
                        vt100_scroll <= vt100_scroll + 1;
                        vt100_fsm_state <= vt100_state_delay;
                        vt100_fsm_tag   <= vt100_state_scroll;
                    end
                vt100_state_scroll3: // clear last row
                    begin
                        if (vt100_scroll == (25 * 80)) begin
                            vt100_fsm_state <= vt100_state_idle;
                        end else begin
                            mem_addr_a      <= vt100_scroll;
                            mem_din_a       <= 0;
                            mem_wr_en_a     <= 1;
                            vt100_scroll    <= vt100_scroll + 1;
                            vt100_fsm_state <= vt100_state_delay;
                            vt100_fsm_tag   <= vt100_fsm_state;
                        end
                    end
                vt100_state_csi_terms:
                    begin
                        if (uart_rx_ready) begin
                            uart_rx_read    <= 1;
                            vt100_fsm_state <= vt100_state_delay;
                            vt100_fsm_tag   <= vt100_state_csi_term_parse;
                        end
                    end
                vt100_state_csi_term_parse:
                    begin
                        vt100_fsm_state <= vt100_state_csi_terms;
                        if (uart_rx_byte >= 48 && uart_rx_byte <= 57) begin
                            vt100_term[vt100_terms] <= vt100_term[vt100_terms] * 10 + uart_rx_byte - 48;
                            vt100_term_default      <= 0;
                        end else if (uart_rx_byte == 59) begin // ;
                            vt100_terms                 <= vt100_terms + 1;
                            vt100_term[vt100_terms + 1] <= 0;
                        end else begin
                            vt100_fsm_state <= vt100_state_idle;
                            case (uart_rx_byte)
                                102, 72: // f or H
                                    begin
                                        if (vt100_term_default || vt100_terms == 0) begin
                                            vt100_x <= 0;
                                            vt100_y <= 0;
                                        end else if (vt100_terms != 0) begin
                                            vt100_y <= vt100_term[0] - 1;
                                            vt100_x <= vt100_term[1] - 1;
                                        end
                                    end
                                65: // A (move up X lines)
                                    begin
                                        if (vt100_y >= vt100_term[0]) begin
                                            vt100_y <= vt100_y - vt100_term[0];
                                        end else begin
                                            vt100_y <= 0;
                                        end
                                    end
                                66: // B (move down X lines)
                                    begin
                                        if ((vt100_y + vt100_term[0]) > 25) begin
                                            vt100_y <= 25;
                                        end else begin
                                            vt100_y <= vt100_y + vt100_term[0];
                                        end
                                    end
                                67: // C (move left X columns)
                                    begin
                                        if (vt100_x >= vt100_term[0]) begin
                                            vt100_x <= vt100_x - vt100_term[0];
                                        end else begin
                                            vt100_x <= 0;
                                        end
                                    end
                                68: // D (move right X columns)
                                    begin
                                        if ((vt100_x + vt100_term[0]) > 79) begin
                                            vt100_x <= 79;
                                        end else begin
                                            vt100_x <= vt100_x + vt100_term[0];
                                        end
                                    end
                                69: // E (reset x, move down X lines)
                                    begin
                                        vt100_x <= 0;
                                        if ((vt100_y + vt100_term[0]) > 25) begin
                                            vt100_y <= 25;
                                        end else begin
                                            vt100_y <= vt100_y + vt100_term[0];
                                        end
                                    end
                                70: // F (reset x, move up X lines)
                                    begin
                                        vt100_x <= 0;
                                        if (vt100_y >= vt100_term[0]) begin
                                            vt100_y <= vt100_y - vt100_term[0];
                                        end else begin
                                            vt100_y <= 0;
                                        end
                                    end
                                74: // J (erase)
                                    begin
                                        vt100_fsm_state <= vt100_state_idle;
                                        if (vt100_term[0] == 0 || vt100_term_default) begin // cursor to end of screen
                                            vt100_fsm_state <= vt100_state_erase_cells;
                                            vt100_i         <= vt100_y * 80 + vt100_x;
                                            vt100_j         <= 25 * 80;
                                        end else if (vt100_term[0] == 1) begin // from cursor to start of screen
                                            vt100_fsm_state <= vt100_state_erase_cells;
                                            vt100_j         <= vt100_y * 80 + vt100_x;
                                            vt100_i         <= 0;
                                        end else if (vt100_term[0] == 2) begin // entire screen
                                            vt100_fsm_state <= vt100_state_erase_cells;
                                            vt100_i         <= 0;
                                            vt100_j         <= 25 * 80;
                                        end
                                    end                                        
                            endcase
                        end
                    end
                vt100_state_erase_cells:
                    begin
                        if (vt100_i != vt100_j) begin
                            vt100_i         <= vt100_i + 1;
                            mem_wr_en_a     <= 1;
                            mem_din_a       <= {vt100_colour, 8'h20};
                            mem_addr_a      <= vt100_i;
                            vt100_fsm_state <= vt100_state_delay;
                            vt100_fsm_tag   <= vt100_fsm_state;
                        end else begin
                            vt100_fsm_state <= vt100_state_idle;
                        end
                    end
                vt100_state_delay:
                    begin
                        mem_wr_en_a     <= 0;
                        uart_rx_read    <= 0;
                        uart_tx_start   <= 0;
                        vt100_fsm_state <= vt100_fsm_tag;
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