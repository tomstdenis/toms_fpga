#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <stdlib.h>

#define OP_READ  0x80
#define OP_WRITE 0x40
#define OP_HALT  0x20

#define OP_LEN(x) ((x - 1) & 3)

#define MEM_SIZE 8192

uint8_t memory[MEM_SIZE], init[MEM_SIZE];
uint32_t lines = 0;

void write_opcode(FILE *out, uint32_t opcode, uint32_t addr, uint32_t value, uint32_t len)
{
	uint8_t b;
	
	// first write command to file
	b = opcode | OP_LEN(len);   fprintf(out, "%02x", b);
	b = addr >> 16;             fprintf(out, "%02x", b);
	b = (addr >> 8) & 0xFF;     fprintf(out, "%02x", b);
	b = addr & 0xFF;            fprintf(out, "%02x", b);
	b = (value >> 24) & 0xFF;   fprintf(out, "%02x", b);
	b = (value >> 16) & 0xFF;   fprintf(out, "%02x", b);
	b = (value >> 8) & 0xFF;    fprintf(out, "%02x", b);
	b = value & 0xFF;           fprintf(out, "%02x\n", b);
	lines++;
}

// write out value[31:(32 - len)]
void gen_write(FILE *out, uint32_t addr, uint32_t value, uint32_t len)
{
	write_opcode(out, OP_WRITE, addr, value, len);
	
	// now do the op
	while (len--) {
		init[addr & (MEM_SIZE - 1)]     = 1;
		memory[addr++ & (MEM_SIZE - 1)] = (value >> 24) & 0xFF;
		value <<= 8;
	}	
}

// read in len bytes
void gen_read(FILE *out, uint32_t addr, uint32_t len)
{
	uint32_t value = 0, olen = len, oaddr = addr;
	
	// read into memory
	while (len--) {
		if (!init[addr & (MEM_SIZE - 1)]) {
			printf("Address %u was not initialized before reading!\n", addr & (MEM_SIZE - 1));
			exit(-1);
		}
		value = (value << 8) | memory[addr++ & (MEM_SIZE - 1)];
	}
	// shift up to MSB
	if (olen != 4) {
		value <<= 8 * (4 - olen);
	}
	write_opcode(out, OP_READ, oaddr, value, olen);
}

uint32_t read_rng(uint32_t len)
{
	uint32_t value = 0, olen = len;
	FILE *rng = fopen("/dev/urandom", "r");
	uint8_t b;
	
	while (len--) {
		fread(&b, 1, 1, rng);
		value = (value << 8) | b;
	}
	if (olen != 4) {
		value <<= 8 * (4 - olen);
	}
	fclose(rng);
	return value;
}

int main(void)
{
	uint32_t x, y, z;
	FILE *out;
	
	memset(memory, 0, sizeof memory);
	memset(init, 0, sizeof init);
	
	out = fopen("trace.hex", "w");

#if 1
	gen_write(out, 0x1210, 0x5A6B7C00, 3);
	gen_read(out, 0x1210, 3);
#else	
	// let's fill the first 8KB in banks of 2K using runs of 1, 2, 3, and 4 byte strides
	for (x = 1; x <= 4; x++) {
		z = 2048 * (x - 1);
		for (y = 0; y <= (2048 - x); y += x) {
			uint32_t value;
			value = read_rng(x);
			gen_write(out, z, value, x);
			z += x;
		}
	}
	// now generate reads 
	for (x = 1; x <= 4; x++) {
		z = 2048 * (x - 1);
		for (y = 0; y <= (2048 - x); y += x) {
			gen_read(out, z, x);
			z += x;
		}
	}
#endif

	while (lines < 10240) {
		write_opcode(out, OP_HALT, 0, 0, 0);
	}
}
