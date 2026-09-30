# nanoFPU

A highly configurable, multi-target IEEE-754 single-precision Floating Point Unit (FPU) written in Verilog. **nanoFPU** is engineered for FPGA architectures ranging from low-cost targets with limited resources (e.g., Lattice iCE40) to high-performance targets with DSP slices (e.g., Lattice ECP5, Gowin, Xilinx).

## Key Features

- **IEEE-754 Single Precision Format**: Standard 32-bit floating-point support.
- **Modular Instruction Enables**: Unused functional blocks can be disabled at compile time via Verilog parameters to save logic.
- **Flexible Area vs. Latency Trade-offs**: Options to select between serial shifters/multipliers and barrel shifters or dedicated hardware DSPs.
- **Broad FPGA Vendor Support**: Fully synthesizable for Lattice (iCE40, ECP5), Gowin, Xilinx, and standard Yosys toolchains.
- **Simple Valid/Ready Handshake Protocol**: Straightforward multi-cycle execution interface.

## Instruction Set & Opcodes

The core operates on a 3-bit opcode (`opcode[2:0]`):

| Opcode | Mnemonic | Operation | Description |
| :---: | :---: | :--- | :--- |
| `0` | **FADD** | $out = in\_a + in\_b$ | Floating-point addition |
| `1` | **FSUB** | $out = in\_a - in\_b$ | Floating-point subtraction |
| `2` | **FMUL** | $out = in\_a \times in\_b$ | Floating-point multiplication |
| `3` | **FDIV** | $out = in\_a \div in\_b$ | Floating-point division |
| `4` | **FLDI** | $out = \text{float}(in\_a)$ | Load integer: Converts signed 32-bit integer to float |
| `5` | **FSTI** | $out = \text{int}(in\_a)$ | Store integer: Converts float to signed 32-bit integer |
| `6` | **FSQRT**| $out = \sqrt{in\_a}$ | Floating-point square root |

## Performance & Latency Options

The execution cycles depend on parameter configuration:

| Instruction | Configuration / Parameter | Latency (Clock Cycles) |
| :--- | :--- | :--- |
| **FADD / FSUB** | `USE_FADDSUB_BARREL = 1` | 3 cycles |
| | `USE_FADDSUB_BARREL = 0` | ~27 cycles |
| **FMUL** | `USE_MULT = 1` (36x36 DSP) | 3 – 4 cycles |
| | `USE_MULT = 2` (18x18 DSP) | 4 – 5 cycles |
| | `USE_MULT = 0` (Serial Shift Multiplier) | 28 – 29 cycles |
| **FDIV** | Standard | 28 cycles |
| **FSTI** | `USE_FSTI_BARREL = 1` | 1 – 2 cycles |
| | `USE_FSTI_BARREL = 0` | 2 – 24 cycles |
| **FLDI** | Standard | 2 – 24 cycles |

## Module Parameters

| Parameter | Default | Range / Type | Description |
| :--- | :---: | :---: | :--- |
| `ENABLE_FADDSUB` | `1'b1` | `0` / `1` | Enable `FADD` and `FSUB` operations |
| `ENABLE_FMUL` | `1'b1` | `0` / `1` | Enable `FMUL` operation |
| `ENABLE_FDIV` | `1'b1` | `0` / `1` | Enable `FDIV` operation |
| `ENABLE_FLDI` | `1'b1` | `0` / `1` | Enable `FLDI` operation |
| `ENABLE_FSTI` | `1'b1` | `0` / `1` | Enable `FSTI` operation |
| `ENABLE_FSQRT` | `1'b1` | `0` / `1` | Enable `FSQRT` operation |
| `USE_MULT` | `1` | `0`, `1`, `2` | Multiplier target: `0` = Serial, `1` = 36x36 DSP, `2` = 18x18 DSP |
| `USE_FADDSUB_BARREL`| `1` | `0` / `1` | Enable normalization barrel shifter for `FADD`/`FSUB` |
| `USE_FSTI_BARREL` | `1` | `0` / `1` | Enable barrel shifter for `FSTI` normalization |

## Interface Signal Description

| Signal | Direction | Width | Description |
| :--- | :---: | :---: | :--- |
| `clk` | Input | 1 | Master clock signal |
| `rst_n` | Input | 1 | Active-low asynchronous/synchronous reset |
| `in_a` | Input | 32 | Operand A (IEEE-754 Float or Signed 32-bit Int for `FLDI`) |
| `in_b` | Input | 32 | Operand B (IEEE-754 Float, used for `FADD`, `FSUB`, `FMUL`, `FDIV`) |
| `opcode` | Input | 3 | Operation selector (0–6) |
| `valid` | Input | 1 | Asserts operation start (must be held steady for 1 cycle) |
| `out` | Output | 32 | Result output (valid when `ready` is high) |
| `ready` | Output | 1 | High for 1 cycle when execution completes and `out` is valid |

### Protocol Rules
1. **Initiating an Operation**: Assert `in_a`, `in_b` (if required), `opcode`, and `valid` simultaneously for 1 clock cycle.
2. **Execution**: The core is non-pipelined. Do not assert `valid` again until `ready` goes high.
3. **Completion**: Read `out` on the clock edge where `ready == 1`.

## Synthesis & Area Usage Benchmarks

### Lattice iCE40 (Area-Optimized Configuration)
*Configured without barrel shifters or hardware DSP multipliers (`USE_MULT=0`, barrel shifters disabled).*


```
490  SB_CARRY
16   SB_DFF
330  SB_DFFE
295  SB_DFFESR
8    SB_DFFESS
8    SB_DFFSR
1619 SB_LUT4
```

### Lattice ECP5 (Performance Configuration)
*Configured with `USE_MULT=2` (18x18 DSP) and barrel shifters enabled.*


```
4    MULT18X18D
271  CCU2C
59   L6MUX21
1637 LUT4
331  PFUMX
689  TRELLIS_FF
```

### Gowin (Performance Configuration)
*Configured with `USE_MULT=1` (36x36 DSP) and barrel shifters enabled.*


```
1555 LUT
575  DFF
351  MUX
1    MULT36X36
463  ALU
```

### Xilinx 7-Series / UltraScale (Performance Configuration)
*Configured with DSP48 enabled and barrel shifters enabled (Estimated Logic Cells: ~979).*


```
1    BUFG
2    DSP48E1
70   IBUF
131  INV
281  LUT2
181  LUT3
174  LUT4
358  LUT5
266  LUT6
33   OBUF
```

## File Structure

- `nanofpu.v` - Top-level module wrapper
- `nanofpu.vh` - Opcode definitions and macros
- `faddsub.v` - Floating-point adder/subtractor
- `fmul.v` - Floating-point multiplier
- `fdiv.v` - Floating-point divider
- `fldi.v` - Integer-to-float converter
- `fsti.v` - Float-to-integer converter
- `fsqrt.v` - Floating-point square root core
