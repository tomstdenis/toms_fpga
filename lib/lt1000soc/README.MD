# Little Timmy 1000 System-on-Chip (LT1000SoC)

The **Little Timmy 1000 (LT1000)** is a lightweight, customizable RISC-V System-on-Chip (SoC) HDL design based around the **PicoRV32** processor core. Designed for embedded applications and retro-computing hardware setups (e.g., FPGA gaming consoles and graphics systems), it integrates dual-clock domain VGA output, QPI PSRAM caching, multi-chip SPI, buffered UART, flexible GPIO with atomic set/clear/toggle operations, and modular memory layout options.

---

## Block Diagram

```text
 ┌───────────────────────────────────────────────────┐                          
 │            ┌────────────────────────────────────┐ │                          
 │ ┌────────┐ │ ┌────────┐   ┌─────────┐┌─────────┐│ │      ┌───────────┐ 
 │ │ 2x PLL │ │ │PicoRV32│   │TCM 64KB ││VGA 128KB││ ├─────►│VGA RGB444 │ 
 │ └────────┘ │ │ IM32   │   └─────────┘└─────────┘│ │      └───────────┘ 
 │ ┌────────┐ │ └────────┘   ┌─────────┐┌─────────┐│ │      ┌───────────┐ 
 │ │ IO Buf │ │              │BIOS 8KB ││Cache 8KB││ ├─────►│PSRAM 16MiB│ 
 │ └────────┘ │              └─────────┘└─────────┘│ │      └───────────┘ 
 │            │    SOC Bus                         │ │      ┌───────────┐ 
 │            │     Fabric   ┌─────────┐           │ ├─────►│SD Card/Etc│ 
 │            │              │ 4CS SPI │           │ │      └───────────┘ 
 │            │              └─────────┘           │ │                    
 │            │              ┌─────────┐           │ │                    
 │            │              │8N1 UART │           │ │                    
 │            │              └─────────┘           │ │                    
 │            └────────────────────────────────────┘ │                    
 └─────────────┬──────────┬────────────┬──────────┬──┘                    
               │          │            │          │                       
          ┌────▼───┐  ┌───▼────┐  ┌────▼───┐  ┌───▼────┐                  
          │ 8 GPIO │  │ 8 GPIO │  │ 8 GPIO │  │ 8 GPIO │                  
          └────────┘  └────────┘  └────────┘  └────────┘                  

```

---

## Architecture Overview

* **CPU Core**: 32-bit PicoRV32 RISC-V core supporting configurable RV32I / RV32IM instruction set features, fast hardware multiplication, hardware division, and configurable trap catching.
* **Memory Architecture**:
* **BIOS ROM**: Up to 8 KiB (configurable) bootloader region loaded from include vector files (`bios_lane0.vh` .. `bios_lane3.vh`).
* **Tightly Coupled Memory (TCM)**: On-chip SRAM (default 64 KiB) for fast zero-wait-state data and code execution.
* **External PSRAM Interface**: Up to 16 MiB external QPI PSRAM interfaced via a 32-bit configurable direct-mapped cache controller (`nanocache`). Automatically handles endianness conversion.
* **VGA Dedicated Memory**: 128 KiB frame buffer with dual page-flipping support.


* **Peripherals & I/O**:
* **VGA Controller**: Dual-clock domain (separate system and pixel clock domains), configurable display modes, page select, and vertical/horizontal blanking status reporting.
* **UART**: Full-duplex 8N1 UART controller with built-in hardware TX/RX FIFOs (default 64 bytes) and runtime baud-rate calculation.
* **SPI Master Interface**: Quad Chip-Select (4 CS) SPI interface with programmable clock division and transfer controls.
* **GPIO**: 32-bit bidirectionally buffered GPIO lines with full direction control and dedicated atomic **Write-1-to-Set (W1S)**, **Write-1-to-Clear (W1C)**, and **Write-1-to-Toggle (W1T)** registers.
* **Hardware Timer**: 32-bit free-running clock cycle register for precise timing and performance benchmarking.



---

## System Memory Map

The LT1000 SoC uses a one-hot high-bit address decoding bus fabric. The target region is selected using address bits `[28:24]`.

| Base Address | Region Bit | Size | Description |
| --- | --- | --- | --- |
| `0x0100_0000` | `MEM_16M_BIOS` (`bit 24`) | Configurable ($2^{\text{BIOS\_SIZE\_BITS}}$ Bytes, Default 8 KiB) | **BIOS Boot ROM** (Read-Only) |
| `0x0200_0000` | `MEM_16M_TCM` (`bit 25`) | Configurable ($2^{\text{TCM\_SIZE\_BITS}}$ Bytes, Default 64 KiB) | **On-Chip TCM RAM** (Read/Write) |
| `0x0400_0000` | `MEM_16M_VGA` (`bit 26`) | 128 KiB Address Space | **VGA Framebuffer Memory** (Read/Write) |
| `0x0800_0000` | `MEM_16M_PSRAM` (`bit 27`) | Up to 16 MiB | **External Cached PSRAM** (Read/Write) |
| `0x1000_0000` | `MEM_16M_MMIO` (`bit 28`) | 256 Bytes | **Memory-Mapped I/O Registers** |

