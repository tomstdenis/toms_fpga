#!/usr/bin/env python3
import sys

def main():
    pass_count = 0
    fail_count = 0
    other_count = 0

    print("Listening on stdin for FPGA output ('A' = Pass, 'B' = Fail)...")
    print("Press Ctrl+C to terminate and view the final summary.\n")

    try:
        # Read character by character
        while True:
            char = sys.stdin.read(1)
            if not char:
                break  # EOF reached

            # Case-sensitive check (or change to char.upper() if needed)
            if char == 'A':
                pass_count += 1
            elif char == 'B':
                fail_count += 1
            elif char in ('\r', '\n', ' ', '\t'):
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
    print("        FINAL TEST SUMMARY        ")
    print("=" * 35)
    print(f"  Total Runs  : {total}")
    print(f"  Passed (A)  : {pass_count}")
    print(f"  Failed (B)  : {fail_count}")
    print(f"  Pass Rate   : {pass_rate:.2f}%")
    if other_count > 0:
        print(f"  Unexpected  : {other_count}")
    print("=" * 35)

if __name__ == "__main__":
    main()
