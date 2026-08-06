#!/usr/bin/env python3
import random
import sys
import time

CSI = "\x1b["
RESET = f"{CSI}0m"
BOLD  = f"{CSI}1m"
DIM   = f"{CSI}2m"

# Heat Palette: 12 levels mapping (heat_val -> (ANSI_color_sequence, ASCII_char))
# Smooth transition: Dark Blue -> Red -> Orange -> Yellow -> Bright White
FIRE_PALETTE = [
    (f"{CSI}30m",     " "),   # 0:  Off / Black
    (f"{CSI}34m",     "."),   # 1:  Dim Blue Ember
    (f"{CSI}31m",     "."),   # 2:  Dark Red
    (f"{CSI}31m",     ":"),   # 3:  Red
    (f"{CSI}91m",     ":"),   # 4:  Bright Red
    (f"{CSI}91;1m",   "*"),   # 5:  Bold Bright Red
    (f"{CSI}33m",     "*"),   # 6:  Dark Yellow / Orange
    (f"{CSI}93m",     "s"),   # 7:  Bright Yellow
    (f"{CSI}93;1m",   "S"),   # 8:  Bold Bright Yellow
    (f"{CSI}97m",     "#"),   # 9:  Bright White
    (f"{CSI}97;1m",   "$"),   # 10: Bold White
    (f"{CSI}97;1m",   "W"),   # 11: Super Hot Center (White W)
]

MAX_HEAT = len(FIRE_PALETTE) - 1

def pos(r, c):
    return f"{CSI}{r};{c}H"

def main():
    sys.stdout.write(f"{CSI}?25l{CSI}2J") # Hide cursor, clear screen
    sys.stdout.flush()

    width, height = 70, 20
    top_row, left_col = 3, 5

    # 2D heat buffer initialized to 0 (cold)
    fire_pixels = [[0] * width for _ in range(height)]

    frame = 0

    try:
        while True:
            # 1. Seed the bottom row with maximum heat source
            for c in range(width):
                # Add slight random flickering to the embers at the base
                fire_pixels[height - 1][c] = MAX_HEAT if random.random() > 0.1 else MAX_HEAT - 2

            # 2. Propagate heat upwards (Classic Doom Fire algorithm)
            for r in range(height - 1):
                for c in range(width):
                    # Random decay & wind drift factors
                    decay = random.randint(0, 2)
                    decay_y = random.randint(0, 1)
                    wind = random.randint(-1, 1)

                    src_r = min(height - 1, r + decay_y + 1)
                    src_c = (c + wind) % width

                    current_heat = fire_pixels[src_r][src_c]
                    new_heat = max(0, current_heat - decay)
                    fire_pixels[r][c] = new_heat

            # 3. Build ANSI frame buffer with delta-compression
            buf = [pos(1, 1), f"{BOLD}{CSI}91m DOOM FIRE DEMO | {CSI}93m230.4k UART Test | Frame: {frame:<6}{RESET}"]

            for r in range(height):
                buf.append(pos(top_row + r, left_col))
                last_style = None
                line_str = []

                for c in range(width):
                    heat_val = fire_pixels[r][c]
                    style, char = FIRE_PALETTE[heat_val]

                    # Delta compression: only send escape sequence if color changed
                    if style != last_style:
                        line_str.append(style)
                        last_style = style
                    
                    line_str.append(char)

                line_str.append(RESET)
                buf.append("".join(line_str))

            sys.stdout.write("".join(buf))
            sys.stdout.flush()

            frame += 1
#            time.sleep(0.025) # ~40 FPS

    except KeyboardInterrupt:
        sys.stdout.write(pos(top_row + height + 2, 1) + f"{CSI}?25h{RESET}\n")
        sys.stdout.flush()

if __name__ == "__main__":
    main()