---

## MMIO Register Interface

All peripheral registers are mapped under the MMIO base address `0x1000_0000`.

| Offset | Register Name | R/W | Description |
| --- | --- | --- | --- |
| `0x00` | `MMIO_MCFG` | R/W | Machine Configuration & Revision |
| `0x04` | `MMIO_GPIO_DATA` | R/W | GPIO Data Register (Input / Output) |
| `0x08` | `MMIO_GPIO_OE` | R/W | GPIO Output Enable Mask |
| `0x0C` | `MMIO_GPIO_W1S` | W | GPIO Write-1-to-Set Output Bits |
| `0x10` | `MMIO_GPIO_W1C` | W | GPIO Write-1-to-Clear Output Bits |
| `0x14` | `MMIO_GPIO_W1T` | W | GPIO Write-1-to-Toggle Output Bits |
| `0x18` | `MMIO_UART_DATA` | R/W | UART Transmit / Receive Data FIFO |
| `0x1C` | `MMIO_UART_STATUS` | R | UART RX/TX FIFO Status Flags |
| `0x20` | `MMIO_VGA_CTRL` | R/W | VGA Display Mode, Page Swap & Blanking Status |
| `0x24` | `MMIO_SPI_TRANSFER` | R/W | SPI Control, Clock Divider & Transfer Data |
| `0x28` | `MMIO_TIMER` | R | 32-bit Hardware Cycle Counter |

---

### Detailed Register Definitions

#### 1. Machine Configuration (`MMIO_MCFG` - `0x1000_0000`)

* **Read Format**:
* `[31:24]`: System Core Clock Frequency in MHz (`CORE_FREQ_MHZ`).
* `[23:16]`: SoC Revision Identifier (`0x00`).
* `[15:8]`: TCM Size parameter in bits (`TCM_SIZE_BITS`, e.g., `16` = 64 KiB).
* `[7:0]`: General Scratchpad / Config Register (`mmio_reg_mcfg`).


* **Write Format**: Byte 0 sets `mmio_reg_mcfg[7:0]`.

#### 2. GPIO Registers (`0x1000_0004` – `0x1000_014`)

* **`MMIO_GPIO_DATA` (`0x04`)**: Reads current 32-bit pin values (`gpio_din`). Writes set output value buffer (`gpio_dout`). Supports byte-lane masking.
* **`MMIO_GPIO_OE` (`0x08`)**: Sets pin directions. `1` = Output, `0` = High-Z Input.
* **`MMIO_GPIO_W1S` (`0x0C`)**: Writing `1` to bit $N$ sets `gpio_dout[N]` to `1`.
* **`MMIO_GPIO_W1C` (`0x10`)**: Writing `1` to bit $N$ clears `gpio_dout[N]` to `0`.
* **`MMIO_GPIO_W1T` (`0x14`)**: Writing `1` to bit $N$ toggles `gpio_dout[N]`.

#### 3. UART Interface (`0x1000_0018` – `0x1000_001C`)

* **`MMIO_UART_DATA` (`0x18`)**:
* **Write (Byte 0)**: Pushes byte `picorv_mem_wdata[7:0]` to TX FIFO.
* **Read**: Reads and pops byte from RX FIFO. Returns `0xFFFFFFFF` if no byte is available.


* **`MMIO_UART_STATUS` (`0x1C`)** *(Read-Only)*:
* `Bit 0`: `uart_tx_fifo_full`
* `Bit 1`: `uart_tx_fifo_empty`
* `Bit 2`: `uart_rx_ready` (Data available in RX FIFO)
* `[31:3]`: Reserved (`0`)



#### 4. VGA Control Register (`MMIO_VGA_CTRL` - `0x1000_0020`)

* **Read Format**:
* `Bit 0`: Current Video Mode (`cvga_video_mode`).
* `Bit 1`: Active Display Page Select (`cvga_page_sel`).
* `Bit 2`: Horizontal Blanking Status (`cvga_h_blank`).
* `Bit 3`: Vertical Blanking Status (`cvga_v_blank`).
* `[31:4]`: Reserved (`0`).


* **Write Format (Byte 0)**:
* `Bit 0`: Sets `cvga_video_mode` (0 = Standard, 1 = Alternate/High-res).
* `Bit 1`: Sets `cvga_page_sel` (Page Flipping bit).



#### 5. SPI Control & Data Register (`MMIO_SPI_TRANSFER` - `0x1000_0024`)

* **Read Format**:
* `[7:0]`: Received SPI Byte (`spi_miso_byte`).
* `Bit 8`: SPI Bus Idle Flag (`spi_idle`).
* `[31:9]`: Reserved (`0`).


