#include "cf/lib/tni.h"

memset(unsigned char *a, int v, unsigned len)
{ 
	while (len--) {
		*a++ = v;
	}
}
