#ifndef LT1000_REGS_H
#define LT1000_REGS_H

// MCFG
#define MCFG_DATA           *((volatile uint32_t *)0x10000000)
#define MCFG_FREQ_KHZ(x) ((x) & 0xFFF)
#define MCFG_TCM_BITS(x) (((x) >> 15) & 0x1F)
#define MCFG_SOC_REV(x)  (((x) >> 20) & 0xFF)

// GPIO
#define GPIO_DATA           *((volatile uint32_t *)0x10000004)
#define GPIO_OE             *((volatile uint32_t *)0x10000004)
#define GPIO_W1S            *((volatile uint32_t *)0x10000008)
#define GPIO_W1C            *((volatile uint32_t *)0x1000000C)
#define GPIO_W1T            *((volatile uint32_t *)0x10000010)

// UART
#define UART_DATA           *((volatile uint32_t *)0x10000018)
#define UART_STATUS         *((volatile uint32_t *)0x1000001C)
#define UART_STATUS_TX_FULL  1
#define UART_STATUS_TX_EMPTY 2
#define UART_STATUS_RX_READY 4

// VGA
#define VGA_CTRL            ((volatile uint32_t *)0x10000020)
#define VGA_CTRL_GFX_MODE    1
#define VGA_CTRL_PAGE_SEL    2
#define VGA_CTRL_VBLANK      4
#define VGA_CTRL_HBLANKL     8

// SPI
#define SPI_TRANSFER        *((volatile uint32_t *)0x10000024)

// TIMER
#define TIMER               *((volatile uint32_t *)0x10000028)

#endif
