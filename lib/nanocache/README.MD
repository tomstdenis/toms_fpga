# `nanocache` — Direct-Mapped Cache Controller for PSRAM (`nanosram`)

`nanocache` is a parameterized, direct-mapped, write-back cache controller written in Verilog. Designed specifically to front the `nanosram` Quad SPI (QPI) PSRAM controller, it minimizes memory latency for host processors by caching active lines in block/distributed RAM and providing dual-port hit acceleration when dual-ported memory structures are available.

---

## Features

* **Write-Back Policy:** Modified lines are marked dirty and only written out to physical PSRAM upon eviction, reducing bus traffic.
* **Configurable Dual-Porting (`CACHE_DP`):**
* `CACHE_DP = 1`: Uses true dual-ported SRAM. Fetches 2 bytes per clock cycle on cache hits, doubling throughput.
* `CACHE_DP = 0`: Operates in semi-dual-ported / single-ported mode for resource-constrained FPGA targets.


* **Integrated Sub-Module (`nanosram`):** Direct instantiates `nanosram` to manage raw QPI bus timing, PHY initialization (`WAKEUP_DELAY_US`), and line transfers.
* **Per-Byte Write Enable Support:** 4-bit `write_mask` allows byte, half-word, and full 32-bit word partial writes.
* **Simulation Instrumentation:** Includes conditional compile simulation hooks (`MODEL_SIM`) to monitor cache performance counters (hits, misses, evictions, fills, cycles).

---

## Architecture Overview

An incoming address (`data_addr`) is split into **Tag**, **Line Index**, and **Line Offset** depending on the configuration parameters:

```text
+----------------------+--------------------+--------------------+
|       TAG BITS       |  CACHE_LINES Index | CACHE_LINE Offset  |
+----------------------+--------------------+--------------------+

```

### Module Parameters

| Parameter | Default | Description |
| --- | --- | --- |
| `CACHE_SIZE` | `11` | Log2 of total cache size in bytes (default: $2^{11} = 2\text{ KB}$). |
| `CACHE_LINE` | `5` | Log2 of line size in bytes (default: $2^5 = 32\text{ B}$). |
| `CACHE_DP` | `1` | Enable true dual-port RAM mode (`1`) or single-port mode (`0`). |
| `SRAM_ADDR_WIDTH` | `24` | Total address space width in bits ($16\text{ MB}$ range). |
| `DUMMY_BYTES` | `3` | Number of fast-read dummy cycles required by PSRAM. |
| `FREQ` | `81` | Core clock frequency in MHz (used for PSRAM timing delays). |
| `WAKEUP_DELAY_US` | `50` | Power-on wakeup delay for PSRAM in microseconds. |
| `HANGUP_DELAY_NS` | `50` | Minimum delay between PSRAM CS deassertions in nanoseconds. |

---

## Interface Signals

### Core Control & Host Data Interface

| Signal | Direction | Width | Description |
| --- | --- | --- | --- |
| `clk` | Input | 1 | System clock. |
| `rst_n` | Input | 1 | Active-low async/sync reset. Clears tag memory on reset. |
| `data_in` | Input | 32 | 32-bit input data bus for writes. |
| `write_mask` | Input | 4 | Byte enable mask for partial word writes. |
| `data_addr` | Input | `SRAM_ADDR_WIDTH` | Target target byte address in memory. |
| `data_wr_en` | Input | 1 | Read (`0`) / Write (`1`) control. |
| `data_out` | Output | 32 | 32-bit output data read from cache/memory. |
| `valid` | Input | 1 | Transaction request pulse/flag from host. |
| `ready` | Output | 1 | Single-cycle pulse indicating operation completion. |
| `idle` | Output | 1 | High when FSM is resting in `FSM_IDLE`. |

### External QPI / Hardware Pins (Passed to `nanosram`)

| Signal | Direction | Width | Description |
| --- | --- | --- | --- |
| `sio_din` | Input | 4 | QPI data in. |
| `sio_dout` | Output | 4 | QPI data out. |
| `sio_en` | Output | 1 | QPI output enable (`1` = Output, `0` = Tri-state/Input). |
| `cs_pin` | Output | 1 | Active-low Chip Select line for PSRAM. |
| `sck_pin` | Output | 1 | Serial Clock line for PSRAM. |

---

## Finite State Machine (FSM)

The controller executes via a 3-bit state machine (`ctrl_fsm`):

1. **`FSM_CLEAR_TAGS` (`3'd0`):** Iterates through tag RAM upon reset and clears all valid and dirty bits.
2. **`FSM_IDLE` (`3'd1`):** Waits for `valid` signal to sample host requests and latch tag/cache addresses.
3. **`FSM_COMPARE_TAG` (`3'd2`):** Evaluates tag memory output against target address bits.
* **Hit:** Directly reads/writes internal block RAM and transitions back to `FSM_IDLE` with `ready <= 1`.
* **Miss (Clean):** Bypasses eviction and transitions directly to `FSM_FILL`.
* **Miss (Dirty):** Line is marked dirty; transitions to `FSM_EVICT`.


4. **`FSM_EVICT` (`3'd3`):** Streams the modified line from internal cache memory out to physical PSRAM via `nanosram`.
5. **`FSM_FILL` (`3'd4`):** Issue a read request to PSRAM to stream the new line into cache memory, substituting write payload bytes mid-burst if the initial command was a write. Transitions back to `FSM_IDLE`.

