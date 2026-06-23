#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <ctype.h>

int main(void)
{
	char line[512];
	unsigned addr, x, hide, first;

	// read until we hit SYMBOL TABLE
	
	while (fgets(line, sizeof line, stdin)) {
		if (!memcmp(line, "SYMBOL TABLE:", strlen("SYMBOL TABLE:"))) {
			break;
		}
	}
	fgets(line, sizeof line, stdin); // skip blank line
	printf("#ifndef BIOS_H_\n#define BIOS_H_\n\n");
	while (fgets(line, sizeof line, stdin)) {
		while (line[strlen(line)-1] == '\r' || line[strlen(line)-1] == '\n') {
			line[strlen(line)-1] = 0;
		}
		x = 0;
		while (line[x]) {
			hide = 0;
			first = 1; 
			while (line[x] == '?' || isalnum(line[x]) || line[x] == '_') {
				if (line[x] == '?') { hide = 1; };
				if (!hide) { 
					if (first) {
						first = 0;
						printf("#define ");
					}
					fputc(line[x], stdout);
				}
				++x;
			}
			while (line[x] == ' ' || line[x] == '\t') { ++x; }
			++x;
			sscanf(line+x, "%04X", &addr);
			x += 4;
			if (!hide) printf(" $%04X\n", addr);
			while (line[x] == ' ' || line[x] == '\t') { ++x; }
		}
	}
	printf("\n#endif\n");
}
