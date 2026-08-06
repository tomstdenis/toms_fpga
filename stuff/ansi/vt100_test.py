#!/usr/bin/env python3
import sys

# VT100 / ANSI Escape Sequences
ESC = "\x1b"
CSI = f"{ESC}["

CLEAR_SCREEN = f"{CSI}2J"
CURSOR_HOME  = f"{CSI}1;1H"
RESET        = f"{CSI}0m"
BOLD         = f"{CSI}1m"
UNDERLINE    = f"{CSI}4m"
REVERSE      = f"{CSI}7m"

# 8 Standard ANSI / VT100 Colors
COLORS = [
    (0, "Black"),
    (1, "Red"),
    (2, "Green"),
    (3, "Yellow"),
    (4, "Blue"),
    (5, "Magenta"),
    (6, "Cyan"),
    (7, "White"),
]

def pos(row, col):
    """Set absolute cursor position (1-indexed)."""
    return f"{CSI}{row};{col}H"

def write(text):
    sys.stdout.write(text)

def main():
    # 1. Clear Screen & Draw Header
    write(CLEAR_SCREEN)
    write(CURSOR_HOME)
    write(f"{BOLD}{CSI}33m=== VT100 RTL EMULATOR TEST PATTERN ==={RESET}\r\n\r\n")

    # 2. Text Attributes Test
    write(f"{BOLD}Bold Text{RESET}  |  ")
    write(f"{UNDERLINE}Underline Text{RESET}  |  ")
    write(f"{REVERSE}Reverse Video{RESET}\r\n\r\n")

    # 3. Foreground Colors (30..37)
    write(f"{BOLD}--- Foreground Colors (30-37) ---{RESET}\r\n")
    for code, name in COLORS:
        fg_seq = f"{CSI}{30 + code}m"
        write(f"{fg_seq}{name:<8}{RESET} ")
    write("\r\n\r\n")

    # 4. Background Colors (40..47)
    write(f"{BOLD}--- Background Colors (40-47) ---{RESET}\r\n")
    for code, name in COLORS:
        bg_seq = f"{CSI}{40 + code}m"
        # Use white text on dark colors, black on light for readability
        fg_override = f"{CSI}30m" if code in (3, 6, 7) else f"{CSI}37m"
        write(f"{bg_seq}{fg_override} {name:<7} {RESET} ")
    write("\r\n\r\n")

    # 5. 8x8 Color Grid (FG vs BG)
    write(f"{BOLD}--- 8x8 FG / BG Matrix ---{RESET}\r\n   ")
    for bg_code, _ in COLORS:
        write(f" B{bg_code} ")
    write("\r\n")

    for fg_code, _ in COLORS:
        write(f"F{fg_code} ")
        for bg_code, _ in COLORS:
            seq = f"{CSI}{30 + fg_code};{40 + bg_code}m"
            write(f"{seq} X {RESET} ")
        write("\r\n")
    
    # 6. Absolute Cursor Positioning Test (Draw a frame box on right side)
    write(pos(15, 45) + f"{CSI}36m+-------------------+{RESET}")
    write(pos(16, 45) + f"{CSI}36m| {BOLD}Position Test{RESET}{CSI}36m     |{RESET}")
    write(pos(17, 45) + f"{CSI}36m| Line 16 Col 45    |{RESET}")
    write(pos(18, 45) + f"{CSI}36m+-------------------+{RESET}")

    # Move cursor to bottom out of the way
    write(pos(16, 1) + f"{RESET}\r\n")
    sys.stdout.flush()

if __name__ == "__main__":
    main()
