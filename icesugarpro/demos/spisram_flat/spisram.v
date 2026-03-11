/*
	Realllly simple SPI FIFO SRAM demo, does a write then read.  Raises 'good' pin to high if successful.

*/
module top(input clk, inout [3:0] sio, output cs, output sck, output reg good, input uart_rx, output uart_tx);

	localparam
		DATA_WIDTH = `BITS,
		SRAM_ADDR_WIDTH = 16;
    wire sram_done;
    reg [DATA_WIDTH-1:0] sram_data_in;
    reg sram_data_in_valid;
    wire [DATA_WIDTH-1:0] sram_data_out;
    reg [3:0] sram_data_be;

    reg sram_write_cmd;
    reg sram_read_cmd;
    reg [15:0] sram_address;
    reg [3:0] rstcnt = 4'b0;
    wire rst_n;
    assign rst_n = rstcnt[3];
    wire pll_clk;
	wire pll_locked;

	pll1 pll(.clkin(clk), .clkout0(pll_clk), .locked(pll_locked));
	
	wire rx_data;
	wire rx_clk;
	wire tx_data;
	wire tx_clk;
	
	reg [(DATA_WIDTH+7):0] debug_outgoing_data;
	wire debug_outgoing_tgl;
	reg prev_debug_outgoing_tgl;
	wire [(DATA_WIDTH+7):0] debug_incoming_data;
	wire debug_incoming_tgl;
	reg prev_debug_incoming_tgl;
	reg [(DATA_WIDTH+7):0] debug_identity;
	
	serial_debug #(.BITS((DATA_WIDTH+8)), .ENABLE(1)) debug_node(
		.clk(pll_clk), .rst_n(rst_n),
		.prescaler(2),
		.rx_data(rx_data), .rx_clk(rx_clk),
		.tx_data(tx_data), .tx_clk(tx_clk),
		.debug_outgoing_data(debug_outgoing_data), .debug_outgoing_tgl(debug_outgoing_tgl),
		.debug_incoming_data(debug_incoming_data), .debug_incoming_tgl(debug_incoming_tgl),
		.identity(debug_identity));

	wire [15:0] uart_bauddiv = 50_000_000 / 115_200;

	serial_debug_uart #(.BITS((DATA_WIDTH+8)), .ENABLE(1)) debug_uart(
		.clk(pll_clk), .rst_n(rst_n),
		.prescaler(2),
		.debug_tx_clk(tx_clk), .debug_tx_data(tx_data),
		.debug_rx_clk(rx_clk), .debug_rx_data(rx_data),
		.uart_bauddiv(uart_bauddiv), .uart_rx_pin(uart_rx), .uart_tx_pin(uart_tx));

    always @(posedge pll_clk) begin
		if (pll_locked) begin
			rstcnt <= {rstcnt[2:0], 1'b1};
		end
    end

`define USE_23LC512

    spi_sram_flat
    #(
`ifdef USE_23LC512
            .DATA_WIDTH(DATA_WIDTH), .CLK_FREQ_MHZ(50), .SRAM_ADDR_WIDTH(SRAM_ADDR_WIDTH),
            .DUMMY_BYTES(1), .CMD_READ(8'h03), .CMD_WRITE(8'h02), .CMD_EQIO(8'h38),
            .MIN_CPH_NS(50), .SPI_TIMER_BITS(1), .QPI_TIMER_BITS(1)                     // divide by 2 to get 37.5MHz clock
`else
            .DATA_WIDTH(DATA_WIDTH), .CLK_FREQ_MHZ(50), .SRAM_ADDR_WIDTH(SRAM_ADDR_WIDTH),
            .DUMMY_BYTES(6), .CMD_READ(8'hEB), .CMD_WRITE(8'h38), .CMD_EQIO(8'h35),
            .MIN_CPH_NS(50), .SPI_TIMER_BITS(1), .QPI_TIMER_BITS(1)
`endif  
    ) test_sram(
        .clk(pll_clk),
        .rst_n(rst_n),
        .done(sram_done),
        .data_in(sram_data_in),
        .data_in_valid(sram_data_in_valid), 
        .data_be(sram_data_be),
        .data_out(sram_data_out),
        .write_cmd(sram_write_cmd),
        .read_cmd(sram_read_cmd),
        .address(sram_address),
        .sio_pin(sio), .cs_pin(cs), .sck_pin(sck));

    reg [2:0] state;
    reg [2:0] tag;

    localparam
        STATE_ISSUE_WRITE = 1,
        STATE_ISSUE_READ = 2,
        STATE_COMPARE_READ = 3,
        STATE_SUCCESS = 4,
        STATE_FAILURE = 5,
        STATE_WAIT_DONE = 6,
        STATE_DELAY=7;

    always @(posedge pll_clk) begin
        if (!rst_n) begin
            // these must be initialized in reset
            sram_data_in_valid <= 0;
            sram_data_out_read <= 0;
            sram_write_cmd <= 0;
            sram_read_cmd <= 0;
            sram_data_in <= 0;
            sram_address <= 0;
            sram_data_be <= 4'b1111;
            state <= STATE_WAIT_DONE;
            tag <= STATE_ISSUE_WRITE;
            good <= 0;
            debug_outgoing_data <= 0;
            prev_debug_incoming_tgl <= 0;
            prev_debug_outgoing_tgl <= 0;
            debug_identity <= 'hFF000001;
        end else begin
			debug_outgoing_data <= { sram_data_out, 1'b0, sram_done, tag, state };
            case(state)
                STATE_DELAY: state <= STATE_WAIT_DONE;
                STATE_WAIT_DONE:
                    begin
                        sram_data_in_valid <= 0;
                        sram_write_cmd <= 0;
                        sram_read_cmd <= 0;
                        if (sram_done) begin
                            state <= tag;
                        end
                    end
                STATE_ISSUE_WRITE:
                    begin
                        sram_data_be <= 4'b1111;
                        sram_address <= 'h001234;
                        sram_data_in <= 'h12345678;
                        sram_data_in_valid <= 1;
                        sram_write_cmd <= 1;
                        tag <= STATE_ISSUE_READ;
                        state <= STATE_WAIT_DONE;
                    end
                STATE_ISSUE_READ:
                    begin
                        sram_read_cmd <= 1;
                        sram_data_be <= 4'b1111;
                        sram_address <= 'h001234;
                        tag <= STATE_COMPARE_READ;
                        state <= STATE_WAIT_DONE;
                    end
                STATE_COMPARE_READ:
                    begin
                        if (sram_data_out == 'h12345678) begin
                            state <= STATE_SUCCESS;
							good <= 1'b1;
                        end else begin
                            state <= STATE_FAILURE;
                            good <= 1'b0;
                        end
                    end
                default: begin end
            endcase
        end         
    end
endmodule