* **Write Format** *(Requires 3-byte write enable, `wstrb[2:0] == 3'b111`)*:
* `[7:0]`: Data byte to transmit (`spi_mosi_byte`).
* `[11:8]`: Clock Divider (`spi_div`).
* `Bit 12`: Assert Chip Select Start (`spi_cs_start`).
* `Bit 13`: Assert Chip Select End (`spi_cs_end`).
* `[15:14]`: SPI Slave Target Select (`spi_cs_sel`):
* `00` -> CS0 active (`spi_cs_pin = 4'b1110`)
* `01` -> CS1 active (`spi_cs_pin = 4'b1101`)
* `10` -> CS2 active (`spi_cs_pin = 4'b1011`)
* `11` -> CS3 active (`spi_cs_pin = 4'b0111`)


* `Bit 16`: Trigger Transfer Valid flag (`spi_valid`).



#### 6. System Timer (`MMIO_TIMER` - `0x1000_0028`)

* **Read Format**: 32-bit hardware register that increments on every `core_clk` cycle. Writes are ignored.

---

## Module Parameters

| Parameter | Type | Default Value | Description |
| --- | --- | --- | --- |
| `CORE_FREQ_KHZ` | `int` | `50_000` | System Core Clock Frequency in kHz (50 MHz) |
| `BIOS_SIZE_BITS` | `int` | `13` | Address bit width for BIOS ROM (13 = 8 KiB) |
| `CACHE_SIZE_BITS` | `int` | `13` | Cache size in bits for external PSRAM (13 = 8 KiB) |
| `TCM_SIZE_BITS` | `int` | `16` | Bit width for internal TCM (16 = 64 KiB) |
| `SRAM_ADDR_WIDTH` | `int` | `24` | Address width for external PSRAM (24 = 16 MiB) |
| `RV_ENABLE_COUNTERS` | `bit` | `0` | Enable RV32 hardware performance counters |
| `RV_BARREL_SHIFTER` | `bit` | `1` | Enable PicoRV32 full barrel shifter |
| `RV_ENABLE_FAST_MUL` | `bit` | `1` | Enable PicoRV32 fast hardware multiplier |
| `RV_ENABLE_DIV` | `bit` | `1` | Enable PicoRV32 hardware division unit |
| `RV_PROGADDR_RESET` | `hex` | `32'h0100_0000` | CPU Boot Vector / Reset Address (Points to BIOS) |
| `RV_STACKADDR` | `hex` | `32'h0200_8000` | Initial Stack Pointer location (Located in TCM) |
| `UART_BAUD` | `int` | `1_000_000` | Target UART Baud Rate (1 Mbps) |
| `UART_FIFO_DEPTH` | `int` | `64` | Depth of UART TX and RX hardware FIFOs |

---

## Signal Pinout (Top Level Ports)

### Clocks & Reset

* `input wire core_clk`: System clock driving the CPU core, bus fabric, memory, and main peripherals.
* `input wire vga_clk`: Dedicated pixel clock input driving the VGA timing controller.
* `input wire core_rst_n`: Active-low system reset input (internally synchronized).
* `input wire vga_rst_n`: Active-low pixel reset input (internally synchronized).

### VGA Interface

* `output wire [3:0] vga_r`: Red color channel output (4-bit DAC).
* `output wire [3:0] vga_g`: Green color channel output (4-bit DAC).
* `output wire [3:0] vga_b`: Blue color channel output (4-bit DAC).
* `output wire vga_h_pulse`: VGA Horizontal Sync signal.
* `output wire vga_v_pulse`: VGA Vertical Sync signal.

### PSRAM (QPI Bus) Interface

* `input wire [3:0] psram_sio_din`: PSRAM Quad SPI Data input bus.
* `output wire [3:0] psram_sio_dout`: PSRAM Quad SPI Data output bus.
* `output wire psram_sio_en`: Tri-state enable control signal for Quad I/O pins.
* `output wire psram_cs_pin`: Active-low PSRAM Chip Select line.
* `output wire psram_sck_pin`: PSRAM Clock line.

### SPI Bus Interface

* `input wire spi_miso_pin`: SPI Master-In Slave-Out pin.
* `output wire spi_mosi_pin`: SPI Master-Out Slave-In pin.
* `output wire spi_sck_pin`: SPI Serial Clock line.
* `output reg [3:0] spi_cs_pin`: Active-low 4-line Chip Select outputs.

### General Purpose I/O (GPIO)

* `input wire [31:0] gpio_din`: 32-bit Input data lines from FPGA pad ring / buffers.
* `output reg [31:0] gpio_dout`: 32-bit Output data lines driven to FPGA pad ring.
* `output reg [31:0] gpio_oe`: 32-bit Output enable control lines (`1` = Output enable).

### Serial UART

* `input wire uart_rx`: Serial receive data input.
* `output wire uart_tx`: Serial transmit data output.

---

## Included Dependencies

The SoC top-level integrates the following submodule dependencies (via Verilog includes/instantiations):

```verilog
`include "picorv32/picorv32.v"
`include "../../uart/blocks/uart.v"
`include "../../uart/blocks/tx_uart.v"
`include "../../uart/blocks/rx_uart.v"
`include "../../nanocache/nanocache_comb_32bit.v"
`include "../../nanocache/refmem.v"
`include "../../nanosram/nanosram.v"
`include "../../vga/blocks/vga.v"
`include "../../timer/blocks/timer.v"
`include "../../spi/spi.v"

```