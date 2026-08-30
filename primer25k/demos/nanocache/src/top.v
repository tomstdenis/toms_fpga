// note if you change any of this you need to rebuild the memory IP blocks
// 16KB cache, 32byte line
`define CACHE_SIZE      14
`define CACHE_LINE       5
`define CACHE_LINES      (`CACHE_SIZE - `CACHE_LINE)
`define CACHE_REGISTERED 1
`define CACHE_DP         1
`define SRAM_ADDR_WIDTH 24

// this is the wrapper for our TAG memory using a Gowin SP registered memory
module nanocache_tag_mem #(
    parameter WIDTH=2 + `SRAM_ADDR_WIDTH - `CACHE_LINE - `CACHE_LINES,      // width of data in bits
    parameter DEPTH=`CACHE_LINES,                                           // address width in bits
    parameter REG=`CACHE_REGISTERED
)(
    input wire clk,
    input wire rst_n,

    output wire [WIDTH-1:0] mem_out,
    input wire [WIDTH-1:0]  mem_in,
    input wire [DEPTH-1:0] addr,
    input wire wren
);
    gowin_tagmem tagmem(
        .dout(mem_out), //output [11:0] dout
        .clk(clk), //input clk
        .oce(1'b1), //input oce
        .ce(1'b1), //input ce
        .reset(~rst_n), //input reset
        .wre(wren), //input wre
        .ad(addr), //input [8:0] ad
        .din(mem_in) //input [11:0] din
    );
endmodule

// this is the wrapper for our cache memory using a set of Gowin DP register memories in an 8x16384 configuration
module nanocache_cache_mem #(
    parameter WIDTH=8,                      // width of data in bits
    parameter DEPTH=`CACHE_SIZE,            // address width in bits
    parameter REG=`CACHE_REGISTERED
)(
    input wire clk,
    input wire rst_n,

    output wire [WIDTH-1:0] mem_out_1,
    input wire [WIDTH-1:0]  mem_in_1,
    input wire [DEPTH-1:0]  mem_addr_1,
    input wire              mem_wren_1,

    output wire [WIDTH-1:0] mem_out_2,
    input wire [WIDTH-1:0]  mem_in_2,
    input wire [DEPTH-1:0]  mem_addr_2,
    input wire              mem_wren_2
);

    gowin_cache_mem cache_mem(
        .douta(mem_out_1), //output [7:0] douta
        .clka(clk), //input clka
        .ocea(1'b1), //input ocea
        .cea(1'b1), //input cea
        .reseta(~rst_n), //input reseta
        .wrea(mem_wren_1), //input wrea
        .ada(mem_addr_1), //input [13:0] ada
        .dina(mem_in_1), //input [7:0] dina

        .doutb(mem_out_2), //output [7:0] doutb
        .clkb(clk), //input clkb
        .oceb(1'b1), //input oceb
        .ceb(1'b1), //input ceb
        .resetb(~rst_n), //input resetb
        .wreb(mem_wren_2), //input wreb
        .adb(mem_addr_2), //input [13:0] adb
        .dinb(mem_in_2) //input [7:0] dinb
    );
endmodule

module top(
    input wire clk,

    output wire uart_tx,
    input wire uart_rx,

    output wire sck_pin,
    output wire cs_pin,
    inout wire [3:0] sio
);

    localparam
        SRAM_ADDR_WIDTH = 24,
        PSRAM = 1,       // 1 == use PSRAM, 0 == SRAM
        FREQ  = 100_000;  // clock rate in LHz

    wire pllclk;

    Gowin_PLL MrGoFast(
        .clkout0(pllclk), //output clkout
        .clkin(clk) //input clkin
    );

    reg rst_n = 1'b0;

    localparam
        baud     = 1_000_000,
        baud_div = (FREQ * 1_000) / baud,
        baud_width = $clog2(baud_div);

    wire [baud_width-1:0] bauddiv = baud_div;

    reg uart_tx_start;
    reg [7:0] uart_tx_data_in;
    wire uart_tx_fifo_full;
    wire uart_tx_fifo_empty;
    reg  uart_rx_read;
    wire uart_rx_ready;
    wire [7:0] uart_rx_byte;

    uart #(.FIFO_DEPTH(4), .RX_ENABLE(1), .TX_ENABLE(1), .BAUD_WIDTH(baud_width)) MrTalky(
        .clk(pllclk), .rst_n(rst_n),
        .baud_div(bauddiv), .uart_tx_start(uart_tx_start), .uart_tx_data_in(uart_tx_data_in),
        .uart_tx_pin(uart_tx), .uart_tx_fifo_empty(uart_tx_fifo_empty), .uart_tx_fifo_full(uart_tx_fifo_full),
        .uart_rx_pin(uart_rx), .uart_rx_read(uart_rx_read), .uart_rx_ready(uart_rx_ready), .uart_rx_byte(uart_rx_byte));

    reg [31:0] nc_data_in;
    reg [3:0] nc_write_mask;
    reg [SRAM_ADDR_WIDTH-1:0] nc_data_addr;
    reg nc_data_wr_en;
    wire [31:0] nc_data_out;
    reg nc_valid;
    wire nc_ready;
    wire nc_idle;

    wire [3:0] sio_din;
    wire [3:0] sio_dout;
    wire       sio_en;

    assign sio     = sio_en ? sio_dout : 4'bzzzz;
    assign sio_din = sio;

    nanocache #(
        .CACHE_SIZE(`CACHE_SIZE),
        .CACHE_LINE(`CACHE_LINE),
        .CACHE_DP(`CACHE_DP),
        .CACHE_REGISTERED(`CACHE_REGISTERED),
        .SRAM_ADDR_WIDTH(SRAM_ADDR_WIDTH),
        .FREQ(FREQ/1000)) MrLocalMemory
    (
        .clk(pllclk), .rst_n(rst_n),
        .data_in(nc_data_in), .data_out(nc_data_out), .data_addr(nc_data_addr), .data_wr_en(nc_data_wr_en), .write_mask(nc_write_mask),
        .valid(nc_valid), .ready(nc_ready), .idle(nc_idle),
        .sio_din(sio_din), .sio_dout(sio_dout), .sio_en(sio_en), .cs_pin(cs_pin), .sck_pin(sck_pin)
    );

    reg [2:0]  test_state;
    reg [2:0]  test_cnt;
    reg        test_pass;
    reg [63:0] test_data;

    reg [3:0]  command_op;
    reg [3:0]  command_burst_len;
    reg [23:0] command_addr;
    reg [31:0] command_data;

    always @(*) begin
        command_op        = test_data[63:60];
        command_burst_len = test_data[59:56];
        command_addr      = test_data[55:32];
        command_data      = test_data[31:0];
    end

    localparam
		command_op_read  = 4'h8,
		command_op_write = 4'h4,
		command_op_halt  = 4'h2;

    localparam
        STATE_START_COMMAND   = 0,
        STATE_PROCESS_COMMAND = 1,
        STATE_RX_BYTE         = 2,
        STATE_WRITE           = 3,
        STATE_READ            = 4,
        STATE_HALT            = 5,
        STATE_PASS            = 6,
        STATE_DELAY           = 7;

    always @(posedge pllclk) begin
        nc_valid         <= 1'b0;
        if (!rst_n) begin
            rst_n            <= 1'b1;
            uart_tx_start    <= 1'b0;
            uart_rx_read     <= 1'b0;
            test_state       <= STATE_START_COMMAND;
            test_cnt         <= 7;
            test_pass        <= 1'b0;
        end else begin
            case (test_state)
                STATE_START_COMMAND:
                    begin
                        uart_tx_start           <= 1'b0;
                        if (uart_rx_ready) begin
                            test_state          <= STATE_DELAY;
                            uart_rx_read        <= 1'b1;
                        end
                    end
                STATE_DELAY: 
                    begin
                        uart_rx_read  <= 1'b0;
                        test_state    <= STATE_RX_BYTE;
                    end
                STATE_RX_BYTE:
                    begin
                        test_cnt        <= test_cnt - 1'b1;
                        test_data       <= {test_data[55:0], uart_rx_byte };
                        if (test_cnt == 0) begin
                            test_state <= STATE_PROCESS_COMMAND;
                        end else begin
                            test_state <= STATE_START_COMMAND;
                        end
                    end
                STATE_PROCESS_COMMAND:
                    begin
                        uart_tx_start <= 1'b0;
						case (test_data[59:56]) 
							0: nc_write_mask <= 4'b1000;
							1: nc_write_mask <= 4'b1100;
							2: nc_write_mask <= 4'b1110;
							3: nc_write_mask <= 4'b1111;
						endcase
                        case (test_data[63:60])
                            command_op_read:   test_state <= STATE_READ;
                            command_op_write:  test_state <= STATE_WRITE;
                            command_op_halt: 
                                begin
                                    test_state <= STATE_HALT;
                                    test_pass  <= 1'b1;
                                end
                            default:
                                begin
                                    test_state <= STATE_START_COMMAND;
                                    test_cnt   <= 7;
                                end
                        endcase
                    end
                STATE_READ:
                    begin
						if (!nc_valid & nc_idle) begin
							nc_valid      <= 1;
							nc_data_wr_en <= 0;
							nc_data_addr  <= command_addr;
						end
						if (nc_ready) begin
							test_state <= STATE_PASS;
                            if (nc_write_mask[3] && nc_data_out[31:24] != command_data[31:24]) begin
                                test_state <= STATE_HALT;
                            end
                            if (nc_write_mask[2] && nc_data_out[23:16] != command_data[23:16]) begin
                                test_state <= STATE_HALT;
                            end
                            if (nc_write_mask[1] && nc_data_out[15:8] != command_data[15:8]) begin
                                test_state <= STATE_HALT;
                            end
                            if (nc_write_mask[0] && nc_data_out[7:0] != command_data[7:0]) begin
                                test_state <= STATE_HALT;
                            end
						end
                    end
                STATE_WRITE:
                    begin
						if (!nc_valid & nc_idle) begin								// only program job once
							nc_valid      <= 1'b1;
							nc_data_wr_en <= 1'b1;
							nc_data_in    <= command_data;
							nc_data_addr  <= command_addr;
						end
						if (nc_ready) begin											// ready strobe
							test_state <= STATE_PASS;
						end
                    end
                STATE_PASS:
                    begin
                        if (!uart_tx_fifo_full) begin
                            uart_tx_start   <= 1'b1;
                            uart_tx_data_in <= 8'hAA;
                            test_state      <= STATE_START_COMMAND;
                        end
                    end
                STATE_HALT:
                    begin
                        if (!uart_tx_fifo_full) begin
                            uart_tx_start <= 1'b1;
                            uart_tx_data_in <= test_pass ? 8'hBB : 8'h55;
                            test_state      <= STATE_START_COMMAND;
                        end
                    end
            endcase
        end
    end
endmodule
