#!/usr/bin/env python3
import math
import sys
import time

# VT100 / ANSI Escape Sequences
ESC = "\x1b"
CSI = f"{ESC}["

CLEAR_SCREEN = f"{CSI}2J"
HOME         = f"{CSI}H"
RESET        = f"{CSI}0m"
BOLD         = f"{CSI}1m"
DIM          = f"{CSI}2m"

def pos(row, col):
    """Set absolute cursor position (1-indexed)."""
    return f"{CSI}{row};{col}H"

def main():
    # 1. Clear screen once at start
    sys.stdout.write(CLEAR_SCREEN)
    sys.stdout.flush()

    # Box dimensions
    box_w, box_h = 76, 16
    top_row, left_col = 4, 3

    # Sprite state
    x, y = 5, 2
    dx, dy = 1, 1
    frame = 0

    try:
        while True:
            buf = []
            buf.append(HOME)

            # --- 1. Header: Dynamic Spectrum using Bright FG (90-97) + Bold/Dim ---
            buf.append(f"{BOLD}{CSI}93m=== VT100 RTL ANIMATED STRESS TEST ==={RESET}\r\n")

            bar = []
            for i in range(48):
                fg = 90 + ((i + frame) % 8)  # Bright FG range 90-97
                attr = BOLD if math.sin((i + frame) * 0.25) > 0 else DIM
                bar.append(f"{CSI}{fg}m{attr}o{RESET}")
            buf.append(f"  {''.join(bar)}\r\n")

            # --- 2. Outer Border ---
            buf.append(pos(top_row - 1, left_col - 1))
            buf.append(f"{CSI}90m+{'-' * box_w}+{RESET}")

            for r in range(box_h):
                buf.append(pos(top_row + r, left_col - 1))
                buf.append(f"{CSI}90m3{RESET}")
                buf.append(pos(top_row + r, left_col + box_w))
                buf.append(f"{CSI}90m3{RESET}")

            buf.append(pos(top_row + box_h, left_col - 1))
            buf.append(f"{CSI}90m+{'-' * box_w}+{RESET}")

            # --- 3. Animated Waves: Testing Standard (40-47) & Bright (100-107) BG ---
            for r in range(box_h):
                buf.append(pos(top_row + r, left_col))
                row_chars = []
                for c in range(box_w):
                    # Compute wave pattern
                    val = math.sin((c * 0.12) + (frame * 0.12)) + math.cos((r * 0.3) + (frame * 0.1))

                    if val > 1.25:
                        bg = 100 + ((r + c + frame // 2) % 8)  # Bright BG (100-107)
                        fg = 30                              # Black FG
                        row_chars.append(f"{CSI}{fg};{bg}m {RESET}")
                    elif val < -1.25:
                        bg = 40 + ((r + c + frame // 2) % 8)   # Standard BG (40-47)
                        fg = 97                              # Bright White FG
                        row_chars.append(f"{CSI}{fg};{bg}m {RESET}")
                    else:
                        row_chars.append(" ")
                buf.append("".join(row_chars))

            # --- 4. Bouncing Sprite Logic ---
            x += dx
            y += dy

            if x <= 0 or x >= box_w - 12:
                dx *= -1
                x += dx
            if y <= 0 or y >= box_h - 1:
                dy *= -1
                y += dy

            # Compound sequence: Bright BG + Standard FG + Bold
            sprite_bg = 100 + ((frame // 3) % 8)
            sprite_fg = 30 + ((frame // 2) % 8)
            sprite = f"{CSI}{sprite_fg};{sprite_bg};1m RTL-VT100 {RESET}"

            buf.append(pos(top_row + y, left_col + x))
            buf.append(sprite)

            # --- 5. Footer Diagnostics ---
            buf.append(pos(top_row + box_h + 1, 1))
            buf.append(
                f"{DIM}{CSI}37mFrame: {frame:<6} | "
                f"{BOLD}{CSI}92mFG: 90-97 OK {RESET}| "
                f"{BOLD}{CSI}104;30m BG: 100-107 OK {RESET}\r\n"
            )

            # Flush entire frame buffer in one network write
            sys.stdout.write("".join(buf))
            sys.stdout.flush()

            frame += 1
#            time.sleep(0.04)  # ~25 FPS

    except KeyboardInterrupt:
        sys.stdout.write(pos(top_row + box_h + 3, 1) + RESET + "\n")
        sys.stdout.flush()

if __name__ == "__main__":
    main()
