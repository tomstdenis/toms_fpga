/* vt100 module

This accepts a 230.4K baud serial channel on uart_rx/uart_tx and outputs text+attribute bytes
to a synchronous video memory (mem_*_a).

Assumes a 80x25 display for now.

*/

`timescale 1ns/1ps
`default_nettype none

module vt100
#(
    parameter VT100_WIDTH=80,
    parameter VT100_HEIGHT=25,
    parameter VT100_FREQ=27_000_000,    // default clock for a Tang Nano 1K
    parameter VT100_BAUD=230_400
)
(
    input wire clk,
    input wire rst_n,

    input wire uart_rx,
    output wire uart_tx,

    output reg [10:0] mem_addr_a,       // video memory in 80x25 format with 16 bits per symbol ([15:8] == attribute, [7:0] == symbol)
    output reg [15:0] mem_din_a,
    input wire [15:0] mem_dout_a,
    output reg        mem_wr_en_a
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

    reg [10:0] vt100_x;
    reg [10:0] vt100_y;
    reg [7:0]  vt100_colour;
    reg [3:0]  vt100_fsm_state;
    reg [3:0]  vt100_fsm_tag;
    reg [10:0] vt100_scroll;

    reg [7:0]  vt100_term[3:0];
    reg [2:0]  vt100_terms;
    reg        vt100_term_default;
    reg [10:0] vt100_i;
    reg [10:0] vt100_j;
    reg [7:0]  vt100_prev_char;

    wire [10:0] vt100_row_addr;
    wire [10:0] vt100_cursor_addr;
    assign vt100_row_addr    = vt100_y * 11'd80;
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
            vt100_colour     <= {1'b0, 1'b0, 3'b0, 3'b111};
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
                                    vt100_y     <= vt100_y + 1'b1;
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
                                    mem_din_a   <= {vt100_colour, 8'h20};
                                    if (vt100_x + 4 >= 80) begin
                                        vt100_x <= 79;
                                    end else begin
                                        vt100_x <= vt100_x + 7'd4;
                                    end
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
                                    if (vt100_x == 79) begin
                                        vt100_x <= 0;
                                        vt100_y <= vt100_y + 1'b1;
                                    end else begin
                                        vt100_x <= vt100_x + 1'b1;
                                    end
                                end
                        endcase
                    end
                vt100_state_scroll: // start read unless done
                    begin
                        if (vt100_scroll == (24 * 80)) begin
                            vt100_fsm_state <= vt100_state_scroll3;
                        end else begin
                            mem_addr_a      <= vt100_scroll + 11'd80;
                            vt100_fsm_state <= vt100_state_delay;
                            vt100_fsm_tag   <= vt100_state_scroll2;
                        end
                    end
                vt100_state_scroll2: // start write
                    begin
                        mem_addr_a      <= vt100_scroll;
                        mem_din_a       <= mem_dout_a;
                        mem_wr_en_a     <= 1;
                        vt100_scroll    <= vt100_scroll + 1'b1;
                        vt100_fsm_state <= vt100_state_delay;
                        vt100_fsm_tag   <= vt100_state_scroll;
                    end
                vt100_state_scroll3: // clear last row
                    begin
                        if (vt100_scroll == (25 * 80)) begin
                            vt100_fsm_state <= vt100_state_idle;
                        end else begin
                            mem_addr_a      <= vt100_scroll;
                            mem_din_a       <= {vt100_colour, 8'h20};
                            mem_wr_en_a     <= 1'b1;
                            vt100_scroll    <= vt100_scroll + 1'b1;
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
                        end else if (uart_rx_byte == 59) begin              // ;
                            vt100_terms                 <= vt100_terms + 1'b1;
                            vt100_fsm_state             <= vt100_state_zero_term;
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
                                71: // G (move to column X)
                                    begin
                                        if (vt100_term[0] > 80) begin
                                            vt100_x <= 79;
                                        end else begin
                                            vt100_x <= vt100_term[0] - 1;
                                        end
                                    end
                                74: // J (erase)
                                    begin
                                        if (vt100_term[0] == 0 || vt100_term_default) begin // cursor to end of screen
                                            vt100_fsm_state <= vt100_state_erase_cells;
                                            vt100_i         <= vt100_cursor_addr;
                                            vt100_j         <= 11'd25 * 11'd80;
                                        end else if (vt100_term[0] == 1) begin // from cursor to start of screen
                                            vt100_fsm_state <= vt100_state_erase_cells;
                                            vt100_j         <= vt100_cursor_addr;
                                            vt100_i         <= 11'd0;
                                        end else if (vt100_term[0] == 2) begin // entire screen
                                            vt100_fsm_state <= vt100_state_erase_cells;
                                            vt100_i         <= 11'd0;
                                            vt100_j         <= 11'd25 * 11'd80;
                                        end
                                    end
                                75: // K (erase row)
                                    begin
                                        if (vt100_term[0] == 0 || vt100_term_default) begin // cursor to end of line
                                            vt100_fsm_state <= vt100_state_erase_cells;
                                            vt100_i         <= vt100_cursor_addr;
                                            vt100_j         <= vt100_row_addr + 11'd80 - vt100_x;
                                        end else if (vt100_term[0] == 1) begin // from start of line to cursor
                                            vt100_fsm_state <= vt100_state_erase_cells;
                                            vt100_i         <= vt100_row_addr;
                                            vt100_j         <= vt100_cursor_addr;
                                        end else if (vt100_term[0] == 2) begin // erase current line
                                            vt100_fsm_state <= vt100_state_erase_cells;
                                            vt100_i         <= vt100_row_addr;
                                            vt100_j         <= vt100_row_addr + 11'd80;
                                        end
                                    end
                                109: // m (attributes)
                                    begin
                                        vt100_fsm_state     <= vt100_state_attributes;
                                        vt100_j             <= vt100_terms;
                                        vt100_terms         <= 0;
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
                            vt100_colour[2:0] <= vt100_term[vt100_terms] - 8'd30;
                        end else if (vt100_term[vt100_terms] >= 40 && vt100_term[vt100_terms] <= 47) begin //background
                            vt100_colour[5:3] <= vt100_term[vt100_terms] - 8'd40;
                        end else if (vt100_term[vt100_terms] == 39) begin //default foreground
                            vt100_colour[2:0] <= 8'd7;
                        end else if (vt100_term[vt100_terms] == 49) begin //default background
                            vt100_colour[5:3] <= 8'd0;
                        end else if (vt100_term[vt100_terms] >= 90 && vt100_term[vt100_terms] <= 97) begin // bright foreground
                            vt100_colour[7]   <= 1;
                            vt100_colour[2:0] <= vt100_term[vt100_terms] - 8'd90;
                        end else if (vt100_term[vt100_terms] >= 100 && vt100_term[vt100_terms] <= 107) begin // bright background
                            vt100_colour[6]   <= 1;
                            vt100_colour[5:3] <= vt100_term[vt100_terms] - 8'd100;
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
endmodule