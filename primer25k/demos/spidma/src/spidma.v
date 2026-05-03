/*

Setup to use the right most PMOD header (J4).

*/
module top(input wire clk, inout wire [3:0] sio, output wire cs, output wire sck, input wire uart_rx, output wire uart_tx);

	localparam
        FREQ = 50,
		SRAM_ADDR_WIDTH = 24,
        HOST_MEM_ADDR = 11;

    reg [3:0] rstcnt = 4'b0;
    wire rst_n;
    assign rst_n = rstcnt[3];
    wire pll_clk;

    Gowin_PLL pll(
        .clkin(clk), //input  clkin
        .clkout0(pll_clk) //output  clkout0
    );
    always @(posedge pll_clk) begin
		rstcnt <= {rstcnt[2:0], 1'b1};
    end

    // *** UART ***
	wire [15:0] uart_bauddiv = FREQ * 1_000_000 / 1_000_000;
    reg uart_tx_start;
    reg [7:0] uart_tx_data_in;
    wire uart_tx_fifo_full;
    wire uart_tx_fifo_empty;
    reg uart_rx_read;
    wire uart_rx_ready;
    wire [7:0] uart_rx_byte;

    uart mrtalky(
        .clk(pll_clk), .rst_n(rst_n), .baud_div(uart_bauddiv),
        .uart_tx_start(uart_tx_start), .uart_tx_pin(uart_tx),
        .uart_tx_data_in(uart_tx_data_in), .uart_tx_fifo_empty(uart_tx_fifo_empty),
        .uart_tx_fifo_full(uart_tx_fifo_full),
        .uart_rx_pin(uart_rx), .uart_rx_read(uart_rx_read), .uart_rx_ready(uart_rx_ready),
        .uart_rx_byte(uart_rx_byte));

    // *** Host Memory ***
    reg host_memory_wr_en;
    reg [HOST_MEM_ADDR-1:0] host_memory_addr;
    reg [7:0] host_memory_data_in;
    wire [7:0] host_memory_data_out;

    wire spi_memory_wr_en;
    wire [HOST_MEM_ADDR-1:0] spi_memory_addr;
    wire [7:0] spi_memory_data_in;
    wire [7:0] spi_memory_data_out;

    Gowin_DPB host_memory(
        .clka(pll_clk), //input clka
        .ocea(1'b1), //input ocea
        .cea(1'b1), //input cea
        .reseta(~rst_n), //input reseta
        .wrea(host_memory_wr_en), //input wrea
        .ada(host_memory_addr), //input [10:0] ada
        .dina(host_memory_data_in), //input [7:0] dina
        .douta(host_memory_data_out), //output [7:0] douta

        .clkb(pll_clk), //input clkb
        .oceb(1'b1), //input oceb
        .ceb(1'b1), //input ceb
        .resetb(~rst_n), //input resetb
        .wreb(spi_memory_wr_en), //input wreb
        .adb(spi_memory_addr), //input [10:0] adb
        .dinb(spi_memory_data_in), //input [7:0] dinb
        .doutb(spi_memory_data_out) //output [7:0] doutb
    );

    // *** SPI DMA ***
    wire spidma_ready;
    reg [3:0] spidma_cmd_value;
    reg spidma_cmd_valid;
    reg [SRAM_ADDR_WIDTH-1:0] spidma_cmd_spi_address;
    reg [10:0] spidma_cmd_host_address;
    reg [7:0] spidma_cmd_burst_len;

    // wiring to our pins from the SPI block
    wire [3:0] sio_din;
    wire [3:0] sio_dout;
    wire sram_sck;
    wire sram_cs;
    wire [3:0] sio_en;
    
    // either output to sio or set to high impedence state
    assign sio[0] = sio_en[0] ? sio_dout[0] : 1'bz;
    assign sio[1] = sio_en[1] ? sio_dout[1] : 1'bz;
    assign sio[2] = sio_en[2] ? sio_dout[2] : 1'bz;
    assign sio[3] = sio_en[3] ? sio_dout[3] : 1'bz;
    // sio input is always just the sio pins
    assign sio_din = sio;
    assign sck = sram_sck;
    assign cs = sram_cs;

    spidma #(
        // PSRAM configuration (Some chips allow 1 Tclk between CS low but ESP-PSRAM requires 50ns)
        .CLK_FREQ_MHZ(FREQ),
        .SRAM_ADDR_WIDTH(SRAM_ADDR_WIDTH), .HOST_MEM_ADDR(HOST_MEM_ADDR),
        .DUMMY_CYCLES(6), 
        
        .CMD_READ(8'hEB), .CMD_WRITE(8'h38), .CMD_EQIO(8'h35), .CMD_QMEX(8'hF5),
        .CMD_RESETEN(8'h66), .CMD_RESET(8'h99),

        .MIN_CPH_NS(50), .SPI_TIMER_BITS(3), .QPI_TIMER_BITS(0), .MIN_WAKEUP_NS(150_000)) sdma(
        .clk(pll_clk), .rst_n(rst_n),
        .ready(spidma_ready),
        .host_mem_addr(spi_memory_addr), .host_mem_wr_en(spi_memory_wr_en),
        .host_mem_data_in(spi_memory_data_in), .host_mem_data_out(spi_memory_data_out),
        .cmd_value(spidma_cmd_value), .cmd_valid(spidma_cmd_valid),
        .cmd_spi_address(spidma_cmd_spi_address), .cmd_host_address(spidma_cmd_host_address),
        .cmd_burst_len(spidma_cmd_burst_len),
        .sio_din(sio_din), .sio_dout(sio_dout), .sio_en(sio_en),
        .cs_pin(sram_cs), .sck_pin(sram_sck));

endmodule
