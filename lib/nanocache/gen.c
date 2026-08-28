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

#if 0
	gen_write(out, 0x210,         0x5A000000, 1);
	gen_write(out, 0x211,         0x6B7C0000, 2);
	gen_write(out, 0x212,         0x8D9EAFBE, 4);
	gen_read(out,  0x210, 4);
	gen_read(out,  0x214, 2);
#if 0
	gen_write(out, 0x210 + 0x800, 0x12345600, 4);	// this should force collisions
	gen_write(out, 0x213 + 0x800, 0x78000000, 1);
	gen_read(out,  0x210 + 0x800, 4);
#endif
#else	
	// fill the full 8kb with values so it's initialized
	for (x = 0; x < 8192; x += 4) {
		gen_write(out, x, read_rng(4), 4);
	}

	while (lines < 65535) {
		uint32_t r, bl;

		// pick a random offset until it doesn't cross a cache line
		do {
			r = read_rng(4);
			bl = 4; // 1+((r>>13)&3);
		} while ((r & 31) > ((r + bl) & 31));

		if (r & 0x80000000) {
			gen_read(out, r & 0x7FF, bl);
		} else {
			uint32_t v = read_rng(4);
			gen_write(out, r & 0x7FF, v, bl);
		}
	}
	
#endif

	while (lines < 65536) {
		write_opcode(out, OP_HALT, 0, 0, 0);
	}
}
