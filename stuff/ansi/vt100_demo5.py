#!/usr/bin/env python3
import random
import sys
import time

CSI = "\x1b["
RESET = f"{CSI}0m"
BOLD  = f"{CSI}1m"
DIM   = f"{CSI}2m"

def pos(r, c):
    """Set absolute cursor position (1-indexed)."""
    return f"{CSI}{r};{c}H"

def main():
    # Hide cursor & clear screen once
    sys.stdout.write(f"{CSI}?25l{CSI}2J")
    sys.stdout.flush()

    box_w, box_h = 52, 16
    top_row, left_col = 3, 4

    # Brick setup: 4 rows of 10 bricks (each brick is 5 chars wide: [===])
    brick_colors = [
        ("91;1m", "[===]"),  # Row 0: Bold Bright Red
        ("93;1m", "[===]"),  # Row 1: Bold Bright Yellow
        ("92;1m", "[===]"),  # Row 2: Bold Bright Green
        ("96;1m", "[===]"),  # Row 3: Bold Bright Cyan
    ]

    def create_bricks():
        b = {}
        for r in range(4):
            color, text = brick_colors[r]
            for c in range(10):
                bx = left_col + 1 + (c * 5)
                by = top_row + 2 + r
                b[(r, c)] = (bx, by, color, text)
        return b

    bricks = create_bricks()

    # Draw static outer border ONCE
    border_buf = []
    border_buf.append(pos(top_row, left_col) + f"{CSI}90m+" + "-" * (box_w - 2) + f"+{RESET}")
    for r in range(1, box_h - 1):
        border_buf.append(pos(top_row + r, left_col) + f"{CSI}90m|{RESET}")
        border_buf.append(pos(top_row + r, left_col + box_w - 1) + f"{CSI}90m|{RESET}")
    border_buf.append(pos(top_row + box_h - 1, left_col) + f"{CSI}90m+" + "-" * (box_w - 2) + f"+{RESET}")

    # Draw initial bricks ONCE
    for _, (bx, by, color, text) in bricks.items():
        border_buf.append(pos(by, bx) + f"{CSI}{color}{text}{RESET}")

    sys.stdout.write("".join(border_buf))
    sys.stdout.flush()

    # Game State
    paddle_w = 8
    paddle_x = float(left_col + (box_w // 2) - (paddle_w // 2))
    paddle_y = top_row + box_h - 2

    ball_x = float(left_col + box_w // 2)
    ball_y = float(paddle_y - 2)
    ball_dx = 0.5
    ball_dy = -0.5

    score = 0
    lives = 3
    level = 1
    frame = 0

    old_ball_pos = (int(ball_x), int(ball_y))
    old_paddle_x = int(paddle_x)

    try:
        while True:
            buf = []

            # 1. Update Header (Top line jump)
            buf.append(pos(1, 1))
            buf.append(
                f"{BOLD}{CSI}93m VT100 AUTONOMOUS BREAKOUT {RESET}| "
                f"{CSI}97mScore: {score:<5} {RESET}| "
                f"{CSI}91mLives: {lives} {RESET}| "
                f"{CSI}92mLevel: {level:<2}{RESET}"
            )

            # 2. AI Paddle Logic (Tracks ball position with tracking lead)
            paddle_center = paddle_x + (paddle_w / 2.0)
            target_x = ball_x + (ball_dx * 2.0) if ball_dy > 0 else ball_x

            if paddle_center < target_x - 1:
                paddle_x += 0.70
            elif paddle_center > target_x + 1:
                paddle_x -= 0.70

            # Clamp paddle inside borders
            paddle_x = max(left_col + 1, min(left_col + box_w - 1 - paddle_w, paddle_x))

            # 3. Move Ball
            next_x = ball_x + ball_dx
            next_y = ball_y + ball_dy

            # Wall Collisions (Left / Right)
            if next_x <= left_col + 1:
                next_x = left_col + 1
                ball_dx = abs(ball_dx)
            elif next_x >= left_col + box_w - 2:
                next_x = left_col + box_w - 2
                ball_dx = -abs(ball_dx)

            # Ceiling Collision
            if next_y <= top_row + 1:
                next_y = top_row + 1
                ball_dy = abs(ball_dy)

            # Paddle Collision
            if next_y >= paddle_y and ball_y < paddle_y:
                if paddle_x <= next_x <= paddle_x + paddle_w:
                    next_y = paddle_y - 1
                    ball_dy = -abs(ball_dy)
                    # Add spin offset depending on where ball hits paddle
                    hit_pos = (next_x - paddle_x) / float(paddle_w)
                    ball_dx = (hit_pos - 0.5) * 1.55

            # Floor Collision (Life lost)
            if next_y >= top_row + box_h - 1:
                lives -= 1
                if lives <= 0:
                    # Reset Game
                    score = 0
                    lives = 3
                    level = 1
                    bricks = create_bricks()
                    for _, (bx, by, color, text) in bricks.items():
                        buf.append(pos(by, bx) + f"{CSI}{color}{text}{RESET}")

                # Respawn ball
                ball_x = float(left_col + box_w // 2)
                ball_y = float(paddle_y - 3)
                ball_dx = random.choice([-0.8, 0.8])
                ball_dy = -0.6
                next_x, next_y = ball_x, ball_y

            # 4. Brick Collisions
            b_row = int(next_y) - (top_row + 2)
            b_col = (int(next_x) - (left_col + 1)) // 5

            if 0 <= b_row < 4 and 0 <= b_col < 10:
                if (b_row, b_col) in bricks:
                    bx, by, _, _ = bricks[(b_row, b_col)]
                    del bricks[(b_row, b_col)]
                    score += (4 - b_row) * 10
                    ball_dy = -ball_dy
                    # Erase destroyed brick
                    buf.append(pos(by, bx) + " " * 5)

                    # Reset level if all cleared
                    if not bricks:
                        level += 1
                        bricks = create_bricks()
                        for _, (bx, by, color, text) in bricks.items():
                            buf.append(pos(by, bx) + f"{CSI}{color}{text}{RESET}")

            ball_x, ball_y = next_x, next_y

            # 5. Render Updates (Differential)
            curr_ball_pos = (int(ball_x), int(ball_y))
            curr_paddle_x = int(paddle_x)

            # Erase old ball
            if old_ball_pos != curr_ball_pos:
                buf.append(pos(old_ball_pos[1], old_ball_pos[0]) + " ")

            # Erase old paddle / Draw new paddle
            if old_paddle_x != curr_paddle_x:
                buf.append(pos(paddle_y, old_paddle_x) + " " * paddle_w)

            # Draw Paddle (Bright White BG with standard black FG text)
            buf.append(pos(paddle_y, curr_paddle_x) + f"{CSI}30;107;1m[======]{RESET}")

            # Draw Ball (Bold Bright White O)
            buf.append(pos(curr_ball_pos[1], curr_ball_pos[0]) + f"{CSI}97;1mO{RESET}")

            old_ball_pos = curr_ball_pos
            old_paddle_x = curr_paddle_x

            # Send minimal delta packet
            sys.stdout.write("".join(buf))
            sys.stdout.flush()

            frame += 1
#            time.sleep(0.025)  # ~40 FPS

    except KeyboardInterrupt:
        sys.stdout.write(pos(top_row + box_h + 2, 1) + f"{CSI}?25h{RESET}\n")
        sys.stdout.flush()

if __name__ == "__main__":
    main()
