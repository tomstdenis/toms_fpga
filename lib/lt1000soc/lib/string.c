#include "lt1000.h"

int memcmp(const void *a, const void *b, size_t len)
{
	uint8_t *d = (uint8_t*)a, *s = (uint8_t*)b;
	while (len--) {
		if (*d < *s) return -1;
		if (*d > *s) return 1;
	}
	return 0;
}

void *memset(void *dst, int c, size_t len)
{
	uint8_t *d = (uint8_t*)dst;
	while (len--) {
		*d++ = c;
	}
	return dst;
}

void *memcpy(void *dst, const void *src, size_t len)
{
	uint8_t *d = (uint8_t*)dst, *s = (uint8_t*)src;
	while (len--) {
		*d++ = *s++;
	}
	return dst;
}

void *mempcpy(void *dst, const void *src, size_t len)
{
	uint8_t *d = (uint8_t*)dst, *s = (uint8_t*)src;
	while (len--) {
		*d++ = *s++;
	}
	return (void*)d;
}

size_t strlen(const char *s)
{
	size_t len;
	len = 0;
	while (*s++) {
		++len;
	}
	return len;
}

char *stpcpy(char *restrict dst, const char *restrict src)
{
   char  *p;

   p = mempcpy(dst, src, strlen(src));
   *p = '\0';

   return p;
}

char *strcpy(char *restrict dst, const char *restrict src)
{
   stpcpy(dst, src);
   return dst;
}

char *strcat(char *restrict dst, const char *restrict src)
{
   stpcpy(dst + strlen(dst), src);
   return dst;
}
