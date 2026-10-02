# nanoFPU

A highly configurable, multi-target "IEEE-754 like" single-precision Floating Point Unit (FPU) written in Verilog. **nanoFPU** is engineered for FPGA architectures ranging from low-cost targets with limited resources (e.g., Lattice iCE40) to high-performance targets with DSP slices (e.g., Lattice ECP5, Gowin, Xilinx).

The goal is reasonable size/speed tradeoffs all the while being mostly precise floating point math.  It doesn't currently implement any subnormal/GRS like rounding so the precision isn't 100% IEEE and probably never will be.  Precision errors may be fixed in the future as I learn more about floats :)

## Key Features

- **IEEE-754 Single Precision Format**: "Standard" 32-bit floating-point support.
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
| `7` | **FCMP** | out = 4 if EQ, 2 if LT, 1 if GT | Floating point comparison |
| `8`..`11` | **IADD** | 8-bit saturated add and sub, 16-bit saturated add and sub |
| `15` | **NOP** | No operation | Idle the FPU, returns `ready` immediately |

## Performance & Latency Options

The execution cycles depend on parameter configuration:

| Instruction | Configuration / Parameter | Latency (Clock Cycles) | Notes |
| :--- | :--- | :--- | :--- |
| **FADD / FSUB** | `USE_FADDSUB_BARREL = 1` | 3 cycles | Larger but faster. |
| | `USE_FADDSUB_BARREL = 0` | ~27 cycles | Compact and variable cycle timing |
| **FMUL** | `USE_FMUL_DSP = 1` (36x36 DSP) | 3 – 4 cycles | For Gowin/Xilinx etc with wide DSP mults |
| | `USE_FMUL_DSP = 2` (18x18 DSP) | 4 – 5 cycles | For smaller DSP blocks |
| | `USE_FMUL_DSP = 0` (Serial Shift Multiplier) | 28 – 29 cycles | Compact 1-bit at a time double and add |
| | `USE_FMUL_DSP = 3` (2-bit Serial Shift Multiplier) | 14 – 15 cycles | Larger 2-bit at a time that takes half the time |
| **FDIV** | Standard | 28 cycles | Standard reduction |
| **FSTI** | `USE_FSTI_BARREL = 1` | 1 – 2 cycles | Larger but faster |
| | `USE_FSTI_BARREL = 0` | 2 – 24 cycles | Compact and variable cycle timing |
| **FLDI** | Standard | 2 – 24 cycles | Variable cycle timing |
| **FSQRT** (`*`) | `USE_FSQRT_STAGES = 0` | 28 – 29 cycles | Faster but harder to hit timing with |
|  | `USE_FSQRT_STAGES = 1` | 54 – 55 cycles (`**`) | Slower but easier to hit timing also slightly larger |
|  | `USE_FSQRT_STAGES = 2` | 79 – 80 cycles (`***`) | Way slower but basically becomes on par with other instructions for timing |
| **FCMP** | Standard | 1 Cycle | It compares things. |
| **IADD** | Standard | 1 Cycle | It adds ints |
| **NOP** | Standard | 1 Cycle | No op |

- (`*`) FSQRT takes 1 cycle to report an error.
- (`**`) The default STAGES==0 is very hard to meet the timing of the other FPU opcodes.  STAGES==1 helps close the gap while still being somewhat performant.
- (`***`) The three stage option (STAGES==2) takes 3x the cycles of the one stage option but has comparable timing closure to the other FPU opcodes.  Use this option when FSQRT latency is less important than overall FPU Fmax.

## Module Parameters

| Parameter | Default | Range / Type | Description |
| :--- | :---: | :---: | :--- |
| `ENABLE_FADDSUB` | `1'b1` | `0` / `1` | Enable `FADD` and `FSUB` operations |
| `ENABLE_FMUL` | `1'b1` | `0` / `1` | Enable `FMUL` operation |
| `ENABLE_FDIV` | `1'b1` | `0` / `1` | Enable `FDIV` operation |
| `ENABLE_FLDI` | `1'b1` | `0` / `1` | Enable `FLDI` operation |
| `ENABLE_FSTI` | `1'b1` | `0` / `1` | Enable `FSTI` operation |
| `ENABLE_FSQRT` | `1'b1` | `0` / `1` | Enable `FSQRT` operation |
| `ENABLE_FCMP` | `1'b1` | `0` / `1` | Enable `FCMP` operation |
| `ENABLE_IADD` | `1'b1` | `0` / `1` | Enable `IADD` operations |
| `USE_FMUL_DSP` | `1` | `0`, `1`, `2` | Multiplier target: `0` = Serial, `1` = 36x36 DSP, `2` = 18x18 DSP, `3` = 2-bit wide double-add |
| `USE_FADDSUB_BARREL`| `1` | `0` / `1` | Enable normalization barrel shifter for `FADD`/`FSUB` |
| `USE_FSTI_BARREL` | `1` | `0` / `1` | Enable barrel shifter for `FSTI` Normalization |
| `USE_FSQRT_STAGES` | `0` | `0` / `1` | Changes how many FSQRT stages there are STAGES={0,1,2} maps to 1, 2, or 3-stages. |

