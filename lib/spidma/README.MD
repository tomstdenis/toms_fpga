# SPI DMA Controller (`spidma`)

## Overview
This module implements a hardware SPI/Quad SPI controller with host memory DMA capabilities. It manages bidirectional data transfers between a host memory system and an SPI memory (sram/psram) device, automatically handling command, address, and data phases across standard SPI and QPI (Quad SPI) modes.

```

			┌──────────────────┐                 ┌─────────────────┐          ┌──────────────────┐
			│                  │                 │                 │  cs/sck  │                  │
			│                  ├────────────────►│                 ├─────────►│                  │
			│   Host Memory    │   host_mem_*    │                 │   sio_*  │    SPI Memory    │
			│                  │◄────────────────┤                 │◄────────►┤                  │
			│                  │                 │     SPI DMA     │          │                  │
			└──────────┬───────┘                 │                 │          └──────────────────┘
					▲  │                         │                 │                              
					│  │                         │                 │                              
					│  │                         │                 │                              
					│  ▼                         └──────────┬──────┘                              
			┌───────┴──────────┐                       ▲    │                                     
			│                  │    cmd_*              │    │                                     
			│                  ├───────────────────────┘    │                                     
			│  SPI DMA Driver  │                            │                                     
			│                  │◄───────────────────────────┘                                     
			│                  │    ready                                                         
			└──────────────────┘                                                                  
```

## Key Features
- **Dual-Mode Support**: Handles both 1-bit SPI and QPI data transfer states.
- **Configurable Burst Length**: Supports data bursts from 1 to 256 bytes per transaction.
- **Automated State Machine**: Transitions through initialization, reset, command/address shifting, QPI data phases, and host memory coordination.
- **Timing Control**: Includes configurable hangup and wakeup baud rate dividers calculated from the system clock frequency `CLK_FREQ_MHZ`.
- **Simulation Support**: Contains simulation-specific logic (e.g., `sim_wr_en`) guarded by the `` `define SIM_MODEL `` macro.

## Architecture & State Machine
The core drives transaction flow using a predefined finite state machine:
- **Initialization & Reset**: `STATE_INIT` → `STATE_INIT_DONE` → `STATE_SEND_RESETEN*` → `STATE_SEND_RESET_DONE` 
- **Command/Address Phase**: `STATE_SPI_SHIFT_8` cycles through 8-bit command and address bytes.
- **QPI Data Phase**: `STATE_QPI_SEND_2` and `STATE_QPI_RECV_2` manage quad-line data transfers.
- **Host Memory Coordination**: `STATE_START_READ` and `STATE_START_WRITE` increment host addresses and decrement burst counters.
- **Termination**: `STATE_HANGUP` and `STATE_DONE` gracefully end transactions and prepare for the next command.

## Internal Registers & Signals
The following registers track transaction parameters (defined within the module):
- `cmd_value_l`: Current SPI command opcode 
- `cmd_spi_address_l`: Target address on the SPI flash device 
- `cmd_host_address_l`: Source/destination address in host memory 
- `cmd_burst_len_l`: Remaining bytes to transfer in the current burst 
- `sck_timer` & `hangup_timer`: Clock division and timing control registers 
- `temp_wire_bits`: Temporary register used to drive SPI pins and command bytes 

## Integration Guide
1. **Instantiate** the module in your top-level design and connect the SPI pins, host memory bus, and clock/reset signals.
2. **Define** the system clock frequency macro `CLK_FREQ_MHZ` to ensure correct baud rate generation for hangup/wakeup phases.
3. **Route Host Memory Signals**: Ensure `host_mem_addr`, `host_mem_data_in/out`, and `host_mem_wr_en` are correctly mapped to your memory controller.
4. **Simulation**: Enable `` `define SIM_MODEL `` before simulation to activate debug/logic-specific paths.
5. **Toolchain Compatibility**: The code includes Verilator lint directives (`lint_off WIDTHEXPAND`) to ensure compatibility with modern synthesis and lint tools.

