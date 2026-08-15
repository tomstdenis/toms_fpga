#!/usr/bin/env python3
import sys

def main():
    pass_count = 0
    fail_count = 0
    other_count = 0

    print("Listening on stdin for FPGA output (0x55 = Pass, 0xAA = Fail)...")
    print("Press Ctrl+C to terminate and view the final summary.\n")

    try:
        # Read byte-by-byte in raw binary mode
        while True:
            chunk = sys.stdin.buffer.read(1)
            if not chunk:
                break  # EOF reached

            byte = chunk[0]  # Extracts integer value (0x00 - 0xFF)

            if byte == 0x55:
                pass_count += 1
            elif byte == 0xAA:
                fail_count += 1
            elif byte in (0x0D, 0x0A, 0x20, 0x09):  # \r, \n, space, \t
                # Ignore common whitespace noise
                continue
            else:
                other_count += 1

            total = pass_count + fail_count
            pass_rate = (pass_count / total * 100) if total > 0 else 0.0

            # Dynamic inline dashboard
            status = (
                f"\r\033[K"  # Clear line before printing
                f"TOTAL: {total:<7} | "
                f"PASS: {pass_count:<7} | "
                f"FAIL: {fail_count:<7} | "
                f"Pass Rate: {pass_rate:>6.2f}%"
            )
            sys.stdout.write(status)
            sys.stdout.flush()

    except KeyboardInterrupt:
        pass

    # Summary report on exit
    total = pass_count + fail_count
    pass_rate = (pass_count / total * 100) if total > 0 else 0.0

    print("\n\n" + "=" * 35)
    print("         FINAL TEST SUMMARY         ")
    print("=" * 35)
    print(f"  Total Runs  : {total}")
    print(f"  Passed      : {pass_count}")
    print(f"  Failed      : {fail_count}")
    print(f"  Pass Rate   : {pass_rate:.2f}%")
    if other_count > 0:
        print(f"  Unexpected  : {other_count}")
    print("=" * 35)

if __name__ == "__main__":
    main()
