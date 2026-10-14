#include <stdio.h>
#include <string.h>

int main(void)
{
	int ch, last_ch, last_run, runs[32], tally[2], x, y;
	
	y        = 0;
	last_ch  = '2';
	last_run = 0;
	memset(runs, 0, sizeof runs);
	tally[0] = tally[1] = 0;
	
	for (;;) {
		ch = fgetc(stdin);
		if (ch < 0) break;
		++tally[ch - '@'];
		if (ch == last_ch) {
			++last_run;
		} else {
			runs[last_run] += 1;
			last_ch         = ch;
			last_run        = 1;
		}
		++y;
		if (++x == 1024) {
			printf("\n\n\n0/1 distribution %d/%d (spread: %d)\n\r", tally[0], tally[1], tally[0] - tally[1]);
			for (x = 1; x < 32; x++) {
				if (runs[x]) {
					printf("run[%d] == %d/%d\n\r", x, runs[x], y);
				}
			}
			x = 0;
		}
	}
}
