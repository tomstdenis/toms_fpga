// Little Timmy 1000 SOC
`default_nettype none

module lt100soc
#(
    // *** SOC parameters ***
    parameter CORE_FREQ_KHZ   = 50_000,         // 50MHz default core clock
    parameter CACHE_SIZE_BITS = 12,             // 8KB cache for PSRAM region
    parameter TCM_SIZE_BITS   = 15,             // 32KB TCM region

    // *** UART parameters ***
    parameter UART_BAUD       = 230_400,
    parameter UART_FIFO_DEPTH = 64,
)
(
    // *** Clocks ***
    input  wire       core_clk,                  // The clock for the CPU
    input  wire       vga_clk,                   // The clock for the VGA
    input  wire       rst_n,

    // *** VGA output ***
    output wire [3:0] vga_r,                     // VGA red channel
    output wire [3:0] vga_g,                     // VGA green channel
    output wire [3:0] vga_b,                     // VGA blue channel
    output wire       vga_v_pulse,               // VGA vertical blank pulse
    output wire       vga_h_pulse,               // VGA horizontal blank pulse

    // *** PSRAM ***
    input wire [3:0]  psram_sio_din,             // PSRAM QPI output
    output wire [3:0] psram_sio_dout,            // PSRAM QPI input
    output wire       psram_sio_en,              // PSRAM output enable for QPI
    output wire       psram_cs_pin,              // PSRAM CS pin
    output wire       psram_sck_pin,             // PSRAM SCK pin

    // *** SPI ***
    input wire        spi_miso_pin,              // SPI MISO pin
    output reg        spi_mosi_pin,              // SPI MOSI pin
    output reg        spi_sck_pin,               // SPI SCK  pin
    output reg [3:0]  spi_cs_pin,                // SPI CS   pin

    // *** GPIO ***
    input wire [31:0] gpio_din,                  // GPIO data output
    output reg [31:0] gpio_dout,                 // GPIO data input
    output reg [31:0] gpio_oe,                   // GPIO output enable

    // *** UART ***
    input wire        uart_rx,                   // UART RX pin
    output wire       uart_tx                    // UART TX pin
);

// memory addressing 
localparam 
    // regions (one hot selector)
    MEM_16M_BIOS  = 24,
    MEM_16M_TCM   = 25,
    MEM_16M_VGA   = 26,
    MEM_16M_PSRAM = 27,
    MEM_16M_MMIO  = 28,

    // MMIO address (lower 8 bits)
    MEM_MMIO_MCFG         = 8'h00,
    MEM_MMIO_GPIO_DOUT    = 8'h04,
    MEM_MMIO_GPIO_DIN     = 8'h08,
    MEM_MMIO_GPIO_OE      = 8'h0C,
    MEM_MMIO_GPIO_SET     = 8'h10,
    MEM_MMIO_GPIO_CLEAR   = 8'h14,
    MEM_MMIO_GPIO_TOGGLE  = 8'h18,
    MEM_MMIO_UART_DATA    = 8'h1C,
    MEM_MMIO_UART_STATUS  = 8'h20,
    MEM_MMIO_VGA_CTRL     = 8'h24,
    MEM_MMIO_SPI_TRANSFER = 8'h28;

// *** BIOS ***
    reg [7:0] bios_lane_0[0:2047];
    reg [7:0] bios_lane_1[0:2047];
    reg [7:0] bios_lane_2[0:2047];
    reg [7:0] bios_lane_3[0:2047];
    wire [11:0] bios_mem_addr;
    reg [7:0] bios_mem_dout0;
    reg [7:0] bios_mem_dout1;
    reg [7:0] bios_mem_dout2;
    reg [7:0] bios_mem_dout3;
    reg [7:0] bios_mem_dout0_tmp;
    reg [7:0] bios_mem_dout1_tmp;
    reg [7:0] bios_mem_dout2_tmp;
    reg [7:0] bios_mem_dout3_tmp;
    always @(posedge core_clk) begin
        bios_mem_dout0_tmp <= bios_lane_0[bios_mem_addr];
        bios_mem_dout1_tmp <= bios_lane_1[bios_mem_addr];
        bios_mem_dout2_tmp <= bios_lane_2[bios_mem_addr];
        bios_mem_dout3_tmp <= bios_lane_3[bios_mem_addr];
        bios_mem_dout0     <= bios_mem_dout0_tmp;
        bios_mem_dout1     <= bios_mem_dout1_tmp;
        bios_mem_dout2     <= bios_mem_dout2_tmp;
        bios_mem_dout3     <= bios_mem_dout3_tmp;
    end
    initial begin
`include "../bios/bios_lane0.vh"
`include "../bios/bios_lane1.vh"
`include "../bios/bios_lane2.vh"
`include "../bios/bios_lane3.vh"
    end

// *** TCM ***
    reg [7:0] tcm_lane0[0:(1<<(TCM_SIZE_BITS-2))-1];
    reg [7:0] tcm_lane1[0:(1<<(TCM_SIZE_BITS-2))-1];
    reg [7:0] tcm_lane2[0:(1<<(TCM_SIZE_BITS-2))-1];
    reg [7:0] tcm_lane3[0:(1<<(TCM_SIZE_BITS-2))-1];
    reg [7:0] tcm_dout0;
    reg [7:0] tcm_dout1;
    reg [7:0] tcm_dout2;
    reg [7:0] tcm_dout3;
    reg [7:0] tcm_dout0_tmp;
    reg [7:0] tcm_dout1_tmp;
    reg [7:0] tcm_dout2_tmp;
    reg [7:0] tcm_dout3_tmp;
    reg [7:0] tcm_din0;
    reg [7:0] tcm_din1;
    reg [7:0] tcm_din2;
    reg [7:0] tcm_din3;
    reg [3:0] tcm_wren;
    wire [TCM_SIZE_BITS-1:0] tcm_addr;
    always @(posedge core_clk) begin
        if (tcm_wren[0]) begin
            tcm_lane0[tcm_addr] <= tcm_din0;
        end else begin
            tcm_dout0_tmp <= tcm_lane0[tcm_addr];
            tcm_dout0     <= tcm_dout0_tmp;
        end
        if (tcm_wren[1]) begin
            tcm_lane1[tcm_addr] <= tcm_din1;
        end else begin
            tcm_dout1_tmp <= tcm_lane1[tcm_addr];
            tcm_dout1     <= tcm_dout1_tmp;
        end
        if (tcm_wren[2]) begin
            tcm_lane2[tcm_addr] <= tcm_din2;
        end else begin
            tcm_dout2_tmp <= tcm_lane2[tcm_addr];
            tcm_dout2     <= tcm_dout2_tmp;
        end
        if (tcm_wren[3]) begin
            tcm_lane3[tcm_addr] <= tcm_din3;
        end else begin
            tcm_dout3_tmp <= tcm_lane3[tcm_addr];
            tcm_dout3     <= tcm_dout3_tmp;
        end
    end

// *** VGA ***
    reg vga_video_mode;
    reg vga_page_sel;
    wire [16:0] vga_host_addr;
    wire [31:0] vga_data_in;
    wire [3:0]  vga_wren;
    wire [31:0] vga_data_out;

    vga vga(
        .vga_clk(vga_clk), .host_clk(core_clk), .rst_n(rst_n),
        .video_mode(vga_video_mode), .page_sel(vga_page_sel),
        .host_addr(vga_host_addr), .host_data_in(vga_data_in),
        .host_write_mask(vga_wren), .host_data_out(vga_data_out),
        .vga_r(vga_r), .vga_g(vga_g), .vga_b(vga_b), .vga_v_blank(vga_v_pulse),
        .vga_h_blank(vga_h_pulse)
    );

// *** UART ***
    localparam
        BAUD_DIV   = (CORE_FREQ_KHZ * 1000) / UART_BAUD,
        BAUD_WIDTH = $clog2(BAUD_DIV);

    wire [BAUD_WIDTH-1:0] uart_baud = BAUD_DIV;
    reg        uart_tx_start;
    reg [7:0]  uart_tx_data_in;
    wire       uart_tx_fifo_full;
    wire       uart_tx_fifo_empty;
    reg        uart_rx_read;
    wire       uart_rx_ready;
    wire [7:0] uart_rx_byte;

    uart #(
        .FIFO_DEPTH(UART_FIFO_DEPTH), .RX_ENABLE(1), .TX_ENABLE(1), .BAUD_WIDTH(BAUD_WIDTH)
    ) uart (
        .clk(core_clk), .rst_n(rst_n), .baud_div(uart_baud),
        .uart_tx_start(uart_tx_start), .uart_tx_data_in(uart_tx_data_in),
        .uart_tx_pin(uart_tx), .uart_tx_fifo_full(uart_tx_fifo_full),
        .uart_tx_fifo_empty(uart_tx_fifo_empty), .uart_rx_pin(uart_rx),
        .uart_rx_read(uart_rx_read), .uart_rx_ready(uart_rx_ready),
        .uart_rx_byte(uart_rx_byte)
    );

endmodule

`include "picorv32/picorv32.v"
`include "../../uart/blocks/uart.v"
`include "../../uart/blocks/tx_uart.v"
`include "../../uart/blocks/rx_uart.v"
`include "../../nanocache/nanocache.v"
`include "../../nanocache/refmem.v"
`include "../../nanosram/nanosram.v"
`include "../../vga/blocks/vga.v"
`include "../../timer/blocks/timer.v"