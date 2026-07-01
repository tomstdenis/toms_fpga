#ifndef STRLEN_C_
#define STRLEN_C_

unsigned strlen(char *p)
{
	unsigned x;
	while (*p++) {
		++x;
	}
	return x;
}

#endif
