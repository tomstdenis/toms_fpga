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
// PSRAM size in MiB
#define MCFG_PSRAM_MIB(x) ((x) & 0xFF)

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
// When this is set any hot pink (0xE3) byte written over the bus is masked off allowing for transparent writes
#define VGA_CTRL_WRITE_MASK  4
// High when in H blank region
#define VGA_CTRL_HBLANK      8
// High when in V blank region
#define VGA_CTRL_VBLANK      16

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

// FPU
// left hand side input
#define FPU_IN_A            *((volatile float *)0x1000002C)
// right hand side input
#define FPU_IN_B            *((volatile float *)0x10000030)
// output value
#define FPU_OUT             *((volatile float *)0x10000034)
#define FPU_OUT_RAW         *((volatile uint32_t *)0x10000034)
#define FPU_CTRL            *((volatile uint32_t *)0x10000038)
// This value when written starts a job, when you're reading you test for this value.
#define FPU_CTRL_VALID      1
// opcodes 
#define FPU_CTRL_OP_FADD    (0<<1)
#define FPU_CTRL_OP_FSUB    (1<<1)
#define FPU_CTRL_OP_FMUL    (2<<1)
#define FPU_CTRL_OP_FDIV    (3<<1)
#define FPU_CTRL_OP_FLDI    (4<<1)
#define FPU_CTRL_OP_FSTI    (5<<1)
#define FPU_CTRL_OP_FSQRT   (6<<1)
// output is 4 - EQ, 2 - LT, 1 - GT
#define FPU_CTRL_OP_FCMP    (7<<1)
// these are packed 8 or 16 bit saturated add or subtractions.
#define FPU_CTRL_OP_IADD_8ADD (8<<1)
#define FPU_CTRL_OP_IADD_8SUB (9<<1)
#define FPU_CTRL_OP_IADD_16ADD (10<<1)
#define FPU_CTRL_OP_IADD_16SUB (11<<1)
#define FPU_CTRL_OP_NOP     (15<<1)
// set this at the same time you set FPU_CTRL_OP_* and all writes to FPU_IN_B will auto
// fire a job without needing to write to FPU_CTRL to start a job.
#define FPU_CTRL_AUTO_FIRE  (1<<5)

// outputs of FCMP
#define FPU_LT               1
#define FPU_GT               2
#define FPU_EQ               4

// you can program a [say] FMUL job by
// writing left hand side to to FPU_IN_A
// writing right hand side to to FPU_IN_B
// writing FPU_CTRL_VALID | FPU_CTRL_OP_FMUL to FPU_CTRL
// poll FPU_CTRL & 1 until non-zero
// read FPU_OUT to get the result

#endif
