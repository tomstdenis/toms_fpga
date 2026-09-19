#ifndef LT1000_REGS_H
#define LT1000_REGS_H

// MCFG
#define MCFG_DATA           *((volatile uint32_t *)0x10000000)
// Clock rate in MHz
#define MCFG_FREQ_MHZ(x) (((x) >> 24) & 0xFF)
// SOC revision
#define MCFG_SOC_REV(x)  (((x) >> 16) & 0xFF)
// TCM bits (TCM is 2**TCM_BITS bytes long)
#define MCFG_TCM_BITS(x) (((x) >> 8) & 0xFF)

// GPIO
// 32 GPIO lanes
#define GPIO_DATA           *((volatile uint32_t *)0x10000004)
// Output Enable (1 == Output, 0 == Input)
#define GPIO_OE             *((volatile uint32_t *)0x10000008)
// Write-One-Set (1 bit == set lane high, 0 bit == leave unchanged)
#define GPIO_W1S            *((volatile uint32_t *)0x1000000C)
// Write-One-Clear (1 bit == set lane low, 0 bit == leave unchanged)
#define GPIO_W1C            *((volatile uint32_t *)0x10000010)
// Write-One-Toggle (1 bit == toggle lane, 0 bit == leave unchanged)
#define GPIO_W1T            *((volatile uint32_t *)0x10000014)

// UART
#define UART_DATA           *((volatile uint32_t *)0x10000018)
#define UART_STATUS         *((volatile uint32_t *)0x1000001C)
#define UART_STATUS_TX_FULL  1
#define UART_STATUS_TX_EMPTY 2
#define UART_STATUS_RX_READY 4

// VGA
#define VGA_CTRL            *((volatile uint32_t *)0x10000020)
// 1 == Video (320x200x8bpp), 0 = 80x25 Text
#define VGA_CTRL_GFX_MODE    1
// Which 64KB half of VRAM should be displayed (0=0x00000, 1=0x10000)
#define VGA_CTRL_PAGE_SEL    2
// High when in H blank region
#define VGA_CTRL_HBLANK      4
// High when in V blank region
#define VGA_CTRL_VBLANK      8

// SPI
//                  write   |   read         |
// bits 7 -  0  | MOSI_byte | MISO_byte      |
//      11-  8  | SCK div   | [8] == Ready   | Divides core clock by 2 * (div + 1)
//      12- 12  | CS @start | 0              | CS value at start of transfer
//      13- 13  | CS @end   | 0              | CS value at end of transfer
//      15- 14  | CS select | 0              | CS pin select (2 bits)
//      16- 16  | valid     | 0              | Command is valid
#define SPI_TRANSFER        *((volatile uint32_t *)0x10000024)

// TIMER (32-bit Cycle Counter)
#define TIMER               *((volatile uint32_t *)0x10000028)

// Fixed point Multiplication
// SCALER determines right shift count *8 (e.g. 00=0,01==8,10==16,11==24)
#define MULT_SCALER         *((volatile uint32_t *)0x1000002C)
// lower 32 bits of input
#define MULT_IN_LO          *((volatile uint32_t *)0x10000030)
// upper 32 bits of input
#define MULT_IN_HI          *((volatile uint32_t *)0x10000034)
// lower 32 bits of output (post shift)
#define MULT_OUT_LO         *((volatile uint32_t *)0x10000038)
// upper 32 bits of output (post shift)
#define MULT_OUT_HI         *((volatile uint32_t *)0x1000003C)

#endif