---

## Integration Example

```verilog
nanocache #(
    .CACHE_SIZE(11),        // 2KB Cache
    .CACHE_LINE(5),         // 32-Byte Line
    .CACHE_DP(1),           // Dual-Ported
    .SRAM_ADDR_WIDTH(24),   // 16MB space
    .FREQ(81)               // 81 MHz clock
) u_cache (
    .clk(sys_clk),
    .rst_n(sys_rst_n),

    // Host Bus
    .data_in(host_data_wr),
    .write_mask(host_byte_enable),
    .data_addr(host_addr),
    .data_wr_en(host_we),
    .data_out(host_data_rd),
    .valid(host_req_valid),
    .ready(host_req_ready),
    .idle(cache_is_idle),

    // Hardware Pins
    .sio_din(sio_din),
    .sio_dout(sio_dout),
    .sio_en(sio_en),
    .cs_pin(cs_pin),
    .sck_pin(sck_pin)
);

```

Here is the added section for your `README.MD`, formatted to drop right into the documentation.

---

## Theory of Operation

### Transaction Lifecycle

`nanocache` operates on a request-acknowledge handshaking protocol. The host core initiates a transaction when the cache is in `idle`, and then waits for `ready` to pulse high before completing the access or asserting a new request.

```text
               __    __    __    __    __    __    __    __    __    __
clk         __/  \__/  \__/  \__/  \__/  \__/  \__/  \__/  \__/  \__/  \__
               ______
valid       __/      \____________________________________________
            ______________________________________________________
data_addr   XX < Address > XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
            ______________________________________________________
data_in     XX < Write Data > XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
                                                         ______
ready       ____________________________________________/      \_________
            _________                                           ______
idle                 \_________________________________________/      \__
                                                        ^
                                                        Sample data_out here (Reads)

```

---

### Step-by-Step Operation Guide

#### 1. Initiating a Read Request

To read a 32-bit word from memory:

1. **Check Status:** Ensure `idle` is high (or `ready` has completed the prior transaction).
2. **Drive Address & Control Lines:**
* Set `data_addr` to the desired byte-aligned target address.
* Set `data_wr_en = 1'b0` (Read mode).
* Set `write_mask = 4'b1111` (or desired byte mask).


3. **Pulse Request:** Assert `valid = 1'b1` for at least one clock cycle.
4. **Wait for Completion:** Monitor `ready`.
5. **Sample Output:** When `ready` goes high, capture the 32-bit result on `data_out`.

#### 2. Initiating a Write Request

To perform a word, half-word, or byte write:

1. **Drive Address & Payload:**
* Set `data_addr` to the target address.
* Place payload data on `data_in[31:0]`.
* Set `data_wr_en = 1'b1` (Write mode).
* Set `write_mask` to enable specific bytes within the 32-bit word (e.g., `4'b0001` for byte 0, `4'b1111` for full word).


2. **Pulse Request:** Wait for `idle == 1'b1` and then assert `valid = 1'b1` for one clock cycle.
3. **Wait for Completion:** Wait until `ready` pulses high before modifying input lines or driving a new command.

---

### Internal Execution Flow

Depending on whether the target line is present in cache memory, `nanocache` executes one of three paths:

#### Path A: Cache Hit (Fast Path)

1. FSM transitions from `FSM_IDLE` to `FSM_COMPARE_TAG`.
2. Tag RAM output matches `data_tag` and `VALID_BIT` is set.
3. **Read Hit:**
* If `CACHE_DP = 1`, the controller reads 2 bytes per clock cycle across both RAM ports, pipeline-shifting them directly into `data_out`.
* If `CACHE_DP = 0`, it reads 1 byte per clock cycle.


4. **Write Hit:**
* The line's `DIRTY_BIT` is set high in `tag_mem`.
* Targeted bytes specified by `write_mask` are written directly into `cache_mem`.


5. FSM asserts `ready <= 1'b1` and returns to `FSM_IDLE`.

#### Path B: Cache Miss — Clean Line Replacement

1. Tag comparison fails on `FSM_COMPARE_TAG`.
2. The current cache line is clean (`DIRTY_BIT == 0`).
3. FSM enters `FSM_FILL` and signals `nanosram` to initiate a burst read from PSRAM starting at the base address of the requested cache line.
4. As PSRAM streams bytes back via `psram_read_strobe`:
* Bytes are written directly into `cache_mem`.
* If the host initiated a read, the requested word offset is captured and shifted into `data_out` mid-fill.
* If the host initiated a write, the target byte offset is overridden mid-fill using payload bytes from `data_in`.


5. The tag memory is updated with `data_tag`, `VALID_BIT = 1`, and `DIRTY_BIT = data_wr_en`.
6. FSM asserts `ready <= 1'b1` and returns to `FSM_IDLE`.

#### Path C: Cache Miss — Dirty Line Eviction & Fill

1. Tag comparison fails on `FSM_COMPARE_TAG`.
2. The target cache line contains modified data (`DIRTY_BIT == 1`).
3. FSM enters `FSM_EVICT`. It instructs `nanosram` to begin a burst write starting at the line's original tag base address `{tag_mem_out, line_index, 0}` and streams out all line bytes to PSRAM.
4. Once write-back completes, FSM transitions automatically to `FSM_FILL` to fetch the new line from PSRAM (following Path B).