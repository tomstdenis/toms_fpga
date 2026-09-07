// Little Timmy 1000 SOC
`default_nettype none

module lt100soc
#(
    // *** SOC parameters ***
    parameter CORE_FREQ_KHZ   = 50_000,         // 50MHz default core clock
    parameter CACHE_SIZE_BITS = 13,             // 8KB cache for PSRAM region
    parameter TCM_SIZE_BITS   = 15,             // 32KB TCM region

    // *** UART parameters ***
    parameter UART_BAUD     = 230_400
)
(
    // *** Clocks ***
    input             core_clk,                  // The clock for the CPU
    input             vga_clk,                   // The clock for the VGA

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