## Interface Signal Description

| Signal | Direction | Width | Description |
| :--- | :---: | :---: | :--- |
| `clk` | Input | 1 | Master clock signal |
| `rst_n` | Input | 1 | Active-low asynchronous/synchronous reset |
| `in_a` | Input | 32 | Operand A (IEEE-754 Float or Signed 32-bit Int for `FLDI`) |
| `in_b` | Input | 32 | Operand B (IEEE-754 Float, used for `FADD`, `FSUB`, `FMUL`, `FDIV`) |
| `opcode` | Input | 4 | Operation selector (0–15) |
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
      660   SB_CARRY
       18   SB_DFF
      182   SB_DFFE
      494   SB_DFFESR
        8   SB_DFFESS
        8   SB_DFFSR
     1959   SB_LUT4
```

### Lattice ECP5 (Performance Configuration)
*Configured with `USE_MULT=2` (18x18 DSP) and barrel shifters enabled.*


```
        4   MULT18X18D
     3536 submodules
      361   CCU2C
       66   L6MUX21
     1896   LUT4
      429   PFUMX
      784   TRELLIS_FF
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
- `fcmp.v` - Floating-point comparison

# NanoVEX (4:2:1 Reduction Vector Engine)

`nanovex` is a highly configurable, self-synchronizing 7-FPU vector engine constructed as a 4:2:1 binary reduction tree using `nanofpu` cores. It allows complex multi-stage floating-point operations—such as vector dot products, Euclidean distance metrics ($\sqrt{x^2 + y^2}$), matrix transforms, and parallel scalar math—to execute in hardware without processor intervention or software pipeline stalls.

## Topology Architecture

The 7 sub-FPUs are organized across three cascade layers ($F_{0y} \rightarrow F_{1y} \rightarrow F_{2y}$):

```
         F00           F01     F02           F03       <-- Input Layer (Leaf Nodes)
           \           /         \           /
            \         /           \         /
             ▼       ▼             ▼       ▼
                F10                   F11              <-- Layer 1 Reduction
                   \                 /
                    \               /
                     ▼             ▼
                           F20                         <-- Layer 2 Root Output

```

## Features & Execution Modes

