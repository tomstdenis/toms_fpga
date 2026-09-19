#include <errno.h>
#include <sys/types.h>
#include <stddef.h>

extern char _end;      /* Linker symbol: end of BSS / start of heap */
extern char _heap_max; /* Linker symbol: end of PSRAM boundary */

void *_sbrk(ptrdiff_t incr) {
    static char *heap_ptr = NULL;
    char *prev_heap_ptr;

    if (heap_ptr == NULL) {
        heap_ptr = &_end;
    }

    // Word-align increments for 32-bit architecture efficiency
    incr = (incr + 3) & ~3;

    prev_heap_ptr = heap_ptr;

    if (heap_ptr + incr > &_heap_max) {
        errno = ENOMEM;
        return (void *)-1;
    }

    heap_ptr += incr;
    return (void *)prev_heap_ptr;
}
