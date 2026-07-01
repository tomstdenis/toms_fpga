#ifndef STRCPY_C_
#define STRCPY_C_

strcpy(char *d, char *s)
{
	while (*s) {
		*d++ = *s++;
	}
	*d = 0; 
}


#endif

