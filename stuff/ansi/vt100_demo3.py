#!/usr/bin/env python3
import math
import sys
import time

CSI = "\x1b["
RESET = f"{CSI}0m"
BOLD = f"{CSI}1m"
DIM = f"{CSI}2m"

# 8 Corner vertices of a unit cube
CUBE_VERTICES = [
    [-1, -1, -1], [ 1, -1, -1], [ 1,  1, -1], [-1,  1, -1],
    [-1, -1,  1], [ 1, -1,  1], [ 1,  1,  1], [-1,  1,  1]
]

# 12 Edges connecting the vertices (with color tags)
CUBE_EDGES = [
    (0, 1, "91m"), (1, 2, "91m"), (2, 3, "91m"), (3, 0, "91m"), # Back face (Red)
    (4, 5, "92m"), (5, 6, "92m"), (6, 7, "92m"), (7, 4, "92m"), # Front face (Green)
    (0, 4, "93m"), (1, 5, "93m"), (2, 6, "93m"), (3, 7, "93m")  # Connecting edges (Yellow)
]

def pos(r, c):
    return f"{CSI}{r};{c}H"

def draw_line(x0, y0, x1, y1, char_grid, width, height, char="#"):
    """Bresenham's Line Algorithm into a 2D grid."""
    dx = abs(x1 - x0)
    dy = abs(y1 - y0)
    sx = 1 if x0 < x1 else -1
    sy = 1 if y0 < y1 else -1
    err = dx - dy

    while True:
        if 0 <= x0 < width and 0 <= y0 < height:
            char_grid[y0][x0] = char
        if x0 == x1 and y0 == y1:
            break
        e2 = 2 * err
        if e2 > -dy:
            err -= dy
            x0 += sx
        if e2 < dx:
            err += dx
            y0 += sy

def main():
    sys.stdout.write(f"{CSI}?25l{CSI}2J") # Hide cursor, clear screen
    sys.stdout.flush()

    width, height = 70, 22
    top_row, left_col = 3, 5

    angle_x, angle_y, angle_z = 0.0, 0.0, 0.0
    frame = 0

    try:
        while True:
            # Grid buffers to track characters and color sequences
            grid = [[" "] * width for _ in range(height)]
            color_grid = [[""] * width for _ in range(height)]

            # 1. Compute 3D Rotations & 2D Projection
            rad_x, rad_y, rad_z = math.radians(angle_x), math.radians(angle_y), math.radians(angle_z)
            projected = []

            for vx, vy, vz in CUBE_VERTICES:
                # Rotate X
                y1 = vy * math.cos(rad_x) - vz * math.sin(rad_x)
                z1 = vy * math.sin(rad_x) + vz * math.cos(rad_x)
                # Rotate Y
                x2 = vx * math.cos(rad_y) + z1 * math.sin(rad_y)
                z2 = -vx * math.sin(rad_y) + z1 * math.cos(rad_y)
                # Rotate Z
                x3 = x2 * math.cos(rad_z) - y1 * math.sin(rad_z)
                y3 = x2 * math.sin(rad_z) + y1 * math.cos(rad_z)

                # Perspective Projection (Z distance offset = 3.5)
                distance = 3.5
                pz = z2 + distance
                # Aspect ratio correction: 2.2x horizontally for text cells
                px = int((width / 2) + (x3 / pz) * 45)
                py = int((height / 2) + (y3 / pz) * 20)
                projected.append((px, py))

            # 2. Rasterize Edges into Grid
            for v1_idx, v2_idx, color in CUBE_EDGES:
                x0, y0 = projected[v1_idx]
                x1, y1 = projected[v2_idx]
                
                # Choose ASCII character based on line slope
                dx, dy = x1 - x0, y1 - y0
                ch = "*"
                if abs(dx) > 2 * abs(dy): ch = "-"
                elif abs(dy) > 2 * abs(dx): ch = "|"
                elif (dx > 0 and dy > 0) or (dx < 0 and dy < 0): ch = "\\"
                else: ch = "/"

                # Draw line segment
                temp_grid = [[" "] * width for _ in range(height)]
                draw_line(x0, y0, x1, y1, temp_grid, width, height, char=ch)
                
                # Merge into main grid with edge color
                for r in range(height):
                    for c in range(width):
                        if temp_grid[r][c] != " ":
                            grid[r][c] = temp_grid[r][c]
                            color_grid[r][c] = f"{CSI}{color}{BOLD}"

            # 3. Draw Vertices as bright dots
            for px, py in projected:
                if 0 <= px < width and 0 <= py < height:
                    grid[py][px] = "O"
                    color_grid[py][px] = f"{CSI}97;1m"

            # 4. Build Compact ANSI Transmission Packet
            buf = [pos(1, 1), f"{BOLD}{CSI}96m 3D RTL Wireframe Cube | Frame: {frame:<6}{RESET}"]
            
            for r in range(height):
                buf.append(pos(top_row + r, left_col))
                last_color = None
                line_str = []
                for c in range(width):
                    col = color_grid[r][c]
                    ch = grid[r][c]
                    if col != last_color:
                        line_str.append(col if col else RESET)
                        last_color = col
                    line_str.append(ch)
                line_str.append(RESET)
                buf.append("".join(line_str))

            sys.stdout.write("".join(buf))
            sys.stdout.flush()

            # Rotate angles
            angle_x += 3.5
            angle_y += 5.0
            angle_z += 2.0
            frame += 1
#            time.sleep(0.025) # ~40 FPS

    except KeyboardInterrupt:
        sys.stdout.write(pos(height + 5, 1) + f"{CSI}?25h{RESET}\n")
        sys.stdout.flush()

if __name__ == "__main__":
    main()
