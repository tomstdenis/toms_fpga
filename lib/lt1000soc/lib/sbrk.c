#include "lt1000.h"

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
static int _sd_sec_valid = 0, _sd_sec_dirty = 0;
static uint8_t _sd_sec[512];
static uint32_t _sd_sec_no = 0, _sd_sec_offset = 0;

// max # of open files at once
#define MAX_FILES 32

// reserve the first X many file handles for special purposes
#define FD_RESV 16
struct fat32_disk *f32_dsk = NULL;
static struct fat32_file *f32_files[MAX_FILES];

// we should evict the current sector and load the chosen sector and set offset
static int _sd_lseek(int fd, off_t ptr, int dir)
{
	uint32_t tgt_sec, tgt_offset;
	uint64_t dest_offset;
	
	if (dir == SEEK_SET) {
		dest_offset = ptr;
	} else if (dir == SEEK_CUR) {
		uint64_t cur_offset = ((uint64_t)_sd_sec_no << 9) + _sd_sec_offset;
		dest_offset = cur_offset + ptr;
	} else if (dir == SEEK_END) {
		return -1;
	}

	tgt_sec    = dest_offset >> 9;
	tgt_offset = dest_offset & 511;
	_sd_sec_offset = tgt_offset;
	if (_sd_sec_valid) {
		// are on the same sector?
		if (tgt_sec == _sd_sec_no) {
			return 0;
		}
		// do we have to evict?
		if (_sd_sec_dirty) {
			if (sd_sector_op(0, 3, _sd_sec_no, _sd_sec, 1)) {
				return -1;
			}
		}
		_sd_sec_dirty = 0;
	}
	// load tgt sector
	_sd_sec_no = tgt_sec;
	if (sd_sector_op(0, 3, _sd_sec_no, _sd_sec, 0) == 0) {
		_sd_sec_valid = 1;
		return 0;
	}
	return -1;
}

static int _sd_read(int fd, char *buf, int count)
{
	int tot_read = 0;
	while (count) {
		uint32_t rem;
//printf("_sd_read: count=%d, sec_off=%u, sec_no=%u\n", count, _sd_sec_offset, _sd_sec_no);
		if (_sd_sec_valid) {
			rem = (_sd_sec_offset + count) & ~511UL ? 512 - _sd_sec_offset : count;
		} else {
			// SD sector isn't valid so just read it
			if (sd_sector_op(0, 3, _sd_sec_no, _sd_sec, 0)) {
				return -1;
			}
			rem = count > 512 ? 512 : count;
		}
		
		// we can now copy upto rem bytes from _sd_sec_offset on
		memcpy(buf, &_sd_sec[_sd_sec_offset], rem);
		buf            += rem;
		_sd_sec_offset += rem;
		count          -= rem;
		tot_read       += rem;
		
		if (_sd_sec_offset == 512) {
			// move to next sector
			_sd_sec_offset = 0;
			_sd_lseek(fd, ((_sd_sec_no+1)<<9)+_sd_sec_offset, SEEK_SET);
		}
	}
	return tot_read;
}

static int _sd_write(int fd, const char *buf, int count)
{
	int tot_write = 0;
	while (count) {
		uint32_t rem;
//printf("_sd_write: count=%d, sec_off=%u, sec_no=%u\n", count, _sd_sec_offset, _sd_sec_no);
		if (_sd_sec_valid) {
			rem = (_sd_sec_offset + count) & ~511UL ? 512 - _sd_sec_offset : count;
		} else {
			// SD sector isn't valid so just read it if count < 512
			if (count < 512) {
				if (sd_sector_op(0, 3, _sd_sec_no, _sd_sec, 0)) {
					return -1;
				}
			}
			_sd_sec_valid = 1;
			rem = count > 512 ? 512 : count;
		}
		
		// we can now copy upto rem bytes from buf on
		memcpy(&_sd_sec[_sd_sec_offset], buf, rem);
		buf            += rem;
		_sd_sec_offset += rem;
		_sd_sec_dirty   = 1;
		count          -= rem;
		tot_write      += rem;

		if (_sd_sec_offset == 512) {
			// hit the end of the sector always write it out
			if (sd_sector_op(0, 3, _sd_sec_no, _sd_sec, 1)) {
				return -1;
			}
			_sd_sec_dirty = 0;			

			// move to next sector
			_sd_sec_offset = 0;
			if (count >= 512) {
				// if we're writing a full sector next we don't need to read it first
				++_sd_sec_no;
			} else if (count) {
				// we're writing a partial sector cache page so we need to fill it first
				_sd_lseek(fd, ((_sd_sec_no+1)<<9)+_sd_sec_offset, SEEK_SET);
			} else {
				// there's no more to this request but we don't know if the user will read or write next
				// move to next sector but don't read it
				++_sd_sec_no;
				_sd_sec_valid = 0;
			}				
		}
	}
	return tot_write;
}

