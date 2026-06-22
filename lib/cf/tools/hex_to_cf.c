#include <stdio.h>
#include <stdlib.h>
#include <string.h>

unsigned char mem[65536];

void parse_line(char *line)
{
	char t[5];
	int n, x, addr, v;
	t[2] = 0;
	t[4] = 0;
	if (line[0] == 'S' && line[1] == '1') {
		// only parse S1 records
		line += 2;
		// read len
		t[0] = line[0];
		t[1] = line[1];
		line += 2;
		sscanf(t, "%02x", &n);
		memcpy(t, line, 4);
		sscanf(t, "%04x", &addr);
		line += 4;
		t[2] = 0;
		for (x = 0; x < n - 3; x++) {
			t[0] = line[0];
			t[1] = line[1];
			line += 2;
			sscanf(t, "%02x", &v);
			mem[addr++] = v;
		}
	}
}

void parse_file(char *hexf)
{
	FILE *f;
	char buf[256];
	memset(mem, 0, sizeof mem);
	f = fopen(hexf, "r");
	while (fgets(buf, sizeof(buf) - 1, f)) {
		parse_line(buf);
	}
	fclose(f);
}

void dump_bin(char *binf, char *start, char *end)
{
	unsigned s, e, x, y;
	FILE *f;
	
	f = fopen(binf, "wb");
	sscanf(start, "%x", &s);
	sscanf(end, "%x", &e);
	
	// find end 
	if (e == 0) {
		printf("Scanning for end...\n");
		e = 0xFFFF;
		while (e && !mem[e]) {
			--e;
		}
	}
	
	for (x = s; x <= e; x++) {
		fputc(mem[x], f);
	}
	fclose(f);
}

int main(int argc, char **argv)
{
	parse_file(argv[1]);
	if (argc > 5) {
		unsigned e;
		sscanf(argv[5], "%x", &e);
		mem[0] = e & 0xFF;
		mem[1] = (e >> 8) & 0xFF;
		printf("Patched to %x\n", e);
	}
	dump_bin(argv[2], argv[3], argv[4]);
	return 0;
}
