#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdio.h>
#include <string.h>

int main(int argc, char **argv)
{
    unsigned char buf[4], fname[64];
    FILE *out_fd[4];
    int in_fd;
    int x, y;

    in_fd = open("bios/bios.bin", O_RDONLY);
    for (x = 0; x < 4; x++) {
        sprintf(fname, "bios/bios_lane%d.vh", x);
        out_fd[x] = fopen(fname, "w");
    }

    for (x = 0; x < 2048; x++) {
        read(in_fd, buf, 4);
        for (y = 0; y < 4; y++) {
            fprintf(out_fd[y], "\tbios_lane_%d[%d] = 8'h%x;\n", y, x, buf[y]);
        }
    }
}

