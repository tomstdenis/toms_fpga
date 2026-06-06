# SPI SRAM/PRAM DMA Controller (`spidma`)

Overview
--------

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

Key Features
------------

- **Dual-Mode Support**: Handles both 1-bit SPI and QPI data transfer states.
- **Configurable Burst Length**: Supports data bursts from 1 to 256 bytes per transaction.
- **Automated State Machine**: Transitions through initialization, reset, command/address shifting, QPI data phases, and host memory coordination.
- **Timing Control**: Includes configurable hangup and wakeup baud rate dividers calculated from the system clock frequency `CLK_FREQ_MHZ`.
- **Simulation Support**: Contains simulation-specific logic (e.g., `sim_wr_en`) guarded by the `` `define SIM_MODEL `` macro.

Init
----

After POR the module goes through the motions to issue a reset command and then if needed enter quad-io mode.  At which point
it's ready for commands.  You can raise a command at any pointer during init.

Theory of Operation
-------------------

To program a new command you need to program the following nets:

- **cmd_value**: The command to issue (see spidma.vh)
- **cmd_valid**: Set to 1 once all cmd nets are valid
- **cmd_spi_address**: The address in SPI memory to access
- **cmd_host_address**: The address in host memory to access
- **cmd_burst_len**: The length in bytes of the burst - 1, (e.g. 15 == 16 byte burst)

Timing
------

The module automatically inserts mandatory hangup periods between commands.  It doesn't limit the burst length to adhere to PSRAM Tcem timing the user is required to limit that themselves (typically <= 32 bytes for quad-mode IO is fine at all but really low clock rates).

The module uses parameters to configure timing:

- **CLK_FREQ_MHZ**: The Mhz rating of the core clock (should be >= the actual core clock)
- **DUMMY_CYCLES**: How many SCK cycles are required between issuing a read command and data being valid
- **MIN_CPH_NS**: Minimum nanosecond delay between commands
- **MIN_WAKEUP_NS**: Minimum number of nanoseconds to wait after POR before issuing reset commands
- **SPI_TIMER_BITS**: Divide the core clock by this (+1) to get the SPI SCK clock rate.  E.g. 0 == core clock / 2, 1 == core clock / 4, 2 == core clock / 6, ..
- **QPI_TIMER_BITS**: Like **SPI_TIMER_BITS** but affects the QPI SCK clock rate. 

Other Parameters
----------------

The module is meant to support a variety of memories.  By default, it's configured for common PSRAM timings and command bytes.

```
	// Commands 
	parameter CMD_WRITE_ENABLE = 8'h00,						// enable the Write Enable Latch (set to 8'h06 to enable)
	parameter CMD_READ_STATUS  = 8'h05,						// read the status register for WEL/WIP
	parameter CMD_SECTOR_ERASE = 8'h20,						// erase a sector

	parameter CMD_SPI_READ    = 8'h03,						// command to read in SPI mode
	parameter CMD_SPI_WRITE   = 8'h02,						// command to write in SPI mode (page program in NOR mode)
	parameter CMD_QPI_READ    = 8'hEB,						// command to read in QPI mode
	parameter CMD_QPI_WRITE   = 8'h38,						// command to write in QPI mode

	parameter CMD_EQIO        = 8'h35,						// command to enter quad IO mode
	parameter CMD_QMEX        = 8'hF5,						// command to exit quad mod IO
	parameter CMD_RESETEN     = 8'h66,						// command to enable reset
	parameter CMD_RESET       = 8'h99,						// command to reset
```

Keep in mind some command bytes change behaviour, for instance, SPI read with 03h has fewer wait cycles than a SPI read with 0Bh (but 0Bh has a faster tolerable SCK rate than 03h, etc...).
