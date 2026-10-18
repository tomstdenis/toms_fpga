# Single-Channel DMA Controller (`sc_dma`)

The `sc_dma` module is a configurable, single-channel Direct Memory Access (DMA) controller written in Verilog. It offloads memory copy and pattern-fill operations from the main CPU, supporting standard memory-to-memory copies, constant memory initialization, and 2D block transfers with configurable strides.

---

## Features

- **Memory-to-Memory Transfer:** Direct copying from source read addresses to destination write addresses.
- **Constant Value Fill:** Support for memory filling/clearing operations without issuing bus reads (`cmd_write_constant`).
- **Flexible Pointer Advancement:** Read and write address pointers can be independently frozen/held static (`cmd_read_advance`, `cmd_write_advance`), making it ideal for streaming data to or from FIFO memory-mapped registers.
- **2D Strided Transfers:** Independent 2D striding (width and stride/pitch settings) for both read and write operations.
- **Parametric Widths:** Configurable address (`ADDR_WIDTH`) and data (`DATA_WIDTH`) bus widths.

---

## Module Parameters

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `ADDR_WIDTH` | integer | `32` | Bit width of the address bus and command address inputs. |
| `DATA_WIDTH` | integer | `32` | Bit width of the data bus and command constant inputs. |

---

## Signal Interface

### Control & Clocking
| Signal | Direction | Width | Description |
| :--- | :--- | :--- | :--- |
| `clk` | Input | 1 | System clock signal (active on positive edge). |
| `rst_n` | Input | 1 | Asynchronous active-low reset. |

### Command Interface (`cmd_*`)
| Signal | Direction | Width | Description |
| :--- | :--- | :--- | :--- |
| `cmd_read_addr` | Input | `ADDR_WIDTH` | Initial base read address. |
| `cmd_read_stride` | Input | 16 | Stride of read surface in bytes (must be multiple of 4) |
| `cmd_read_width` | Input | 16 | Width of read window in bytes (must be a multiple of 4) |
| `cmd_write_addr` | Input | `ADDR_WIDTH` | Initial base write address. |
| `cmd_write_stride` | Input | 16 | Stride of write surface in bytes (must be multiple of 4) |
| `cmd_write_width` | Input | 16 | Width of write window in bytes (must be a multiple of 4) |
| `cmd_length` | Input | `ADDR_WIDTH` | Total transfer length specified in **32-bit words**. |
| `cmd_constant` | Input | `DATA_WIDTH` | Constant value to write when `cmd_write_constant` is asserted. |
| `cmd_read_advance` | Input | 1 | Set `1` to advance read pointer during read operations; `0` to hold read address static (e.g., FIFO read). |
| `cmd_write_advance`| Input | 1 | Set `1` to advance write pointer during write operations; `0` to hold write address static (e.g., FIFO write). |
| `cmd_write_constant`| Input | 1 | Set `1` to enable constant fill mode (skips bus read cycles). |
| `cmd_valid` | Input | 1 | Asserted high to initiate a command transfer. |
| `cmd_ready` | Output | 1 | Asserted high for 1 clock cycle upon transfer completion. |

### Bus Interface (`bus_*`)
| Signal | Direction | Width | Description |
| :--- | :--- | :--- | :--- |
| `bus_addr` | Output | `ADDR_WIDTH` | Transaction memory address. |
| `bus_wdata` | Output | `DATA_WIDTH` | Transaction write data payload. |
| `bus_rdata` | Input | `DATA_WIDTH` | Transaction read data payload. |
| `bus_wstrb` | Output | `DATA_WIDTH/8` | Byte lane write enable strobe (`0` = Read cycle, `0xF` = 32-bit Write cycle). |
| `bus_valid` | Output | 1 | Asserted high when a bus transaction request is active. |
| `bus_ready` | Input | 1 | Asserted by the memory bus slave to acknowledge transaction completion. |
| `bus_busy` | Output | 1 | Indicates DMA module is active or requesting bus control over the CPU. |

---

## Theory of Operation

### State Machine (FSM)

The DMA controller operates using a 5-state finite state machine:

