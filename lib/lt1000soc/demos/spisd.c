#include <stdint.h>
#include "lt1000.h"

#define INIT_DIV 15
#define OPER_DIV 7

void main(void)
{
	uint8_t buf[512];
	uint32_t x, t1;
	int fd;
	
	// fill buf with some fun contents 
	for (x = 0; x < 512; x++) {
		buf[x] = x >> 4;
	}
	
	// wait for a key to be pressed
	getch();
	
	fd = open("/dev/sda", O_RDONLY);
	printf("fd == %d\n", fd);
	
	// let's write this to sector 14
	printf("lseek(14) == %d\n", lseek(fd, 512 * 14, SEEK_SET));
	printf("write() == %d\n", write(fd, buf, 512));
	
	// write the reverse 
	for (x = 0; x < 512; x++) {
		buf[x] = (511 - x) >> 4;
	}

	// let's write this to sector 15
	printf("lseek(15) == %d\n", lseek(fd, 512 * 15, SEEK_SET));
	printf("write() == %d\n", write(fd, buf, 512));
	
	// clear buf
	memset(buf, 0, 512);	
	
	// let's read it back
	printf("lseek(14) == %d\n", lseek(fd, 512 * 14, SEEK_SET));
	printf("read() == %d\n", read(fd, buf, 512));	
	
	// print it out
	for (x = 0; x < 512; x++) {
		printf("%02x ", buf[x]);
		if (!((x+1)&15)) { printf("\n"); }
	}	
	
	// let's read it back offset by 256 bytes
	printf("lseek(14,+256) == %d\n", lseek(fd, 512 * 14 + 256, SEEK_SET));
	printf("read() == %d\n", read(fd, buf, 512));	
	
	// print it out
	for (x = 0; x < 512; x++) {
		printf("%02x ", buf[x]);
		if (!((x+1)&15)) { printf("\n"); }
	}
	
	close(fd);

	exit(0);
}
