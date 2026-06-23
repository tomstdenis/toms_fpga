#include "cf/lib/tni.h"

memcpy(unsigned char *a, unsigned char *b, unsigned len)
{ 
	while (len--) {
		*a++ = *b++;
	}
}
