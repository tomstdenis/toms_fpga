# Verilog VGA Text & Graphics Controller

### Overview

A robust, dual-clock VGA video engine written in Verilog, designed for 32-bit softcore processors (like the PicoRV32). It outputs a standard 640x480@60Hz timing signal (requiring a 25.170 MHz pixel clock) but renders a centered 640x400 active display area. It features 64KB of embedded video RAM and supports both a classic PC-style 16-color text mode and a retro 8-bit graphics mode.

### System Architecture

* **Dual Clock Domains:** Completely decoupled `host_clk` (for CPU/bus integration) and `vga_clk` (for precise pixel timing).
* **Pipelined Host Memory:** Host memory reads are fully registered on `host_clk`. The extra cycle of read latency allows the Place & Route (PnR) tool to break long routing paths, enabling high system clock speeds ($F_{max}$).
* **64KB Embedded VRAM:** Inferred as 32 block RAMs arranged in four parallel byte-lanes, maximizing FPGA routing speed.
* **Sync & Blanking Exports:** Provides active-high `vga_v_blank` and `vga_h_blank` signals for tearing-free CPU frame updates and timer interrupts.

---

### Module Port Interface

```verilog
module vga (
    // Clock & Control Inputs
    input wire        vga_clk,          // VGA dot clock (25.170 MHz)
    input wire        host_clk,         // Host system clock
    input wire        rst_n,            // Active-low reset
    input wire        video_mode,       // 0: 80x25 Text Mode, 1: 320x200 Graphics Mode
    
    // Host Access Interface (32-bit Pipelined)
    input wire [15:0] host_addr,        // Memory address (DWORD aligned)
    input wire [31:0] host_data_in,     // Data to write LSB-first
    input wire [3:0]  host_write_mask,  // Byte-lane write enable mask
    output reg [31:0] host_data_out,    // Data read from VRAM (Registered output)
    
    // VGA Physical Pin Outputs
    output reg [3:0]  vga_r,            // 4-bit Red DAC channel
    output reg [3:0]  vga_g,            // 4-bit Green DAC channel
    output reg [3:0]  vga_b,            // 4-bit Blue DAC channel
    output reg        vga_v_pulse,      // Active-low Vertical Sync
    output reg        vga_h_pulse,      // Active-low Horizontal Sync

    // Status Signals
    output wire       vga_v_blank,      // Active-high Vertical Blanking
    output wire       vga_h_blank       // Active-high Horizontal Blanking
);

```

---

### Video Modes

#### Mode 0: 80x25 Text Mode (`video_mode = 0`)

* Displays hardware-doubled 8x16 characters using a built-in 8x8 IBM CP437 font ROM.
* **CGA-Style Attributes:** Uses 2 bytes per character cell (4,000 bytes total per frame).
* **Byte 0:** ASCII Character Code.
* **Byte 1:** Color Attribute (`IRGBirgb` — Foreground / Background).



#### Mode 1: 320x200 Graphics Mode (`video_mode = 1`)

* Hardware pixel-doubling (horizontally and vertically) to fill the 640x400 active display area with crisp, square pixels.
* **8-bit Color (3-3-2 RGB):** Maps bits `[7:5]` to Red (3-bit), `[4:2]` to Green (3-bit), and `[1:0]` to Blue (2-bit), expanded dynamically across the 12-bit output pins.

---

### Host Interface & Memory Mapping

* **32-Bit Access:** Designed for 32-bit SoC buses. `host_addr` expects DWORD-aligned byte addresses (`host_addr[15:2]`).
* **Byte Lane Masking:** Individual bytes within a 32-bit word can be written independently using `host_write_mask`.
* **VRAM Budgeting:** The 64KB frame buffer easily accommodates a full 320x200 8bpp frame (64,000 bytes) or up to 16 instantly-swappable 80x25 text pages (4,000 bytes each) for fast software screen swapping.