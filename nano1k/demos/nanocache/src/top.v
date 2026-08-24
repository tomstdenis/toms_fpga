module top(
    input wire clk,

    output wire uart_tx,
    input wire uart_rx,

    output reg rgb_r,
    output reg rgb_g,
    output reg rgb_b,

    output wire sck_pin,
    output wire cs_pin,
    inout wire [3:0] sio
);

    localparam
        SRAM_ADDR_WIDTH = 24,
        PSRAM = 1,       // 1 == use PSRAM, 0 == SRAM
        FREQ  = 74_250;  // clock rate in LHz

    wire pllclk;

    Gowin_rPLL MrGoFast(
        .clkout(pllclk), //output clkout
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

    uart #(.FIFO_DEPTH(16), .RX_ENABLE(1), .TX_ENABLE(1), .BAUD_WIDTH(baud_width)) MrTalky(
        .clk(pllclk), .rst_n(rst_n),
        .baud_div(bauddiv), .uart_tx_start(uart_tx_start), .uart_tx_data_in(uart_tx_data_in),
        .uart_tx_pin(uart_tx), .uart_tx_fifo_empty(uart_tx_fifo_empty), .uart_tx_fifo_full(uart_tx_fifo_full),
        .uart_rx_pin(uart_rx), .uart_rx_read(uart_rx_read), .uart_rx_ready(uart_rx_ready), .uart_rx_byte(uart_rx_byte));

    reg [7:0] nc_data_in;
    reg [SRAM_ADDR_WIDTH-1:0] nc_data_addr;
    reg nc_data_wr_en;
    wire [7:0] nc_data_out;
    reg nc_valid;
    wire nc_ready;
    wire nc_idle;

    wire [3:0] sio_din;
    wire [3:0] sio_dout;
    wire       sio_en;

    assign sio     = sio_en ? sio_dout : 4'bzzzz;
    assign sio_din = sio;

    nanocache #(
        .CACHE_SIZE(11),
        .CACHE_LINE(5),
        .SRAM_ADDR_WIDTH(SRAM_ADDR_WIDTH),
        .FREQ(FREQ/1000)) MrLocalMemory
    (
        .clk(pllclk), .rst_n(rst_n),
        .data_in(nc_data_in), .data_out(nc_data_out), .data_addr(nc_data_addr), .data_wr_en(nc_data_wr_en),
        .valid(nc_valid), .ready(nc_ready), .idle(nc_idle),
        .sio_din(sio_din), .sio_dout(sio_dout), .sio_en(sio_en), .cs_pin(cs_pin), .sck_pin(sck_pin)
    );

    reg [3:0]  test_state;
    reg [2:0]  test_cnt;
    reg        test_pass;
    reg [63:0] test_data;

    reg [3:0]  command_op;
    reg [3:0]  command_burst_len;
    reg [23:0] command_addr;
    reg        command_wr_en;
    reg [31:0] command_data;

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
        if (!rst_n) begin
            rst_n            <= 1'b1;
            rgb_r            <= 1'b1;
            rgb_g            <= 1'b1;
            rgb_b            <= 1'b1;
            uart_tx_start    <= 1'b0;
            uart_rx_read     <= 1'b0;
            nc_valid         <= 1'b0;
            test_state       <= STATE_START_COMMAND;
            test_cnt         <= 7;
            test_pass        <= 1'b0;
        end else begin
            case (test_state)
                STATE_START_COMMAND:
                    begin
                        uart_tx_start           <= 1'b0;
                        if (uart_rx_ready) begin
                            {rgb_r,rgb_g,rgb_b} <= 3'b110; // blue == RX started
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
                        uart_rx_read    <= 1'b0;
                        uart_tx_data_in <= uart_rx_byte;
//                        uart_tx_start   <= 1'b1;
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
                        {rgb_r,rgb_g,rgb_b} <= 3'b001; // yellow == running command
                        command_op        <= test_data[63:60];
                        command_burst_len <= test_data[59:56];
                        command_addr      <= test_data[55:32];
                        command_data      <= test_data[31:0];
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
                STATE_WRITE:
                    begin
                        {rgb_r,rgb_g,rgb_b} <= 3'b100; // cyan == write
						nc_valid   <= (command_burst_len != 0) ? nc_valid : 1'b0;   // We need to stop writing before the first ready if 1 byte stride
						nc_data_in <= command_data[31:24];							// this is so data_in is set for when ready goes high first
						if (!nc_valid & nc_idle) begin								// only program job once
							nc_valid      <= 1'b1;
							nc_data_wr_en <= 1'b1;
							nc_data_in    <= command_data[31:24];
							nc_data_addr  <= command_addr;
							command_data  <= { command_data[23:0], 8'b0 };
						end
						if (nc_ready) begin											// ready strobe
							// every cycle this is high we shift command_data
							command_data      <= { command_data[23:0], 8'b0 };		// shift data up
							nc_data_in        <= command_data[23:16];				// by the first ready we've already processed the 2nd byte so load the third onwards
							command_burst_len <= command_burst_len - 1'b1;
							if (command_burst_len == 0) begin
								test_state <= STATE_PASS;                           // jump to start when done last byte
							end
							if (command_burst_len == 1) begin
								nc_valid   <= 1'b0;                                 // turn off valid one cycle EARLY to avoid over-writing past the burst
							end
						end
                    end
                STATE_READ:
                    begin
                        {rgb_r,rgb_g,rgb_b} <= 3'b010; // purple == read
						nc_valid <= (command_burst_len != 0) ? nc_valid : 1'b0;
						if (!nc_valid & nc_idle) begin
							nc_valid      <= 1;
							nc_data_wr_en <= 0;
							nc_data_addr  <= command_addr;
						end
						if (nc_ready) begin
							command_data      <= {command_data[23:0], 8'b0};
							command_burst_len <= command_burst_len - 1'b1;
							if (command_burst_len == 0) begin
								test_state <= STATE_PASS;					// jump to start on last byte
							end
							if (command_burst_len == 1) begin
								nc_valid   <= 1'b0;                                 // turn off valid one cycle EARLY to avoid over-writing past the burst
							end
							// every cycle this is high we have data
							if (nc_data_out !== command_data[31:24]) begin
								test_state <= STATE_HALT;
								nc_valid   <= 1'b0;
							end
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
                        {rgb_r,rgb_g,rgb_b} <= { test_pass, ~test_pass, 1'b1 }; // red == fail, green == pass
                        if (!uart_tx_fifo_full) begin
                            uart_tx_start <= 1'b1;
                            uart_tx_data_in <= test_pass ? 8'hBB : 8'h55;
                        end
                    end
            endcase
        end
    end
endmodule