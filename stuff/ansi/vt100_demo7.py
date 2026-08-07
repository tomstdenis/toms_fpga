#!/usr/bin/env python3
from collections import deque
import random
import sys
import time

# ANSI Escape Sequences as Byte Literals
ESC          = b"\x1b"
CSI          = b"\x1b["
CLEAR_SCREEN = b"\x1b[2J"
HIDE_CURSOR  = b"\x1b[?25l"
SHOW_CURSOR  = b"\x1b[?25h"
RESET        = b"\x1b[0m"
BOLD         = b"\x1b[1m"

# CP437 Byte Definitions (Raw 8-bit Bytes)
CP437_FULL_BLOCK  = b"\xdb"  # 0xDB -> Solid Block (█)
CP437_DARK_SHADE  = b"\xb2"  # 0xB2 -> Dark Shade (▓)
CP437_LIGHT_SHADE = b"\xb0"  # 0xB0 -> Light Shade (░)
CP437_SPACE        = b" "

# CP437 Double-Line Box Drawing Bytes
BOX_TL = b"\xc9"  # ╔
BOX_TR = b"\xbb"  # ╗
BOX_BL = b"\xc8"  # ╚
BOX_BR = b"\xbc"  # ╝
BOX_H  = b"\xcd"  # ═
BOX_V  = b"\xba"  # ║

def pos(r, c):
    """Return 1-indexed position escape sequence as bytes."""
    return f"\x1b[{r};{c}H".encode("ascii")

def get_grid_hash(grid):
    """Generate a fast hash of alive/dead cell states (ignoring age)."""
    return hash(tuple(tuple(1 if cell > 0 else 0 for cell in row) for row in grid))

def main():
    out = sys.stdout.buffer

    # Clear screen & hide cursor
    out.write(CLEAR_SCREEN + HIDE_CURSOR)
    out.flush()

    width, height = 64, 20
    top_row, left_col = 3, 4

    # 1. Draw CP437 Box Frame
    border = []
    border.append(pos(top_row - 1, left_col - 1) + b"\x1b[90m" + BOX_TL + (BOX_H * width) + BOX_TR + RESET)
    for r in range(height):
        border.append(pos(top_row + r, left_col - 1) + b"\x1b[90m" + BOX_V + RESET)
        border.append(pos(top_row + r, left_col + width) + b"\x1b[90m" + BOX_V + RESET)
    border.append(pos(top_row + height, left_col - 1) + b"\x1b[90m" + BOX_BL + (BOX_H * width) + BOX_BR + RESET)
    out.write(b"".join(border))
    out.flush()

    # Grid states
    grid = [[0] * width for _ in range(height)]
    prev_grid = [[-1] * width for _ in range(height)]

    # History buffer to detect period-1 through period-16 loops
    history = deque(maxlen=16)

    def seed_random():
        nonlocal prev_grid
        for r in range(height):
            for c in range(width):
                grid[r][c] = 1 if random.random() < 0.28 else 0
        # Force full redraw on re-seed
        prev_grid = [[-1] * width for _ in range(height)]
        history.clear()

    seed_random()
    generation = 0
    reseed_count = 0

    try:
        while True:
            buf = []

            # Check for stagnation / fixed-point loop
            current_hash = get_grid_hash(grid)
            is_stagnant = current_hash in history
            history.append(current_hash)

            # Header info line
            buf.append(pos(1, 1))
            status_tag = b""; # b"\x1b[1;91m[ LOOP DETECTED - RE-SEEDING ]\x1b[0m" if is_stagnant else b"\x1b[92mRUNNING\x1b[0m"
            buf.append(
                b"\x1b[1;93m VT100 LIFE \x1b[0m| "
                + f"\x1b[97mGen: {generation:<5}\x1b[0m| ".encode("ascii")
                + f"\x1b[96mReseeds: {reseed_count:<3}\x1b[0m| ".encode("ascii")
                + status_tag
            )

            # 2. Render Grid via Differential Byte Updates
            active_cells = 0
            for r in range(height):
                for c in range(width):
                    val = grid[r][c]
                    if val > 0:
                        active_cells += 1

                    if val != prev_grid[r][c]:
                        buf.append(pos(top_row + r, left_col + c))

                        if val == 1:
                            # Newborn: Bold Bright White + Full Block (0xDB)
                            buf.append(b"\x1b[97;1m" + CP437_FULL_BLOCK)
                        elif val == 2:
                            # Young: Bold Bright Green + Full Block (0xDB)
                            buf.append(b"\x1b[92;1m" + CP437_FULL_BLOCK)
                        elif val >= 3:
                            # Mature: Dim Green + Dark Shade (0xB2)
                            buf.append(b"\x1b[32m" + CP437_DARK_SHADE)
                        elif prev_grid[r][c] > 0 and val == 0:
                            # Ghost Trail: Bright Black + Light Shade (0xB0)
                            buf.append(b"\x1b[90m" + CP437_LIGHT_SHADE)
                        else:
                            # Dead Space
                            buf.append(RESET + CP437_SPACE)

                        prev_grid[r][c] = val

            buf.append(RESET)
            out.write(b"".join(buf))
            out.flush()

            # Trigger immediate re-seed if stagnant or extinction occurs
            if is_stagnant or active_cells == 0:
                time.sleep(0.4)  # Pause briefly so the user sees the loop flag
                reseed_count += 1
                seed_random()
                continue

            # 3. Compute Next Generation
            next_grid = [[0] * width for _ in range(height)]
            for r in range(height):
                for c in range(width):
                    neighbors = 0
                    for dr in (-1, 0, 1):
                        for dc in (-1, 0, 1):
                            if dr == 0 and dc == 0:
                                continue
                            nr = (r + dr) % height
                            nc = (c + dc) % width
                            if grid[nr][nc] > 0:
                                neighbors += 1

                    if grid[r][c] > 0:
                        if neighbors in (2, 3):
                            next_grid[r][c] = grid[r][c] + 1
                        else:
                            next_grid[r][c] = 0
                    else:
                        if neighbors == 3:
                            next_grid[r][c] = 1

            grid = next_grid
            generation += 1
#            time.sleep(0.04)  # ~25 FPS

    except KeyboardInterrupt:
        out.write(pos(top_row + height + 2, 1) + SHOW_CURSOR + RESET + b"\n")
        out.flush()

if __name__ == "__main__":
    main()
