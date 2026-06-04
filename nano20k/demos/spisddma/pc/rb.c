#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <termios.h>
#include <errno.h>
#include <inttypes.h>
#include <time.h>

int main(int argc, char **argv)
{
	int fd;
	uint8_t master[512], buf[512], allzero[512];
	uint32_t s_good, s_bad, s_blank;
	
	memset(allzero, 0, sizeof allzero);
	fd = open(argv[1], O_RDONLY);
	read(fd, master, 512);
	close(fd);
	
	// read the entire card
	s_good = s_bad = s_blank = 0;
	fd = open(argv[2], O_RDONLY);
	for (;;) {
		if (read(fd, buf, 512) != 512) {
			break;
		}
		if (!memcmp(buf, master, 512)) {
			++s_good;
		} else if (!memcmp(buf, allzero, 512)) {
			++s_blank;
		} else {
			++s_bad;
		}
		printf("good: %8u, bad: %8u, blank: %8u\r", s_good, s_bad, s_blank);
		fflush(stdout);
	}
	close(fd);
	printf("\n");
}
