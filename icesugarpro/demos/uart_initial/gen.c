#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include <fcntl.h>
#include <unistd.h>

int main(void)
{
	uint8_t mem[2048];
	unsigned x;
	int fd;
	
	fd = open("../README.MD", O_RDONLY);
	memset(mem, 0, sizeof mem);
	read(fd, mem, 2048);
	close(fd);
	
	for (x = 0; x < 2048; x++) {
		printf("\ttext_mem[%d] = 8'h%02x;\n", x, mem[x]);
	}

}
