#!/usr/bin/env python3
import math
import random
import sys
import time

# CP437 Upper 128 & Extended Byte Literals
CP437_FULL  = b"\xdb"  # 0xDB -> Solid Block (█)
CP437_DARK  = b"\xb2"  # 0xB2 -> Dark Shade (▓)
CP437_MED   = b"\xb1"  # 0xB1 -> Medium Shade (▒)
CP437_LIGHT = b"\xb0"  # 0xB0 -> Light Shade (░)
CP437_TOP   = b"\xdf"  # 0xDF -> Upper Half Block (▀)
CP437_BOT   = b"\xdc"  # 0xDC -> Lower Half Block (▄)
CP437_FLARE = b"\xce"  # 0xCE -> Cross / Star Flare (┼)
CP437_SQUARE= b"\xfe"  # 0xFE -> Small Square Core (■)
CP437_DOT   = b"\xfa"  # 0xFA -> Subpixel Dot (·)
CP437_NONE  = b" "

# Double-Line Box Drawing Bytes
BOX_TL = b"\xc9"  # ╔
BOX_TR = b"\xbb"  # ╗
BOX_BL = b"\xc8"  # ╚
BOX_BR = b"\xbc"  # ╝
BOX_H  = b"\xcd"  # ═
BOX_V  = b"\xba"  # ║

ESC          = b"\x1b"
CSI          = b"\x1b["
CLEAR_SCREEN = b"\x1b[2J"
HIDE_CURSOR  = b"\x1b[?25l"
SHOW_CURSOR  = b"\x1b[?25h"
RESET        = b"\x1b[0m"

# Playfield Grid (80 subpixels wide x 48 subpixels high -> 80x24 text cells)
V_WIDTH   = 80
V_HEIGHT  = 46
TEXT_ROWS = V_HEIGHT // 2  # 24 text rows
TOP_ROW   = 3              # Text row offset
LEFT_COL  = 2              # Text col offset

NUM_STARS = 256
MAX_Z     = 100.0

# Color palette mapping
COLORS = {
    "dim_blue":   b"\x1b[34m",
    "cyan":       b"\x1b[96m",
    "bright_cyan":b"\x1b[96;1m",
    "yellow":     b"\x1b[93m",
    "white":      b"\x1b[97m",
    "hi_white":   b"\x1b[97;1m",
    "magenta":    b"\x1b[95;1m",
}

def pos(r, c):
    """1-indexed position sequence in bytes."""
    return f"\x1b[{r};{c}H".encode("ascii")

def draw_frame(out):
    """Draw boundary box around the 80x24 playfield."""
    buf = [CLEAR_SCREEN, HIDE_CURSOR]
    buf.append(pos(TOP_ROW - 1, LEFT_COL - 1) + b"\x1b[90m" + BOX_TL + (BOX_H * V_WIDTH) + BOX_TR + RESET)
    for r in range(TEXT_ROWS):
        buf.append(pos(TOP_ROW + r, LEFT_COL - 1) + b"\x1b[90m" + BOX_V + RESET)
        buf.append(pos(TOP_ROW + r, LEFT_COL + V_WIDTH) + b"\x1b[90m" + BOX_V + RESET)
    buf.append(pos(TOP_ROW + TEXT_ROWS, LEFT_COL - 1) + b"\x1b[90m" + BOX_BL + (BOX_H * V_WIDTH) + BOX_BR + RESET)
    out.write(b"".join(buf))
    out.flush()

class Star:
    def __init__(self):
        self.reset(initial=True)

    def reset(self, initial=False):
        # Coordinates relative to camera origin (0, 0)
        self.x = random.uniform(-100.0, 100.0)
        self.y = random.uniform(-60.0, 60.0)
        self.z = random.uniform(1.0, MAX_Z) if initial else MAX_Z

