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

int main(int argc, char **argv)
{
	FILE *f;
	char line[256];
	int x;
	
	memset(mem, 0, sizeof mem);
	memset(line, 0, sizeof line);
	while (fgets(line, sizeof(line)-1, stdin)) {
		parse_line(line);
	}
	
	if (argc == 1) {
		// output hexfile
		#define ROMSIZE 2048
		printf(
		"#File_format=Hex\n"
		"#Address_depth=%d\n"
		"#Data_width=8\n", ROMSIZE);
		
		for (x = 0; x < ROMSIZE; x++) {
			printf("%02x\n", mem[(60 * 1024) + x]);
		}
	} else {
		for (x = 0; x < 65536; x++) {
			printf("%02x\n", mem[x]);
		}
	}
}
