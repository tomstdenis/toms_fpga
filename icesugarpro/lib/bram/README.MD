# ECP5 DP16KD Dual Ported BRAM Module Wrappers

This directory contains various memory configurations all based off
of the basic DP16KD in 2048x9bit (we ignore the top bit so 8 bits) mode.

There are semi dual ported versions for the 8-bit bus versions, and 
other bus widths for the true dual ported.

# Simulation Model

A very basic 9-bit simulation model is provided in the file **DP16KD.V** which only
supports 9-bit widths (what the rest of the code here uses).  It supports the parameters
for REGMODE and WRITEMODE. 

# Models

## Semi Dual Ported

- **bram_sp_2048x8.v**: Provides a single 2KiB block that is 2048 deep by 8-bit wide.  Uses the semi dual
port mode meaning there are independently clocked write and read ports.  2KiB in size.
- **bram_sp_n2048x8.v**: Provides a "N by" 2048 by 8-bit memory.  Valid for N=2 and higher.  Each new
block adds 2KiB to the address space.  2 * N KiB in size.

	Large memories are not provided since you can simply null route ports of the DP version you are't using.
These SP versions are mostly for convenience.

## True Dual Ported

### 8-Bit

- **bram_dp_2048x8.v**: Provides a true dual ported 2048 by 8-bit memory. 2KiB in size
- **bram_dp_nx2048x8.v**: Provides a true dual ported N by 2048 by 8-bit memory.   Each new block adds 2KiB to the memory.
2 * N KiB in size.
	
### 32-bit

32-bit Memories support byte enables allowing 32-bit read/writes on 4-byte aligned addresses, 16-bit read/writes on 2-byte aligned addresses, 
and 8-bit read/writes on any address.  The address space is byte mapped so the 16th 32-bit word is stored at byte 64.

- **bram_dp_2048x32.v**: Provides a true dual ported 2048 by 32-bit memory using 4 DP16KD blocks.  8KiB in size.
- **bram_dp_nx2048x32.v**: Provides a true dual ported N by 2048 by 32-bit memory using 4*N DP16KD blocks.  8 * N KiB in size.