static int _sd_open(const char *path, int flags)
{
	_sd_sec_valid  = 0;
	_sd_sec_no     = 0;
	_sd_sec_offset = 0;
	if (sd_init(0, 15, 3) != 1) {
		return -1;
	}
	return 3; // fd == 3 is the SD card
}

static int _sd_close(int fd)
{
	if (_sd_sec_valid && _sd_sec_dirty) {
		_sd_sec_valid = 0;
		return sd_sector_op(0, 3, _sd_sec_no, _sd_sec, 1);
	}
	_sd_sec_valid = 0;
	return 0;
}

/*
 * Low-level write syscall for Newlib.
 * Handles stdout (1) and stderr (2) by forwarding characters to UART putch.
 */
int _write(int fd, const char *buf, int count) {
    // Only handle stdout and stderr
    if (fd == 1) {
        for (int i = 0; i < count; i++) {
            // Translate standard '\n' to '\r\n' for terminal compatibility
            if (buf[i] == '\n') {
                putch('\r');
            }
            putch(buf[i]);
        }
        return count;
    }
    if (fd == 2) {
		// VGA text output
        for (int i = 0; i < count; i++) {
            // Translate standard '\n' to '\r\n' for terminal compatibility
            if (buf[i] == '\n') {
                txt_putc('\r');
            }
            txt_putc(buf[i]);
        }
        return count;
    }
    if (fd == 3) {
		return _sd_write(fd, buf, count);
	}
	if (f32_dsk && fd >= FD_RESV && fd < (FD_RESV + MAX_FILES)) {
		if (f32_files[fd-FD_RESV]) {
			return fat32_write(f32_files[fd-FD_RESV], buf, count);
		}
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
	if (f32_dsk && fd >= FD_RESV && fd < (FD_RESV + MAX_FILES)) {
		if (f32_files[fd-FD_RESV]) {
			return fat32_read(f32_files[fd-FD_RESV], buf, count);
		}
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
	if (f32_dsk && fd >= FD_RESV && fd < (FD_RESV + MAX_FILES)) {
		if (f32_files[fd-FD_RESV]) {
			// only support SEEK_SET
			return fat32_seek(f32_files[fd-FD_RESV], ptr); 
		}
	}
    return 0; // Seeking isn't supported on UART streams
}

int _open(const char *path, int flags)
{
	if (!memcmp(path, "/dev", 4)) {
		// /dev is a special path 
		if (!strcmp(path, "/dev/sda")) {
			// fd == 3 is the SD card
			return _sd_open(path, flags);
		}
	} else {
		// normal file system
		uint32_t x;
		if (f32_dsk == NULL) {
			// init disk system
			f32_dsk = fat32_init_disk(0, 15);
			if (!f32_dsk) {
				return -1;
			}

			// init file map
			for (x = 0; x < MAX_FILES; x++) {
				f32_files[x] = NULL;
			}
		}

		// find empty slot 
		for (x = 0; x < MAX_FILES; x++) {
			if (f32_files[x] == NULL) {
				if (flags & O_CREAT) {
					if (fat32_create(f32_dsk, path, FAT32_F_ARC, 0)) {
						return -1;
					}
				}
				f32_files[x] = fat32_open(f32_dsk, path);
				if (f32_files[x]) {
					return x + FD_RESV;
				}
				return -1;
			}
		}
		return -1;
	}
	return -1;
}

int _close(int fd) {
	if (fd == 3) {
		return _sd_close(fd);
	}
	if (f32_dsk && (fd >= FD_RESV) && fd < (FD_RESV + MAX_FILES)) {
		if (f32_files[fd - FD_RESV]) {
			fat32_close(f32_files[fd - FD_RESV]);
			f32_files[fd - FD_RESV] = NULL;
		}
	}
    return -1;
}

void _exit(int status) {
	(void)status;

	// close all files if any
	int x;
	for (x = FD_RESV; x < (FD_RESV + MAX_FILES); x++) {
		_close(x);
	}

	void (*bios_entry)(void) = (void (*)(void))0x01000000;
	bios_entry();
}	
