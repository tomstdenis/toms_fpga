#!/usr/bin/env python3
import random
import sys
import time

# CP437 Raw Byte Literals
CP437_FULL  = b"\xdb"  # 0xDB -> Solid Block (█)
CP437_DARK  = b"\xb2"  # 0xB2 -> Dark Shade (▓)
CP437_MED   = b"\xb1"  # 0xB1 -> Medium Shade (▒)
CP437_LIGHT = b"\xb0"  # 0xB0 -> Light Shade (░)
CP437_TOP   = b"\xdf"  # 0xDF -> Upper Half Block (▀)
CP437_BOT   = b"\xdc"  # 0xDC -> Lower Half Block (▄)
CP437_NONE  = b" "
CP437_HEART = b"\x03"  # 0x03 -> CP437 Heart Character (♥)

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

# Subpixel Grid Dimensions (64 wide x 36 high -> occupies 64x18 text cells)
V_WIDTH   = 64
V_HEIGHT  = 36
TEXT_ROWS = V_HEIGHT // 2  # 18 rows
TOP_ROW   = 3              # Text row offset on screen
LEFT_COL  = 4              # Text col offset on screen

# Color palette: (fg_code, bg_code)
COLORS = {
    "red":     (b"\x1b[91m", b"\x1b[101m"),
    "magenta": (b"\x1b[95m", b"\x1b[105m"),
    "yellow":  (b"\x1b[93m", b"\x1b[103m"),
    "green":   (b"\x1b[92m", b"\x1b[102m"),
    "cyan":    (b"\x1b[96m", b"\x1b[106m"),
    "white":   (b"\x1b[97m", b"\x1b[107m"),
    "paddle":  (b"\x1b[93;1m", b"\x1b[103m"),
    "ball":    (b"\x1b[97;1m", b"\x1b[107m"),
}

# Textured shade pattern across a 5-character wide brick
SHADE_PATTERN = [CP437_DARK, CP437_MED, CP437_LIGHT, CP437_MED, CP437_DARK]

def pos(r, c):
    """1-indexed position sequence in bytes."""
    return f"\x1b[{r};{c}H".encode("ascii")

def draw_frame(out):
    """Draw boundary box around the 64x18 character playfield."""
    buf = [CLEAR_SCREEN, HIDE_CURSOR]
    buf.append(pos(TOP_ROW - 1, LEFT_COL - 1) + b"\x1b[90m" + BOX_TL + (BOX_H * V_WIDTH) + BOX_TR + RESET)
    for r in range(TEXT_ROWS):
        buf.append(pos(TOP_ROW + r, LEFT_COL - 1) + b"\x1b[90m" + BOX_V + RESET)
        buf.append(pos(TOP_ROW + r, LEFT_COL + V_WIDTH) + b"\x1b[90m" + BOX_V + RESET)
    buf.append(pos(TOP_ROW + TEXT_ROWS, LEFT_COL - 1) + b"\x1b[90m" + BOX_BL + (BOX_H * V_WIDTH) + BOX_BR + RESET)
    out.write(b"".join(buf))
    out.flush()

def create_bricks():
    """Create textured brick grid storing (color_key, shade_char) tuples."""
    bricks = {}
    palette = ["red", "magenta", "yellow", "green", "cyan", "white"]
    
    # 6 rows of bricks (each 2 subpixels high)
    for row in range(6):
        sub_y_top = 2 + (row * 2)
        sub_y_bot = sub_y_top + 1
        
        col_idx = 0
        for bx in range(2, V_WIDTH - 2, 6):  # Brick width = 5 subpixels, 1 gap
            color_key = palette[(row * 2 + col_idx * 3) % len(palette)]
            
            for x_offset in range(5):
                shade = SHADE_PATTERN[x_offset]
                bricks[(sub_y_top, bx + x_offset)] = (color_key, shade)
                bricks[(sub_y_bot, bx + x_offset)] = (color_key, shade)
            col_idx += 1

    return bricks

