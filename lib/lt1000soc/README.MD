# Little Timmy 1000 SOC

## Introduction
The Little Timmy 1000 SOC is a system on chip module that combines various blocks into a single module that can be used with vendor specific I/O buffers and PLL blocks to make a fully elaboratable design

## Configuration

- Tightly Coupled data/code memory (default: **32KB**)
- Cacheable PSRAM region upto 128Mbit (default: **4KB cache**)
- VGA with 80x25 colour and 320x200 8bpp (default: **128KB VRAM**, **both modes**)
- UART Serial Port (default: **64 deep FIFO**, **230.4Kbaud**)
- 32-bit GPIO with individual output enable
- Four chip single channel SPI master with configurable baud
- 8KB BIOS

## Memory Map

The memory map is split into 16MByte regions to allow for one-hot zone control.

### High level map 

```
  START        END       DESCRIPTION
0100_0000 - 0100_1FFF -- 8KB ROM BIOS
0200_0000 - 0200_7FFF -- 32KB (*) TCM
0400_0000 - 0401_FFFF -- 128KB VGA memory
0800_0000 - 08xx_xxxx -- PSRAM region
1000_0000 - 10xx_xxxx -- MMIO region
```

(*): TCM region is as small as 32KB and can be as large as you're crazy enough.

### MMIO Memory Map

```
1000_0000 - Machine Config
                - [11:0]   Core Clock (*10)
                - [19:15]  TCM log2 size

1000_0004 - GPIO DATA OUT
1000_0008 - GPIO DATA IN
1000_000C - GPIO OE
1000_0010 - GPIO (W1S) SET
1000_0014 - GPIO (W1C) CLEAR
1000_0018 - GPIO (W1T) TOGGLE

1000_001C - UART DATA
1000_0020 - UART STATUS
                - [0]     TX FIFO Full
                - [1]     TX FIFO Empty
                - [2]     RX READ Ready

1000_0024 - VGA CTRL
                - [0]     Video mode (0 == Text Mode, 1 == 320x200 Mode)
                - [1]     Page Select (0 == First 64KB, 1 == Second 64KB)

1000_0028 - SPI TRANSFER
                - [7:0]   MOSI/MISO byte
                - [15:8]  SPI Tick per SCK
                - [17:16] CS Pin Selector
                - [18]    CS Pin value at start
                - [19]    CS Pin value at end
```

## TBD
