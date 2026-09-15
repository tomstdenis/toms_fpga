#ifndef LT1000_STRING_H
#define LT1000_STRING_H

#define size_t uint32_t

char *stpcpy(char *restrict dst, const char *restrict src);
char *strcpy(char *restrict dst, const char *restrict src);
char *strcat(char *restrict dst, const char *restrict src);
size_t strlen(const char *s);
void *memcpy(void *dst, const void *src, size_t len);
void *memset(void *dst, int c, size_t len);
int memcmp(const void *a, const void *b, size_t len);
void *mempcpy(void *dst, const void *src, size_t len);

#endif