def main():
    out = sys.stdout.buffer
    draw_frame(out)

    bricks = create_bricks()

    # Game State (Subpixel coordinates)
    paddle_x = 26.0
    paddle_w = 12           # 12 subpixels wide
    paddle_y = V_HEIGHT - 2 # Row 34 subpixel

    ball_x = 32.0
    ball_y = 20.0
    ball_vx = 0.85
    ball_vy = 0.75

    score = 0
    level = 1
    lives = 3

    # Character-cell double buffer
    prev_text_cells = {}

    try:
        while True:
            # 1. Build subpixel grid for current frame
            sub_grid = {}

            # Populate bricks with textured shades
            for (by, bx), (color, shade) in bricks.items():
                sub_grid[(by, bx)] = (color, shade)

            # Populate paddle (2 subpixels thick)
            px_start = int(paddle_x)
            for px in range(px_start, px_start + paddle_w):
                if 0 <= px < V_WIDTH:
                    sub_grid[(paddle_y, px)] = ("paddle", CP437_FULL)
                    sub_grid[(paddle_y + 1, px)] = ("paddle", CP437_FULL)

            # Populate ball (1 subpixel)
            bx_int, by_int = int(ball_x), int(ball_y)
            sub_grid[(by_int, bx_int)] = ("ball", CP437_FULL)

            # 2. Render subpixel grid via differential updates
            buf = []
            
            # Header with raw CP437 byte lives display (0x03)
            lives_bytes = (CP437_HEART + b" ") * lives
            buf.append(pos(1, 1))
            buf.append(
                f"\x1b[1;93m BREAKOUT 2X (CP437) \x1b[0m| "
                f"\x1b[97mScore: {score:<5}\x1b[0m| "
                f"\x1b[92mLevel: {level:<2}\x1b[0m| "
                f"\x1b[91mLives: ".encode("ascii")
                + lives_bytes.ljust(8)
                + b"\x1b[0m"
            )

            for cy in range(TEXT_ROWS):
                sub_y_top = cy * 2
                sub_y_bot = cy * 2 + 1

                for cx in range(V_WIDTH):
                    top_data = sub_grid.get((sub_y_top, cx))
                    bot_data = sub_grid.get((sub_y_bot, cx))

                    cell_key = (cy, cx)
                    cell_state = (top_data, bot_data)

                    # Only emit bytes if cell state changed
                    if prev_text_cells.get(cell_key) != cell_state:
                        buf.append(pos(TOP_ROW + cy, LEFT_COL + cx))

                        top_col, top_glyph = top_data if top_data else (None, None)
                        bot_col, bot_glyph = bot_data if bot_data else (None, None)

                        if top_col is None and bot_col is None:
                            buf.append(RESET + CP437_NONE)
                        elif top_col is not None and bot_col is None:
                            buf.append(COLORS[top_col][0] + CP437_TOP)
                        elif top_col is None and bot_col is not None:
                            buf.append(COLORS[bot_col][0] + CP437_BOT)
                        elif top_col == bot_col and top_glyph == bot_glyph:
                            # Both halves identical -> render full character glyph
                            buf.append(COLORS[top_col][0] + top_glyph)
                        else:
                            # Dual-color or mixed half-cell
                            fg = COLORS[top_col][0]
                            bg = COLORS[bot_col][1]
                            buf.append(fg + bg + CP437_TOP)

                        prev_text_cells[cell_key] = cell_state

            buf.append(RESET)
            out.write(b"".join(buf))
            out.flush()

            # 3. Physics Sub-Stepping (Prevents Tunneling)
            sub_steps = max(1, int(max(abs(ball_vx), abs(ball_vy)) / 0.4))
            dt_vx = ball_vx / sub_steps
            dt_vy = ball_vy / sub_steps

            ball_died = False

            for _ in range(sub_steps):
                next_bx = ball_x + dt_vx
                next_by = ball_y + dt_vy

                # Wall Collisions (Left / Right)
                if next_bx <= 0 or next_bx >= V_WIDTH - 1:
                    ball_vx = -ball_vx
                    dt_vx = -dt_vx
                    next_bx = max(0.0, min(float(V_WIDTH - 1), next_bx))

                # Wall Collision (Top)
                if next_by <= 0:
                    ball_vy = -ball_vy
                    dt_vy = -dt_vy
                    next_by = 0.0

                # Paddle Collision
                if next_by >= paddle_y - 1 and ball_y < paddle_y:
                    if px_start - 1 <= next_bx <= px_start + paddle_w + 1:
                        ball_vy = -abs(ball_vy)
                        dt_vy = -abs(dt_vy)
                        
                        hit_offset = (next_bx - (paddle_x + paddle_w / 2.0)) / (paddle_w / 2.0)
                        jitter = random.uniform(-0.25, 0.25)
                        ball_vx = (hit_offset * 1.3) + jitter

                        # Anti-deadlock safeguard
                        if abs(ball_vx) < 0.25:
                            ball_vx = 0.25 if random.random() < 0.5 else -0.25

                        # Cap max speeds
                        ball_vx = max(-1.4, min(1.4, ball_vx))
                        ball_vy = max(-1.1, min(1.1, ball_vy))

                        next_by = paddle_y - 1

                # Bottom Death Boundary
                if next_by >= V_HEIGHT - 1:
                    ball_died = True
                    break

                # Exact Brick Erasure Logic
                b_hit_x, b_hit_y = int(next_bx), int(next_by)
                if (b_hit_y, b_hit_x) in bricks:
                    # Calculate exact grid origin for the hit brick
                    pair_top = 2 + ((b_hit_y - 2) // 2) * 2
                    bx_start = 2 + ((b_hit_x - 2) // 6) * 6

                    # Wipe all 5 subpixel columns across both rows (entire brick)
                    for x in range(bx_start, bx_start + 5):
                        bricks.pop((pair_top, x), None)
                        bricks.pop((pair_top + 1, x), None)

                    ball_vy = -ball_vy
                    dt_vy = -dt_vy
                    score += 50
                    
                    # Gradual speed scaling
                    ball_vx = max(-1.5, min(1.5, ball_vx * 1.015))
                    ball_vy = max(-1.1, min(1.1, ball_vy * 1.015))
                    break  # Stop sub-stepping on brick bounce

                ball_x = next_bx
                ball_y = next_by

            if ball_died:
                lives -= 1
                if lives <= 0:
                    lives = 3
                    score = 0
                    level = 1
                    bricks = create_bricks()
                    prev_text_cells.clear()

                ball_x, ball_y = 32.0, 20.0
                ball_vx, ball_vy = 0.85, 0.75
                paddle_x = 26.0
                time.sleep(0.5)
                continue

            # AI Paddle Autopilot
            paddle_target = ball_x - (paddle_w / 2.0)
            paddle_x += (paddle_target - paddle_x) * 0.35
            paddle_x = max(0.0, min(float(V_WIDTH - paddle_w), paddle_x))

            # Auto level clear check
            if not bricks:
                level += 1
                bricks = create_bricks()
                prev_text_cells.clear()
                ball_x, ball_y = 32.0, 20.0
                ball_vx = 0.85 * (1.08 ** level)
                ball_vy = 0.75 * (1.08 ** level)

#            time.sleep(0.03)  # ~33 FPS

    except KeyboardInterrupt:
        out.write(pos(TOP_ROW + TEXT_ROWS + 2, 1) + SHOW_CURSOR + RESET + b"\n")
        out.flush()

if __name__ == "__main__":
    main()
