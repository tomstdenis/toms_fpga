/* vt100 module

This accepts a 230.4K baud serial channel on uart_rx/uart_tx and outputs text+attribute bytes
to a synchronous video memory (mem_*_a).

Assumes a 80x25 display for now.

*/

`timescale 1ns/1ps
`default_nettype none

module vt100
#(
    parameter VT100_WIDTH=11'd80,
    parameter VT100_HEIGHT=11'd25,
    parameter VT100_FREQ=27_000_000,    // default clock for a Tang Nano 1K
    parameter VT100_BAUD=230_400,
    parameter INDEX_BITS=$clog2(VT100_WIDTH*VT100_HEIGHT)
)
(
    input wire clk,
    input wire rst_n,

    input wire uart_rx,
    output wire uart_tx,

    output reg [INDEX_BITS-1:0] mem_addr_a,       // video memory in 80x25 format with 16 bits per symbol ([15:8] == attribute, [7:0] == symbol)
    output reg [15:0] mem_din_a,
    input wire [15:0] mem_dout_a,
    output reg        mem_wr_en_a,

    input wire [15:0] symbol,
    input wire text_out,
    input wire vga_active,
    output reg [3:0] vga_r,
    output reg [3:0] vga_g,
    output reg [3:0] vga_b
);

    // uart driven by uart_tx/uart_rx pins
    reg uart_tx_start;
    reg [7:0] uart_tx_data_in;
    wire uart_tx_fifo_empty;
    wire uart_tx_fifo_full;
    reg uart_rx_read;
    wire uart_rx_ready;
    wire [7:0] uart_rx_byte;

    localparam 
        bauddiv = VT100_FREQ / VT100_BAUD,
        baudwidth = $clog2(bauddiv);
    wire [baudwidth-1:0] baud_div = bauddiv;

    uart #(.FIFO_DEPTH(16), .RX_ENABLE(1), .TX_ENABLE(0), .BAUD_WIDTH(baudwidth)) mrtalky (
        .clk(clk), .rst_n(rst_n), .baud_div(baud_div),
        .uart_tx_start(uart_tx_start), .uart_tx_data_in(uart_tx_data_in),
        .uart_tx_pin(uart_tx), .uart_tx_fifo_empty(uart_tx_fifo_empty), .uart_tx_fifo_full(uart_tx_fifo_full),
        .uart_rx_pin(uart_rx), .uart_rx_read(uart_rx_read), .uart_rx_ready(uart_rx_ready), .uart_rx_byte(uart_rx_byte));

    reg [INDEX_BITS-1:0] vt100_x;
    reg [INDEX_BITS-1:0] vt100_y;
    reg [INDEX_BITS-1:0] vt100_sx;
    reg [INDEX_BITS-1:0] vt100_sy;
    reg [7:0]  vt100_colour;
    reg        vt100_linewrap;
    reg [3:0]  vt100_fsm_state;
    reg [3:0]  vt100_fsm_tag;

    reg [7:0]  vt100_term[3:0];
    reg [2:0]  vt100_terms;
    reg        vt100_term_default;
    reg [INDEX_BITS-1:0] vt100_i;
    reg [INDEX_BITS-1:0] vt100_j;
    reg [7:0]  vt100_prev_char;

    wire [INDEX_BITS-1:0] vt100_row_addr;
    wire [INDEX_BITS-1:0] vt100_cursor_addr;
    assign vt100_row_addr    = vt100_y * VT100_WIDTH;
    assign vt100_cursor_addr = vt100_row_addr + vt100_x;

    localparam
        vt100_state_idle           = 0,
        vt100_state_rx_char        = 1,
        vt100_state_write_colour   = 2,
        vt100_state_scroll         = 3,
        vt100_state_scroll2        = 4,
        vt100_state_scroll3        = 5,
        vt100_state_csi_terms      = 6,
        vt100_state_zero_term      = 7,
        vt100_state_csi_term_parse = 8,
        vt100_state_erase_cells    = 9,
        vt100_state_attributes     = 10,
        vt100_state_delay          = 11;
	
	always @(posedge clk) begin
		if (!rst_n) begin
			mem_wr_en_a      <= 0;
            vt100_x          <= 0;
            vt100_y          <= 0;
            vt100_sx         <= 0;
            vt100_sy         <= 0;
            vt100_colour     <= {1'b0, 1'b0, 3'b0, 3'b111};
            vt100_linewrap   <= 1'b0;
            vt100_fsm_state  <= vt100_state_idle;
            vt100_i          <= 0;
            vt100_j          <= 0;
            vt100_prev_char  <= 0;
            uart_rx_read     <= 0;
            uart_tx_start    <= 0;
		end else begin
            case (vt100_fsm_state)
                vt100_state_idle:
                    begin
                        vt100_terms <= 0;
                        if (vt100_y[10]) begin          // went negative
                            vt100_y         <= 0;
                        end else if (vt100_x[10]) begin // x went negative
                            vt100_x         <= 0;
                        end else if (vt100_x >= VT100_WIDTH) begin
                            vt100_x         <= VT100_WIDTH - 1;
                        end else if (vt100_y >= VT100_HEIGHT) begin
                            // initiate screen scroll fsm state
                            vt100_y         <= vt100_y - 1'b1;
                            vt100_i         <= 0;  // read from scroll+80 and write to scroll 
                            vt100_fsm_state <= vt100_state_scroll;
                        end else if (uart_rx_ready) begin
                            uart_rx_read    <= 1;
                            vt100_fsm_tag   <= vt100_state_rx_char;
                            vt100_fsm_state <= vt100_state_delay;
                        end

                    end
                vt100_state_rx_char:
                    begin
                        vt100_prev_char <= uart_rx_byte;
                        uart_tx_start   <= 0;
                        uart_tx_data_in <= uart_rx_byte;
                        mem_addr_a      <= vt100_cursor_addr;          // address for colour/symbol pair
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
                                        vt100_term[vt100_terms] <= 0;
                                        vt100_term_default <= 1;
                                        vt100_i            <= 0;
                                        vt100_j            <= 0;
                                        vt100_fsm_state    <= vt100_state_csi_terms;
                                        mem_wr_en_a        <= 0;
                                    end
                                end
                            10: // line feed
                                begin
                                    vt100_y     <= vt100_y + 1'b1;
                                    vt100_x     <= 0;               // linux default
                                    mem_wr_en_a <= 0;
                                end
                            13: // carriage return
                                begin
                                    vt100_x     <= 0;
                                    mem_wr_en_a <= 0;
                                end
                            8: // bs
                                begin
                                    if (vt100_x > 0) begin
                                        vt100_x     <= vt100_x - 1'b1;
                                        mem_addr_a  <= vt100_cursor_addr - 1'b1;
                                        mem_din_a   <= {vt100_colour, 8'h20};
                                    end else begin
                                        mem_wr_en_a <= 0;
                                    end
                                end
                            default:
                                begin
                                    // advance x/y
                                    if (vt100_x == VT100_WIDTH - 1) begin
                                        if (vt100_linewrap) begin
                                            vt100_x <= 0;
                                            vt100_y <= vt100_y + 1'b1;
                                        end
                                    end else begin
                                        vt100_x <= vt100_x + 1'b1;
                                    end
                                end
                        endcase
                    end
                vt100_state_scroll: // start read unless done
                    begin
                        if (vt100_i == (VT100_HEIGHT * VT100_WIDTH - VT100_WIDTH)) begin
                            vt100_fsm_state <= vt100_state_scroll3;
                        end else begin
                            mem_addr_a      <= vt100_i + VT100_WIDTH;
                            vt100_fsm_state <= vt100_state_delay;
                            vt100_fsm_tag   <= vt100_state_scroll2;
                        end
                    end
                vt100_state_scroll2: // start write
                    begin
                        mem_addr_a      <= vt100_i;
                        mem_din_a       <= mem_dout_a;
                        mem_wr_en_a     <= 1;
                        vt100_i         <= vt100_i + 1'b1;
                        vt100_fsm_state <= vt100_state_delay;
                        vt100_fsm_tag   <= vt100_state_scroll;
                    end
                vt100_state_scroll3: // clear last row
                    begin
                        if (vt100_i == (VT100_HEIGHT * VT100_WIDTH)) begin
                            vt100_fsm_state <= vt100_state_idle;
                        end else begin
                            mem_addr_a      <= vt100_i;
                            mem_din_a       <= {vt100_colour, 8'h20};
                            mem_wr_en_a     <= 1'b1;
                            vt100_i         <= vt100_i + 1'b1;
                            vt100_fsm_state <= vt100_state_delay;
                            vt100_fsm_tag   <= vt100_fsm_state;
                        end
                    end
                vt100_state_zero_term:
                    begin
                        vt100_term[vt100_terms] <= 0;
                        vt100_fsm_state         <= vt100_state_csi_terms;
                    end
                vt100_state_csi_terms:
                    begin
                        if (uart_rx_ready) begin
                            uart_rx_read    <= 1'b1;
                            vt100_fsm_state <= vt100_state_delay;
                            vt100_fsm_tag   <= vt100_state_csi_term_parse;
                        end
                    end
                vt100_state_csi_term_parse:
                    begin
                        vt100_fsm_state <= vt100_state_csi_terms;
                        if (uart_rx_byte >= 48 && uart_rx_byte <= 57) begin // 0 - 9
                            vt100_term[vt100_terms] <= vt100_term[vt100_terms] * 8'd10 + uart_rx_byte - 8'd48;
                            vt100_term_default      <= 1'b0;
                        end else if (uart_rx_byte == 61 || uart_rx_byte == 63) begin              // =, ?
                            // for now just skip over this byte
                        end else if (uart_rx_byte == 59) begin              // ;
                            vt100_terms             <= vt100_terms + 1'b1;
                            vt100_fsm_state         <= vt100_state_zero_term;
                        end else begin                                      // command character
                            vt100_fsm_state <= vt100_state_idle;
                            case (uart_rx_byte)
                                102, 72: // f or H
                                    begin
                                        if (vt100_term_default) begin
                                            vt100_x <= 1'b0;
                                            vt100_y <= 1'b0;
                                        end else begin
                                            vt100_y <= vt100_term[0] - 1'b1;
                                            vt100_x <= vt100_term[1] - 1'b1;
                                        end
                                    end
                                65: // A (move up X lines)
                                    begin
                                        vt100_y <= vt100_y - vt100_term[0];
                                    end
                                66: // B (move down X lines)
                                    begin
                                        vt100_y <= vt100_y + vt100_term[0];
                                    end
                                67: // C (move left X columns)
                                    begin
                                        vt100_x <= vt100_x - vt100_term[0];
                                    end
                                68: // D (move right X columns)
                                    begin
                                        vt100_x <= vt100_x + vt100_term[0];
                                    end
                                69: // E (reset x, move down X lines)
                                    begin
                                        vt100_x <= 0;
                                        vt100_y <= vt100_y + vt100_term[0];
                                    end
                                70: // F (reset x, move up X lines)
                                    begin
                                        vt100_x <= 0;
                                        vt100_y <= vt100_y - vt100_term[0];
                                    end
                                71: // G (move to column X)
                                    begin
                                        vt100_x <= vt100_term[0] - 1'b1;
                                    end
                                74: // J (erase)
                                    begin
                                        if (vt100_term[0] == 0 || vt100_term_default) begin // cursor to end of screen
                                            vt100_fsm_state <= vt100_state_erase_cells;
                                            vt100_i         <= vt100_cursor_addr;
                                            vt100_j         <= VT100_HEIGHT * VT100_WIDTH;
                                        end else if (vt100_term[0] == 1) begin // from cursor to start of screen
                                            vt100_fsm_state <= vt100_state_erase_cells;
                                            vt100_j         <= vt100_cursor_addr;
                                            vt100_i         <= 11'd0;
                                        end else if (vt100_term[0] == 2) begin // entire screen
                                            vt100_fsm_state <= vt100_state_erase_cells;
                                            vt100_i         <= 11'd0;
                                            vt100_j         <= VT100_HEIGHT * VT100_WIDTH;
                                        end
                                    end
                                75: // K (erase row)
                                    begin
                                        if (vt100_term[0] == 0 || vt100_term_default) begin // cursor to end of line
                                            vt100_fsm_state <= vt100_state_erase_cells;
                                            vt100_i         <= vt100_cursor_addr;
                                            vt100_j         <= vt100_row_addr + VT100_WIDTH - vt100_x;
                                        end else if (vt100_term[0] == 1) begin // from start of line to cursor
                                            vt100_fsm_state <= vt100_state_erase_cells;
                                            vt100_i         <= vt100_row_addr;
                                            vt100_j         <= vt100_cursor_addr;
                                        end else if (vt100_term[0] == 2) begin // erase current line
                                            vt100_fsm_state <= vt100_state_erase_cells;
                                            vt100_i         <= vt100_row_addr;
                                            vt100_j         <= vt100_row_addr + VT100_WIDTH;
                                        end
                                    end
                                104: // h (set mode bit)
                                    begin
                                        case (vt100_term[0])
                                            7: // linewrap
                                                vt100_linewrap <= 1'b1;
                                        endcase
                                    end
                                108: // l (clear mode bit)
                                    begin
                                        case (vt100_term[0])
                                            7: // linewrap
                                                vt100_linewrap <= 1'b0;
                                        endcase
                                    end
                                109: // m (attributes)
                                    begin
                                        vt100_fsm_state     <= vt100_state_attributes;
                                        vt100_j             <= vt100_terms;
                                        vt100_terms         <= 0;
                                    end
                                115: // s (save cursor position)
                                    begin
                                        vt100_sx            <= vt100_x;
                                        vt100_sy            <= vt100_y;
                                    end
                                117: // u (restore cursor)
                                    begin
                                        vt100_x             <= vt100_sx;
                                        vt100_y             <= vt100_sy;
                                    end
                            endcase
                        end
                    end
                vt100_state_erase_cells:
                    begin
                        if (vt100_i != vt100_j) begin
                            vt100_i         <= vt100_i + 1'b1;
                            mem_wr_en_a     <= 1'b1;
                            mem_din_a       <= {vt100_colour, 8'h20};
                            mem_addr_a      <= vt100_i;
                            vt100_fsm_state <= vt100_state_delay;
                            vt100_fsm_tag   <= vt100_fsm_state;
                        end else begin
                            vt100_fsm_state <= vt100_state_idle;
                        end
                    end
                vt100_state_attributes:
                    begin
                        // handle attribute vt100_term[vt100_i]
                        vt100_terms <= vt100_terms + 1'b1;
                        if (vt100_term[vt100_terms] == 0) begin
                            vt100_colour <= {1'b0, 1'b0, 3'b0, 3'b111};
                        end else if (vt100_term[vt100_terms] == 1) begin // set bold
                            vt100_colour[7:6] <= 2'b11;
                        end else if (vt100_term[vt100_terms] == 2) begin // set dim
                            vt100_colour[7:6] <= 2'b00;
                        end else if (vt100_term[vt100_terms] >= 30 && vt100_term[vt100_terms] <= 37) begin  // foreground
                            vt100_colour[2:0] <= vt100_term[vt100_terms][2:0] - 3'd30;
                        end else if (vt100_term[vt100_terms] >= 40 && vt100_term[vt100_terms] <= 47) begin //background
                            vt100_colour[5:3] <= vt100_term[vt100_terms][2:0] - 3'd40;
                        end else if (vt100_term[vt100_terms] == 39) begin //default foreground
                            vt100_colour[2:0] <= 3'd7;
                            vt100_colour[7]   <= 1'b0;
                        end else if (vt100_term[vt100_terms] == 49) begin //default background
                            vt100_colour[5:3] <= 3'd0;
                            vt100_colour[6]   <= 1'b0;
                        end else if (vt100_term[vt100_terms] >= 90 && vt100_term[vt100_terms] <= 97) begin // bright foreground
                            vt100_colour[7]   <= 1;
                            vt100_colour[2:0] <= vt100_term[vt100_terms][2:0] - 3'd90;
                        end else if (vt100_term[vt100_terms] >= 100 && vt100_term[vt100_terms] <= 107) begin // bright background
                            vt100_colour[6]   <= 1;
                            vt100_colour[5:3] <= vt100_term[vt100_terms][2:0] - 3'd100;
                        end
                        if (vt100_j == vt100_terms) begin
                            vt100_fsm_state <= vt100_state_idle;
                        end
                    end
                vt100_state_delay:
                    begin
                        mem_wr_en_a     <= 1'b0;
                        uart_rx_read    <= 1'b0;
                        uart_tx_start   <= 1'b0;
                        vt100_fsm_state <= vt100_fsm_tag;
                    end
            endcase
		end
	end

    // grab the current symbol attribute and latch it so it's valid for the entire width of the font
    wire [1:0] text_at;
    wire [2:0] text_fg;
    wire [2:0] text_bg;
    reg [1:0] text_at_out;
    reg [2:0] text_fg_out;
    reg [2:0] text_bg_out;
    wire [3:0] rgbon;

    assign text_at = symbol[15:14];
    assign text_bg = symbol[13:11];
    assign text_fg = symbol[10:8];
    always @(posedge clk) begin
        text_at_out <= text_at;
        text_bg_out <= text_bg;
        text_fg_out <= text_fg;
    end
    assign rgbon = {text_at_out[text_out], 3'b111};

    // drive the VGA R/G/B pins
	always @(*) begin
		vga_r = 0;
		vga_g = 0;
		vga_b = 0;
		
        // render the foreground/background colour using the VT100 palette, with support
        // bold/dim attributes
		if (vga_active) begin
            case (text_out ? text_fg_out : text_bg_out)
                0: // black
                    {vga_r, vga_g, vga_b} <= 12'b0000_0000_0000;
                1: // red
                    {vga_r, vga_g, vga_b} <= {rgbon, 4'b0000, 4'b0000};
                2: // green
                    {vga_r, vga_g, vga_b} <= {4'b0000, rgbon, 4'b0000};
                3: // yellow
                    {vga_r, vga_g, vga_b} <= {rgbon, rgbon, 4'b0000};
                4: // blue
                    {vga_r, vga_g, vga_b} <= {4'b0000, 4'b0000, rgbon};
                5: // magenta
                    {vga_r, vga_g, vga_b} <= {rgbon, 4'b0000, rgbon};
                6: // cyan
                    {vga_r, vga_g, vga_b} <= {4'b0000, rgbon, rgbon};
                7: // white
                    {vga_r, vga_g, vga_b} <= {rgbon, rgbon, rgbon};
            endcase
		end
	end


endmodule