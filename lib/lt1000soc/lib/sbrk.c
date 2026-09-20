#include "lt1000.h"

#include <errno.h>
#include <sys/types.h>
#include <sys/stat.h>
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

// SD card access
static int _sd_read(int fd, char *buf, int count)
{
}
static int _sd_write(int fd, const char *buf, int count)
{
}

static int _sd_lseek(int fd, int ptr, int dir)
{
}

/*
 * Low-level write syscall for Newlib.
 * Handles stdout (1) and stderr (2) by forwarding characters to UART putch.
 */
int _write(int fd, const char *buf, int count) {
    // Only handle stdout and stderr
    if (fd == 1 || fd == 2) {
        for (int i = 0; i < count; i++) {
            // Translate standard '\n' to '\r\n' for terminal compatibility
            if (buf[i] == '\n') {
                putch('\r');
            }
            putch(buf[i]);
        }
        return count;
    }
    if (fd == 3) {
		return _sd_write(fd, buf, count);
	}

    errno = EBADF;
    return -1;
}


/*
 * Low-level read syscall for Newlib.
 * Handles stdin (0) by polling or waiting on UART getch.
 */
int _read(int fd, char *buf, int count) {
    if (fd == 0) {
        int bytes_read = 0;
        while (bytes_read < count) {
            char c = (char)getch();
            buf[bytes_read++] = c;

            // Optional: Break on newline if doing line-buffered input
            if (c == '\r' || c == '\n') {
                break;
            }
        }
        return bytes_read;
    }
    if (fd == 3) {
		return _sd_read(fd, buf, count);
	}

    errno = EBADF;
    return -1;
}

int _isatty(int fd) {
    // Return 1 for stdio descriptors so Newlib treats them as terminal TTYs
    if (fd >= 0 && fd <= 2) return 1;
    return 0;
}

int _fstat(int fd, struct stat *st) {
    // Mark descriptors as character special devices
    st->st_mode = S_IFCHR;
    return 0;
}

int _lseek(int fd, int ptr, int dir) {
	if (fd == 3) {
		return _sd_lseek(fd, ptr, dir);
	}
    return 0; // Seeking isn't supported on UART streams
}

int _close(int fd) {
    return -1;
}

void _exit(int status) {
	(void)status;
	void (*bios_entry)(void) = (void (*)(void))0x01000000;
	bios_entry();
}	
