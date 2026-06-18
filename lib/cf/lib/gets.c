#ifndef GETS_C_
#define GETS_C_

gets(char *s)
{
	do {
		*s = getc();
	} while (*s++ != '\n');
	*s = 0;
}

#endif
