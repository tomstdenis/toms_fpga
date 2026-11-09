import math
import os
import random
import sys
import time

# VT100 / ANSI escape codes
CLEAR = "\033[2J"
HOME = "\033[H"
HIDE_CURSOR = "\033[?25l"
SHOW_CURSOR = "\033[?25h"

# ANSI Colors
YELLOW = "\033[33m"
GREEN = "\033[32m"
WHITE = "\033[37m"
RESET = "\033[0m"

WIDTH, HEIGHT = 60, 20

# ASCII Art definitions (House only)
HOUSE = [
    "        /--\\        ",
    "       /    \\       ",
    "      /______\\      ",
    "     /        \\     ",
    "    /__________\\    ",
    "    |  __  __  |    ",
    "    | |  ||  | |    ",
    "    | |__|.__| |    ",
    "    |____[__]__|    ",
]

def main():
    # 1. Clear the screen at the start and hide the blinking cursor
    sys.stdout.write(HIDE_CURSOR + CLEAR)
    sys.stdout.flush()

    # Center point of the screen for circular star rotation
    center_x = WIDTH / 2.0
    center_y = 6.5  # Centered in the upper sky region

    # Generate stars with initial angles, distances, and rotation speeds
    num_stars = 35
    stars = []
    for _ in range(num_stars):
        angle = random.uniform(0, 2 * math.pi)
        distance = random.uniform(2, 22)  # Orbit radius
        speed = random.choice([-0.03, -0.02, 0.02, 0.03])  # Direction and speed
        stars.append([angle, distance, speed])
    
    try:
        while True:
            # Create a blank character buffer for the frame
            buffer = [[" " for _ in range(WIDTH)] for _ in range(HEIGHT)]

            # 2. Update and render rotating stars in the sky
            for star in stars:
                # Advance angle
                star[0] += star[2]

                # Calculate screen coordinates using polar-to-cartesian conversion
                # Note: Terminal columns are spaced wider than rows, so we scale x by 2.0 to keep orbits circular
                sx = int(round(center_x + (math.cos(star[0]) * star[1] * 2.0)))
                sy = int(round(center_y + (math.sin(star[0]) * star[1])))

                # Keep stars strictly inside the upper sky boundary (avoiding ground y >= 14 and margins)
                if 0 <= sx < WIDTH and 1 <= sy < 14:
                    # Randomly shift character style for a twinkling effect
                    if random.random() < 0.4:
                        char = random.choice(['*', '.', '+', '`', '-'])
                    else:
                        char = '.'
                    buffer[sy][sx] = char

            # 3. Render ground / landscape
            for x in range(WIDTH):
                buffer[14][x] = "~"
                for y in range(15, HEIGHT):
                    buffer[y][x] = "#"

            # 4. Stamp the House (overwriting spaces explicitly)
            house_x, house_y = 20, 6
            for i, row in enumerate(HOUSE):
                for j, char in enumerate(row):
                    hx, hy = house_x + j, house_y + i
                    if 0 <= hx < WIDTH and 0 <= hy < HEIGHT:
                        buffer[hy][hx] = char

            # 5. Build frame string with ANSI color coding
            output = [HOME]
            output.append(f"{WHITE}=== VT100 ROTATING NIGHT SKY (Press Ctrl+C to exit) ==={RESET}\n")
            
            for y in range(HEIGHT):
                row_str = ""
                for x in range(WIDTH):
                    ch = buffer[y][x]
                    if ch in ['*', '.', '+', '`', '-']:
                        row_str += f"{YELLOW}{ch}{RESET}"
                    elif y >= 14:
                        row_str += f"{GREEN}{ch}{RESET}"
                    elif ch in ['/\\|_-[]{}']:
                        row_str += f"{WHITE}{ch}{RESET}"
                    else:
                        row_str += ch
                output.append(row_str + "\n")

            # Write entire frame at once to avoid screen tearing
            sys.stdout.write("".join(output))
            sys.stdout.flush()

            # Frame delay for smooth orbital movement
            time.sleep(0.08)

    except KeyboardInterrupt:
        pass
    finally:
        # Always restore cursor and clear screen cleanly on exit
        sys.stdout.write(SHOW_CURSOR + CLEAR + HOME)
        sys.stdout.flush()

if __name__ == "__main__":
    main()