```
                  +--------------+
                  |   FSM_IDLE   |<------------------------------+
                  +------+-------+                               |
                         |                                       |
      (cmd_valid)        v      (cmd_valid & cmd_write_constant) |
           +-------------+-------------+<---------------+        |
           |                           |                |        |
           v                           v                |        |
  +------------------+       +-------------------+      |        |
  |  FSM_ISSUE_READ  |    +->|  FSM_ISSUE_WRITE  |      |        |
  +--------+---------+    |  +---------+---------+      |        |
           |              |            |                |        |
           v              |            v                |        |
  +------------------+    |  +-------------------+      |        |
  |   FSM_WAIT_READ  | ---+  |  FSM_WAIT_WRITE   | -----+        |
  +------------------+       +---------+---------+               |
                                       |                         |
                                       | (job_length == 0)       |
                                       +-------------------------+
```

1. **`FSM_IDLE`:** Waiting for `cmd_valid`. Latches all transaction attributes (`addr`, `stride`, `width`, `length`, control flags). If `cmd_write_constant` is set, transitions directly to `FSM_ISSUE_WRITE`; otherwise, goes to `FSM_ISSUE_READ`.
2. **`FSM_ISSUE_READ`:** Drives `bus_addr` and sets `bus_valid` high to request a read. Increments `job_read_addr` by 4 bytes if `cmd_read_advance` is high.
3. **`FSM_WAIT_READ`:** Waits for `bus_ready` from the slave. Once acknowledged, checks if the row boundary (`job_read_width`) is reached to update pitch offsets.
4. **`FSM_ISSUE_WRITE`:** Drives `bus_addr` and `bus_wdata` (either latched read data or `cmd_constant`). Sets `bus_wstrb` high for write operations and decrements the remaining word count (`job_length`).
5. **`FSM_WAIT_WRITE`:** Waits for `bus_ready`. If `job_length` reaches zero, asserts `cmd_ready` and returns to `FSM_IDLE`.

### Windowed vs Linear
To perform linear operations simply set `stride` and `width` to be equal (ideally zero).  Otherwise,
when the read or write offset (from the start of the job) hits the corresponding `width` then the offset is reset to 0 and the corresponding `stride - width` is added to the pointer.

For example, if you set `cmd_read_width = 8` and `cmd_read_stride = 320` then every 8 bytes read will add `320 - 8 = 312` to the read pointer.  Effectively, this advances to the left most column of the next row in a row-major ordering surface.

The read and write directions have their own pitch settings allowing you to copy from a linear surface to a windowed one, vice versa, or from same to same.

---

## Usage Examples

### 1. Simple Memory Copy (RAM to RAM)
To copy a 1024-word block from `0x1000_0000` to `0x2000_0000`:

```verilog
cmd_read_addr      <= 32'h1000_0000;
cmd_read_stride    <= 16'd0;
cmd_read_width     <= 16'd0;
cmd_write_addr     <= 32'h2000_0000;
cmd_write_stride   <= 16'd0;
cmd_write_width    <= 16'd0;
cmd_length         <= 32'd4096;      // Total bytes
cmd_constant       <= 32'h0;
cmd_read_advance   <= 1'b1;          // Increment read address
cmd_write_advance  <= 1'b1;          // Increment write address
cmd_write_constant <= 1'b0;          // Perform actual bus reads
cmd_valid          <= 1'b1;
```

### 2. Memory Fill / Clear (Constant Write)
To clear a memory region of 512 words at `0x2000_0000` with `0x0000_0000`:

```verilog
cmd_write_addr     <= 32'h2000_0000;
cmd_write_stride   <= 16'd0;
cmd_write_width    <= 16'd0;
cmd_length         <= 32'd2048;      // 512 words == 2048 bytes
cmd_constant       <= 32'h0000_0000; // Constant value
cmd_read_advance   <= 1'b0;
cmd_write_advance  <= 1'b1;          // Increment write pointer
cmd_write_constant <= 1'b1;          // Skip bus reads
cmd_valid          <= 1'b1;
```

### 3. FIFO Memory Dump (Static Read Pointer)
To read 100 words from a static peripheral hardware FIFO at `0x4000_0000` into RAM starting at `0x2000_0000`:

```verilog
cmd_read_addr      <= 32'h4000_0000; // Peripheral FIFO address
cmd_write_addr     <= 32'h2000_0000; // Destination buffer
cmd_write_stride   <= 16'd0;
cmd_write_width    <= 16'd0;
cmd_length         <= 32'd400;       // 100 words == 400 bytes
cmd_read_advance   <= 1'b0;          // DO NOT advance read pointer
cmd_write_advance  <= 1'b1;          // Advance write destination address
cmd_write_constant <= 1'b0;
cmd_valid          <= 1'b1;
```