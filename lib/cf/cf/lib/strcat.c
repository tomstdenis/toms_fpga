#ifndef STRCAT_C_
#define STRCAT_C_

strcat(char *d, char *s)
{
	while (*d++);
	--d;
	while (*s) {
		*d++ = *s++;
	}
	*d = 0; 
}


#endif

