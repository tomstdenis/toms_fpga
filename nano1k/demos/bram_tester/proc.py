#!/usr/bin/env python3
import sys
import time

def main():
    print("=== FPGA RAM Diagnostic UART Monitor ===")
    print("Waiting for sync pattern [test_byte, 0xFF, 0xFF, 0xFF] on stdin...\n")

    current_test_byte = None
    total_test_cycles = 0      # Counts complete 0..255 loops
    total_errors = 0
    unique_failing_addrs = set()
    last_test_byte = -1

    # Force stdin to unbuffered binary mode
    stdin = sys.stdin.buffer

    # --- Phase 1: Sliding Window Initial Synchronization ---
    window = bytearray()
    while len(window) < 4:
        b = stdin.read(1)
        if not b:
            print("STDIN closed before sync acquired.")
            return
        window.append(b[0])

    # Slide 1 byte at a time until window ending matches 0xFF 0xFF 0xFF
    while window[1:] != b'\xff\xff\xff':
        b = stdin.read(1)
        if not b:
            print("STDIN closed during resync.")
            return
        window.pop(0)
        window.append(b[0])

    # Initial sync acquired!
    current_test_byte = window[0]
    last_test_byte = current_test_byte
    print(f"[SYNC ACQUIRED] Starting at test_byte: 0x{current_test_byte:02X}")

    # --- Phase 2: Main Processing Loop (4-Byte Words) ---
    try:
        while True:
            word = stdin.read(4)
            if len(word) < 4:
                print("\n[EOF] Input stream closed.")
                break

            header_candidate = word[0]
            tail_bytes = word[1:]

            # 1. Check for New Test Cycle Sync Header [TB, 0xFF, 0xFF, 0xFF]
            if tail_bytes == b'\xff\xff\xff':
                current_test_byte = header_candidate
                
                # Check for 0..255 loop rollover
                if current_test_byte < last_test_byte or (last_test_byte == 255 and current_test_byte == 0):
                    total_test_cycles += 1

                last_test_byte = current_test_byte
                
                # Print periodic progress status
                print(f"\r[RUNNING] Cycle #{total_test_cycles} | Test Byte: 0x{current_test_byte:02X} | "
                      f"Total Errors: {total_errors} | Unique Bad Addrs: {len(unique_failing_addrs)}", end="", flush=True)

            # 2. Check for Address Error Report [TB, Addr_23..16, Addr_15..8, Addr_7..0]
            elif header_candidate == current_test_byte + 1:
                # Assuming Big-Endian address encoding (MSB first)
                failing_addr = (word[1] << 16) | (word[2] << 8) | word[3]
                total_errors += 1
                
                is_new_addr = failing_addr not in unique_failing_addrs
                unique_failing_addrs.add(failing_addr)

                # Overwrite status line with error detail
                marker = " [NEW ADDRESS!]" if is_new_addr else ""
                print(f"\n  └─ [FAIL] Test Byte: 0x{current_test_byte:02X} | "
                      f"Address: 0x{failing_addr:06X} ({failing_addr:d}){marker}")

            # 3. Framing Loss / Out-of-Sync Detection
            else:
                print(f"\n[WARNING] Lost word synchronization! (Got byte 0x{header_candidate:02X}, expected 0x{current_test_byte:02X}). Resyncing...")
                
                # Re-sync by sliding window byte-by-byte
                window = bytearray(word)
                while window[1:] != b'\xff\xff\xff':
                    b = stdin.read(1)
                    if not b:
                        return
                    window.pop(0)
                    window.append(b[0])
                
                current_test_byte = window[0]
                last_test_byte = current_test_byte
                print(f"[RESYNCED] Lock re-established at test_byte: 0x{current_test_byte:02X}")

    except KeyboardInterrupt:
        print("\n\n=== User Interrupted ===")

    # --- Final Diagnostics Summary ---
    print("\n" + "="*45)
    print("           FINAL TEST SUMMARY")
    print("="*45)
    print(f"Total Full Cycles Run (0-255): {total_test_cycles}")
    print(f"Total Errors Captured:         {total_errors}")
    print(f"Unique Failing Addresses:      {len(unique_failing_addrs)}")
    if unique_failing_addrs:
        print("\nFailing Address List:")
        for addr in sorted(unique_failing_addrs):
            print(f"  • 0x{addr:06X} ({addr:d})")
    print("="*45)

if __name__ == "__main__":
    main()