def main():
    out = sys.stdout.buffer
    draw_frame(out)

    stars = [Star() for _ in range(NUM_STARS)]
    prev_text_cells = {}
    frame_count = 0

    try:
        while True:
            frame_count += 1

            # Oscillate speed to create warp drive acceleration cycles
            warp_factor = 0 # (math.sin(frame_count * 0.04) + 1.0) / 2.0  # 0.0 to 1.0
            speed = 0.8 + (warp_factor ** 3) * 6.5                     # Cruise 0.8 -> Warp 7.3

            sub_grid = {}

            # 1. Project 3D stars into subpixel grid space
            for star in stars:
                star.z -= speed

                if star.z <= 0.5:
                    star.reset()
                    continue

                # Perspective Projection onto subpixel plane
                proj_scale = 32.0 / star.z
                sx = int((V_WIDTH / 2.0) + (star.x * proj_scale))
                sy = int((V_HEIGHT / 2.0) + (star.y * proj_scale))

                # Off-screen check
                if not (0 <= sx < V_WIDTH and 0 <= sy < V_HEIGHT):
                    if star.z < 20:  # Respawn if flew past camera view
                        star.reset()
                    continue

                # 2. Assign depth styling using CP437 symbols & colors
                z_ratio = star.z / MAX_Z

                if z_ratio > 0.65:
                    # Distant Stars: Dim & Small
                    color = "dim_blue"
                    glyph = CP437_DOT
                elif z_ratio > 0.35:
                    # Mid-distance: Light Shading
                    color = "cyan"
                    glyph = CP437_LIGHT
                elif z_ratio > 0.15:
                    # Close: Medium Shade / Square
                    color = "bright_cyan" if warp_factor < 0.5 else "yellow"
                    glyph = CP437_MED
                elif z_ratio > 0.05:
                    # Very Close: Dark Shade
                    color = "white"
                    glyph = CP437_DARK
                else:
                    # Warp Flare / Super Close Star
                    color = "hi_white"
                    glyph = CP437_FLARE if warp_factor > 0.6 else CP437_FULL

                sub_grid[(sy, sx)] = (color, glyph)

            # 3. Render 2x Subpixel cells to terminal
            buf = []
            
            # HUD Banner constructed entirely with raw byte slices
            bar_len = int(warp_factor * 12)
            speed_bar_bytes = (CP437_FULL * bar_len) + (b" " * (12 - bar_len))
            
            buf.append(pos(1, 1))
            buf.append(
                f"\x1b[1;97m CP437 WARP FIELD \x1b[0m| "
                f"\x1b[93mSpeed: {speed:4.1f}c \x1b[96m[".encode("ascii")
                + speed_bar_bytes
                + f"]\x1b[0m| \x1b[92mStars: {NUM_STARS}\x1b[0m".encode("ascii")
            )

            for cy in range(TEXT_ROWS):
                sub_y_top = cy * 2
                sub_y_bot = cy * 2 + 1

                for cx in range(V_WIDTH):
                    top_data = sub_grid.get((sub_y_top, cx))
                    bot_data = sub_grid.get((sub_y_bot, cx))

                    cell_key = (cy, cx)
                    cell_state = (top_data, bot_data)

                    # Differential update check
                    if prev_text_cells.get(cell_key) != cell_state:
                        buf.append(pos(TOP_ROW + cy, LEFT_COL + cx))

                        top_col, top_glyph = top_data if top_data else (None, None)
                        bot_col, bot_glyph = bot_data if bot_data else (None, None)

                        if top_col is None and bot_col is None:
                            buf.append(RESET + CP437_NONE)
                        elif top_col is not None and bot_col is None:
                            # Star in top subpixel -> Upper Half Block or custom glyph
                            if top_glyph in (CP437_DOT, CP437_FLARE, CP437_LIGHT):
                                buf.append(COLORS[top_col] + top_glyph)
                            else:
                                buf.append(COLORS[top_col] + CP437_TOP)
                        elif top_col is None and bot_col is not None:
                            # Star in bottom subpixel -> Lower Half Block or custom glyph
                            if bot_glyph in (CP437_DOT, CP437_FLARE, CP437_LIGHT):
                                buf.append(COLORS[bot_col] + bot_glyph)
                            else:
                                buf.append(COLORS[bot_col] + CP437_BOT)
                        else:
                            # Both subpixels active -> Dual color or combined block
                            if top_col == bot_col:
                                buf.append(COLORS[top_col] + top_glyph)
                            else:
                                buf.append(COLORS[top_col] + COLORS[bot_col].replace(b"[", b"[10") + CP437_TOP)

                        prev_text_cells[cell_key] = cell_state

            buf.append(RESET)
            out.write(b"".join(buf))
            out.flush()

#            time.sleep(0.025)  # ~40 FPS

    except KeyboardInterrupt:
        out.write(pos(TOP_ROW + TEXT_ROWS + 2, 1) + SHOW_CURSOR + RESET + b"\n")
        out.flush()

if __name__ == "__main__":
    main()
