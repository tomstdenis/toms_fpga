# 16-bit Logic Analyzer (16bitla)

A high-performance, FPGA-based logic analyzer capable of **148.5 MHz** sampling across 16 channels, featuring advanced LUT-based temporal triggering.

## Features

* **Dual-Width Sampling**:
* **16-Channel Mode**: 32,768 samples at up to 148.5 MHz.
* **8-Channel Mode**: 65,536 samples using "double-stuffed" packing for maximum depth.
* **High Speed Architecture**: Operates at a 148.5 MHz system clock with a measured Fmax of **159.3 MHz**, providing significant thermal and timing margin.

### **Advanced Trigger Engine**:
* **Standard Mode**: Edge-sensitive triggering with bitmask and polarity matching.
* **LUT4 Static Mode**: Arbitrary 4-bit boolean logic trigger on `io[3:0]`.
* **LUT4 Temporal Mode**: Sequence detection on `io[1:0]` using current and latched states to find protocol-specific events like I2C Starts or SPI edges.  Using the format {io[1:0], previous_io[1:0]}.
* **Efficient Power Management**: Implements BRAM Clock Enable (CE) gating to reduce dynamic power consumption (approx. 660mW peak) during idle states.

## Hardware Specifications

* **FPGA**: Gowin GW2AR-18 (Tang Nano 20K).


* **Buffer**: SN74LVC541ADWR (5V tolerant) with 100Ω series termination and 10kΩ pull-downs.
* **Thermal**: Passive 7mm heatsink with ground-plane thermal dissipation.

## Command Protocol

The analyzer is controlled via a 7-byte serial packet (115,200 baud):

| Byte | Field | Description |
| --- | --- | --- |
| 0-1 | `trigger_mask` | Bitmask for edge trigger; sets 8/16ch mode (0x00FF vs 0xFFFF). |
| 2-3 | `trigger_pol` | Trigger polarity OR 16-bit Truth Table for LUT modes. |
| 4 | `prescale` | Sample clock divider. |
| 5 | `post_trigger` | Post-trigger capture depth (multiplied by 128 or 256). |
| 6 | `mode_select` | <br>**0**: Edge, **1**: Static LUT4, **2**: Temporal LUT4. |

## Software Usage

The included C tool handles configuration, data retrieval, and VCD generation.

```bash
# Compile
gcc 16bitla.c -o 16bitla

# Run a capture
./16bitla /dev/ttyUSB0 my_config.cfg

```

## Repository Structure

* `top.v`: Main FPGA logic including the dual-FSM controller and LUT trigger engine.
* `16bitla.c`: Host-side PC tool for programming the FPGA and emitting VCD files.
* `la_pll/`: Gowin rPLL configuration for the 148.5 MHz sampling clock.
