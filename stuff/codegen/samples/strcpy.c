void strcpy(char *dst, char *src)
{
    while (*src) {
        *dst++ = *src;
    }
    *dst = 0;
}

int foo(void) {
    return 3;
}