* **Asynchronous Auto-Synchronization:** Each layer accumulates completion strobes (`fpu_readies`) in internal dependency registers. A dependent parent FPU automatically fires its `valid` signal for exactly **1 clock cycle** as soon as all necessary child inputs become available.
* **Per-Node Functional Pruning:** Each FPU (`ENABLE_Fxy`) can be individually configured with custom opcode subsets (e.g., `NANOFPU_FUNCS_ALL` down to `NANOFPU_FUNCS_NONE`). Synthesis tools automatically prune unsynthesized logic, logic trees, and unused multiplier/DSP hardware.
* **Dynamic Branch Masking & Bypass:** Inner layers can be selectively bypassed or disabled via runtime control (opcode == `NANOFPU_OP_NOP to disable core). Bypassing an unneeded subtree dynamically satisfies parent dependencies, allowing single-ended operations (like left-hand-only 2D cascades) to execute without dummy instructions.
* **Individual Port Exposure:** Results (`out[223:0]`) and completion strobes (`ready[6:0]`) for all 7 FPUs are independently exposed, allowing intermediate calculations to be harvested simultaneously.

---

## Operating Configurations

| Mode | Top-Level Setup | Execution Pattern | Use Case |
| --- | --- | --- | --- |
| **4D Vector Reduction** | All FPUs enabled | 4 inputs $\rightarrow$ 2 intermediate $\rightarrow$ 1 root result | $4\text{D Dot Product}$, Matrix Transformations |
| **Dual 2D Reduction** | `F00..F03`, `F10`, `F11` enabled | Two independent 2:1 reductions in parallel | Dual $x^2 + y^2$ sum stages, 2D Vector Ops |
| **2D Cascade + Bypass** | `F00`, `F01`, `F10`, `F20` enabled | Left branch cascades down into $F_{20}$; Right branch bypassed | Single-ended 2D Distance: $\sqrt{x^2 + y^2}$ |
| **Quad Parallel Scalar** | `F00..F03` enabled | 4 independent FPUs operating concurrently | Parallel SIMD scalar float math |

## Module Parameters

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `ENABLE_F00` .. `ENABLE_F03` | Macro | ``NANOFPU_FUNCS_ALL` | Enabled opcodes for leaf layer nodes $F_{00}$–$F_{03}$ |
| `ENABLE_F10`, `ENABLE_F11` | Macro | ``NANOFPU_FUNCS_ALL` | Enabled opcodes for intermediate layer nodes $F_{10}$, $F_{11}$ |
| `ENABLE_F20` | Macro | ``NANOFPU_FUNCS_ALL` | Enabled opcodes for root output node $F_{20}$ |
| `USE_FMUL_DSP` | Integer | `2` | Multiplier target: `0` = Serial, `1` = $36\times36$ DSP, `2` = $18\times18$ DSP, `3` = 2-bit Serial |
| `USE_FADDSUB_BARREL` | Bit | `1` | Enable barrel shifter for floating-point alignment add/sub |
| `USE_FSTI_BARREL` | Bit | `1` | Enable barrel shifter for float-to-int conversion |
| `USE_FSQRT_TWO_STAGE` | Bit | `1` | Enable 2-stage pipelined square root for higher $F_{\max}$ |


## Signal Interface

### Ports

```verilog
input  wire        clk,
input  wire        rst_n,

// Data & Control Inputs
input  wire [127:0] in_a,        // Concatenated A inputs: {F03, F02, F01, F00}
input  wire [127:0] in_b,        // Concatenated B inputs: {F03, F02, F01, F00}
input  wire [27:0]  opcode,      // Concatenated 4-bit opcodes for 7 FPUs {F20..F00}
input  wire [3:0]   valid,       // Start triggers for leaf FPUs {F03..F00}

// Outputs
output reg  [223:0] out,         // Concatenated 32-bit results {F20, F11, F10, F03..F00}
output reg  [6:0]   ready,       // Output valid strobes {F20, F11, F10, F03..F00}
output reg  [6:0]   busy         // busy status of {F20, F11, F10, F03..F00}

```

### Opcode Mapping (3 bits per FPU)

* `0000` (`0`): **`FADD`** — Floating-Point Addition
* `0001` (`1`): **`FSUB`** — Floating-Point Subtraction
* `0010` (`2`): **`FMUL`** — Floating-Point Multiplication
* `0011` (`3`): **`FDIV`** — Floating-Point Division
* `0100` (`4`): **`FLDI`** — Int-to-Float Conversion
* `0101` (`5`): **`FSTI`** — Float-to-Int Conversion
* `0110` (`6`): **`FSQRT`** — Floating-Point Square Root
* `0111` (`7`): **`FCMP`**  — Floating-Point Compare (out => 4-EQ, 2-LT, 1-GT)
* `1000` (`8`): **`IADD`**  — Parallel 8-bit saturated adds
* `1001` (`9`): **`IADD`**  — Parallel 8-bit saturated subs
* `1010` (`10`): **`IADD`**  — Parallel 16-bit saturated adds
* `1011` (`11`): **`IADD`**  — Parallel 16-bit saturated subs
* `1111` (`15`): **`NOP`**  — No-Op signals `ready` immediately.

## Example Usage: 2D Euclidean Distance $\sqrt{x^2 + y^2}$

Below is a configuration executing $2\text{D Distance} = \sqrt{x^2 + y^2}$ using the left side cascade ($F_{00}, F_{01} \rightarrow F_{10} \rightarrow F_{20}$):

```verilog
// Set inputs: x -> F00, y -> F01
assign in_a = {64'b0, y_val, x_val}; 
assign in_b = {64'b0, y_val, x_val}; 

// Set Opcodes: F00=FMUL (x^2), F01=FMUL (y^2), F10=FADD (x^2+y^2), F20=FSQRT (sqrt)
assign opcode = {
    4'd6, // F20: FSQRT
    4'd15, // F11: Unused / Bypassed
    4'd0, // F10: FADD
    4'd15, 4'd15, // F03, F02: Unused
    4'd2, 4'd2  // F01, F00: FMUL
};

// Trigger leaf execution
assign valid = 4'b0011; // Fire F00 and F01

// Result available when ready[6] (F20 ready strobe) goes high
wire [31:0] distance_result = out[223:192];

```
