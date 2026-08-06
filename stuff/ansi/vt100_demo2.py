#!/usr/bin/env python3
import sys
import time

ESC = "\x1b"
CSI = f"{ESC}["
RESET = f"{CSI}0m"
BOLD = f"{CSI}1m"
DIM = f"{CSI}2m"

# Pure 7-bit ASCII character palette + ANSI styles
PALETTE = [
    (f"{CSI}34m",       "."),  # Dim Blue
    (f"{CSI}94m",       "."),  # Bright Blue
    (f"{CSI}36m",       ":"),  # Cyan
    (f"{CSI}96m",       ":"),  # Bright Cyan
    (f"{CSI}32m",       "-"),  # Green
    (f"{CSI}92m",       "="),  # Bright Green
    (f"{CSI}93m",       "+"),  # Bright Yellow
    (f"{CSI}33;1m",     "*"),  # Bold Yellow
    (f"{CSI}31m",       "#"),  # Red
    (f"{CSI}91;1m",     "%"),  # Bold Bright Red
    (f"{CSI}95;1m",     "@"),  # Bold Bright Magenta
    (f"{CSI}97;1m",     "W"),  # Bold Bright White
]

INSIDE_SET = (f"{CSI}30m", " ")  # Black interior

def pos(r, c):
    """Set absolute cursor position (1-indexed)."""
    return f"{CSI}{r};{c}H"

def render_frame(center_x, center_y, zoom, max_iter, width=78, height=22):
    buf = []
    
    # Header Line
    buf.append(pos(1, 1))
    buf.append(
        f"{BOLD}{CSI}93m VT100 RTL Mandelbrot | "
        f"{CSI}97mZoom: {zoom:>8.1f}x | "
        f"{CSI}96mIter: {max_iter:<3}{RESET}"
    )

    # 2:1 character aspect ratio correction
    range_x = 3.2 / zoom
    range_y = (range_x * (height / width) * 2.0)

    min_x = center_x - (range_x / 2.0)
    min_y = center_y - (range_y / 2.0)
    dx = range_x / width
    dy = range_y / height

    # Render Pixel Grid
    for r in range(height):
        cy = min_y + (r * dy)
        buf.append(pos(r + 2, 1))
        
        last_style = None

        for c in range(width):
            cx = min_x + (c * dx)

            # Mandelbrot core: z = z^2 + c
            zx, zy = 0.0, 0.0
            i = 0
            while (zx * zx + zy * zy <= 4.0) and (i < max_iter):
                zx, zy = (zx * zx - zy * zy + cx), (2.0 * zx * zy + cy)
                i += 1

            if i == max_iter:
                style, char = INSIDE_SET
            else:
                # Cycle palette smoothly based on iteration count
                style, char = PALETTE[i % len(PALETTE)]

            # ANSI Delta Compression
            if style != last_style:
                buf.append(style)
                last_style = style
                
            buf.append(char)

    buf.append(RESET)
    return "".join(buf)

def main():
    sys.stdout.write(f"{CSI}?25l{CSI}2J")
    sys.stdout.flush()

    # Target: Deep Spiral in Elephant Valley
    start_x, start_y = -0.5, 0.0
    target_x, target_y = -0.243643887037158704752191506114774, 0.131825904205311970493132056385139

    try:
        while True:
            steps = 90

            # Zoom In Phase
            for step in range(steps):
                progress = step / float(steps)
                # Smooth ease-in curve for zoom
                zoom = 0.001 + (1.01 ** step)
                
                # Scale max iterations up as zoom increases to maintain edge detail
                max_iter = int(32 + (step * 1.5))

                # Interpolate towards target coordinates
                cx = start_x + (target_x - start_x) * (progress ** 1.5)
                cy = start_y + (target_y - start_y) * (progress ** 1.5)

                frame_data = render_frame(cx, cy, zoom, max_iter)
                sys.stdout.write(frame_data)
                sys.stdout.flush()
                time.sleep(0.01)

            time.sleep(1.5)

            # Zoom Out Phase
            for step in range(steps, 0, -3):
                progress = step / float(steps)
                zoom = 1.0 + (1.14 ** step)
                max_iter = int(32 + (step * 1.5))

                cx = start_x + (target_x - start_x) * (progress ** 1.5)
                cy = start_y + (target_y - start_y) * (progress ** 1.5)

                frame_data = render_frame(cx, cy, zoom, max_iter)
                sys.stdout.write(frame_data)
                sys.stdout.flush()
                time.sleep(0.01)

    except KeyboardInterrupt:
        sys.stdout.write(pos(25, 1) + f"{CSI}?25h{RESET}\n")
        sys.stdout.flush()

if __name__ == "__main__":
    main()
