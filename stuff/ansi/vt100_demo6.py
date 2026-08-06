#!/usr/bin/env python3
import sys
import time

ESC = "\x1b"
CSI = f"{ESC}["
RESET = f"{CSI}0m"
BOLD = f"{CSI}1m"

# VT100 Save / Restore Cursor
DECSC = f"{ESC}7"   # Save cursor pos & attributes
DECRC = f"{ESC}8"   # Restore cursor pos & attributes

# ANSI.SYS alternative Save/Restore (included for completeness)
ANSI_SAVE    = f"{CSI}s"
ANSI_RESTORE = f"{CSI}u"

# Erase in Line (K)
EL_TO_END   = f"{CSI}0K" # Or just CSI K
EL_TO_START = f"{CSI}1K"
EL_ALL      = f"{CSI}2K"

# Erase in Display (J)
ED_TO_END   = f"{CSI}0J" # Or just CSI J
ED_TO_START = f"{CSI}1J"
ED_ALL      = f"{CSI}2J"

def pos(r, c):
    return f"{CSI}{r};{c}H"

def write(text):
    sys.stdout.write(text)
    sys.stdout.flush()

def step_header(title):
    write(pos(1, 1) + EL_ALL)
    write(f"{BOLD}{CSI}93m=== TEST: {title} ==={RESET}\r\n")

def main():
    # Clear screen initially
    write(ED_ALL + pos(1, 1))
    time.sleep(1)

    # =========================================================================
    # TEST 1: Erase in Line (K)
    # =========================================================================
    step_header("Erase in Line (K)")
    
    # Draw 3 reference lines
    write(pos(3, 1) + f"{CSI}96mLine 1: [0000000000MIDPOINT1111111111]{RESET}")
    write(pos(4, 1) + f"{CSI}96mLine 2: [0000000000MIDPOINT1111111111]{RESET}")
    write(pos(5, 1) + f"{CSI}96mLine 3: [0000000000MIDPOINT1111111111]{RESET}")
    time.sleep(2.5)

    # 1a. Test 0K (Erase from cursor to END of line)
    write(pos(3, 20) + EL_TO_END)  # Cursor at 'M' in MIDPOINT
    write(pos(7, 1) + f"1. Issued {BOLD}CSI 0K{RESET} on Line 1 at MIDPOINT -> Right side erased?")
    time.sleep(5)

    # 1b. Test 1K (Erase from START of line to cursor)
    write(pos(4, 20) + EL_TO_START) # Cursor at 'M' in MIDPOINT
    write(pos(8, 1) + f"2. Issued {BOLD}CSI 1K{RESET} on Line 2 at MIDPOINT -> Left side erased?")
    time.sleep(5)

    # 1c. Test 2K (Erase ENTIRE line)
    write(pos(5, 20) + EL_ALL)
    write(pos(9, 1) + f"3. Issued {BOLD}CSI 2K{RESET} on Line 3 -> Entire line cleared?")
    time.sleep(5)

    # =========================================================================
    # TEST 2: Save & Restore Cursor (ESC 7 / ESC 8)
    # =========================================================================
    write(ED_ALL)
    step_header("Save / Restore Cursor (ESC 7 / ESC 8)")

    write(pos(4, 1) + "Target Box: [   ]")
    
    # Move cursor inside the brackets (Row 4, Col 14)
    write(pos(4, 14))
    write(DECSC) # SAVE CURSOR POSITION

    # Jump somewhere far away and draw noise
    write(pos(10, 1) + f"{CSI}91m-> Jumped to Row 10 to write debug log...{RESET}")
    time.sleep(5)

    # Restore cursor position
    write(DECRC) # RESTORE CURSOR POSITION
    write(f"{CSI}92;1mOK!{RESET}") # Should land directly inside [ OK! ]

    write(pos(12, 1) + f"If cursor restore worked, {BOLD}'OK!'{RESET} should be inside the box above.")
    time.sleep(5)

    # =========================================================================
    # TEST 3: Erase in Display - 1J (Start to Cursor)
    # =========================================================================
    write(ED_ALL)
    step_header("Erase in Display (1J - Start of Screen to Cursor)")

    # Fill a 8x30 grid with '#'
    for r in range(3, 11):
        write(pos(r, 1) + f"{CSI}36m" + "#" * 30 + RESET)
    time.sleep(5)

    # Move cursor to Row 6, Col 15 and trigger 1J
    write(pos(6, 15) + ED_TO_START)
    write(pos(12, 1) + f"Issued {BOLD}CSI 1J{RESET} at Row 6, Col 15 -> Top-left block wiped?")
    time.sleep(5)

    # =========================================================================
    # TEST 4: Erase in Display - 0J (Cursor to End)
    # =========================================================================
    write(ED_ALL)
    step_header("Erase in Display (0J - Cursor to End of Screen)")

    # Refill grid
    for r in range(3, 11):
        write(pos(r, 1) + f"{CSI}36m" + "#" * 30 + RESET)
    time.sleep(5)

    # Move cursor to Row 6, Col 15 and trigger 0J
    write(pos(6, 15) + ED_TO_END)
    write(pos(12, 1) + f"Issued {BOLD}CSI 0J{RESET} at Row 6, Col 15 -> Bottom-right block wiped?")
    time.sleep(5)

    # Final cleanup
    write(pos(14, 1) + f"{BOLD}{CSI}92m=== SUITE COMPLETE ==={RESET}\r\n")

if __name__ == "__main__":
    main()
