#include "lt1000.h"

#ifdef LT1000_BIOS
// local copies since we don't heap in BIOS
static struct fat32_disk       bios_dsk;
static struct fat32_dirent     bios_de;
static struct fat32_dirent_raw bios_de_raw;
static struct fat32_file       bios_file;

// local copies of functions to avoid importing too much from newlib

#define free bios_free
static void bios_free(void *) {}

#define memcpy bios_memcpy
static void bios_memcpy(void *dst, void *src, uint32_t len)
{
	uint8_t *d = dst, *s = src;
	while (len--) {
		*d++ = *s++;
	}
}

#define memset bios_memset
static void bios_memset(void *dst, uint8_t v, uint32_t len)
{
	uint8_t *d = dst;
	while (len--) {
		*d++ = v;
	}
}

#define strcmp bios_strcmp
static int bios_strcmp(char *str1, char *str2)
{
	while (*str1) {
		if (*str1 < *str2) return -1;
		if (*str1 > *str2) return 1;
		++str1;
		++str2;
	}
	return 0;
}
#endif

int fat32_errno;

// initialize a disk by reading the MBR and configuring local params
struct fat32_disk *fat32_init_disk(uint32_t cs_sel, uint32_t oper_div)
{
	struct fat32_disk *dsk;
	uint8_t secbuf[512];
	
	// read MBR
	if (sd_sector_op(cs_sel, oper_div, 0, secbuf, 0)) {
		fat32_errno = FAT32_ERR_SEC_READ;
		return NULL;
	}
	
    // Verify that partition 1 is a FAT32 volume (type 0x0B or 0x0C)
    uint8_t part_type = secbuf[0x1C2];
    if (part_type != 0x0B && part_type != 0x0C) {
        fat32_errno = FAT32_ERR_INV_PART_TYPE;
        return NULL;
    }

#ifdef LT1000_BIOS
	dsk = &bios_dsk;
#else
	dsk = calloc(1, sizeof *dsk);
#endif
	if (!dsk) {
		fat32_errno = FAT32_ERR_OOM;
		return NULL;
	}
	dsk->cs_sel   = cs_sel;
	dsk->oper_div = oper_div;

	// get start of partition 1
	dsk->lba_start = secbuf[0x1C6] |
					 ((uint32_t)secbuf[0x1C7] << 8) | 						// bytes 0x1C6..0x1C9
					 ((uint32_t)secbuf[0x1C8] << 16) |
					 ((uint32_t)secbuf[0x1C9] << 24);

	// now read VBR of partition 1
	if (sd_sector_op(cs_sel, oper_div, dsk->lba_start, secbuf, 0)) {
		fat32_errno = FAT32_ERR_SEC_READ;
		free(dsk);
		return NULL;
	}
	
	// is it valid?
	if (secbuf[510] != 0x55 || secbuf[511] != 0xAA) {
		fat32_errno = FAT32_ERR_INV_VBR;
		free(dsk);
		return NULL;
	}

	// parse fields
    dsk->vbr.bytes_per_sector       = secbuf[0xB] | ((uint32_t)secbuf[0xC] << 8);                   // bytes 0xB..0xC
    if (dsk->vbr.bytes_per_sector != 512) {
        fat32_errno = FAT32_ERR_INV_SEC_SIZE;
        free(dsk);
        return NULL;
    }

	dsk->vbr.sectors_per_cluster    = secbuf[0xD];											// bytes 0xD
	dsk->vbr.reserved_sectors       = secbuf[0xE] | ((uint32_t)secbuf[0xF] << 8);			// bytes 0xE..0xF
	dsk->vbr.number_of_fats         = secbuf[0x10];											// bytes 0x10
	dsk->vbr.sectors_per_fat        = secbuf[0x24] | ((uint32_t)secbuf[0x25] << 8) | 		// bytes 0x24..0x27
								   ((uint32_t)secbuf[0x26] << 16) | ((uint32_t)secbuf[0x27] << 24);
	dsk->vbr.root_directory_cluster = secbuf[0x2C] | ((uint32_t)secbuf[0x2D] << 8) | 		// bytes 0x2C..0x2F
								   ((uint32_t)secbuf[0x2E] << 16) | ((uint32_t)secbuf[0x2F] << 24);

	// configure some computed fields
	dsk->fat_sector                 = dsk->lba_start + dsk->vbr.reserved_sectors;
	dsk->data_region_sector         = dsk->lba_start + dsk->vbr.reserved_sectors + (dsk->vbr.number_of_fats * dsk->vbr.sectors_per_fat);
	
	// done return to user
	return dsk;
}

// read a sector from the data region
static int data_region_sector_op(struct fat32_disk *dsk, uint32_t cluster, uint32_t sec_no, uint8_t *dst, int op)
{
	uint32_t sec;
	
	sec = dsk->data_region_sector + (cluster - 2) * dsk->vbr.sectors_per_cluster + sec_no;
	if (sd_sector_op(dsk->cs_sel, dsk->oper_div, sec, dst, op)) {
		fat32_errno = op ? FAT32_ERR_SEC_WRITE : FAT32_ERR_SEC_READ;
		return -1;
	}
	return 0;	
}

static uint32_t next_cluster(struct fat32_disk *dsk, uint32_t cluster)
{
	uint32_t fat_sector;
	uint32_t byte_offset;
	uint32_t raw_entry;
	uint8_t secbuf[512];
	
	// identity map for error clusters
	if (cluster >= 0x0FFFFFF8) {
		return cluster;
	}

	fat32_errno = 0;
	
	// 128 entries per 512-byte sector (512 / 4 = 128)
	// Shift right by 7 (>> 7) is equivalent to dividing by 128
	fat_sector = dsk->fat_sector + (cluster >> 7);
	
	if (sd_sector_op(dsk->cs_sel, dsk->oper_div, fat_sector, secbuf, 0)) {
		fat32_errno = FAT32_ERR_SEC_READ;
		return 0x0FFFFFFF; // Return EOC/Error
	}
	
	// Calculate byte offset inside the 512-byte sector buffer
	byte_offset = (cluster & 0x7F) * 4;
	
	// Read 32-bit little-endian entry
	raw_entry = secbuf[byte_offset] | 
	           ((uint32_t)secbuf[byte_offset + 1] << 8)  |
	           ((uint32_t)secbuf[byte_offset + 2] << 16) | 
	           ((uint32_t)secbuf[byte_offset + 3] << 24);
	
	// FAT32 only uses the lower 28 bits
	return raw_entry & 0x0FFFFFFF;
}
// open a directory starting at a given cluster
struct fat32_dirent *fat32_opendir(struct fat32_disk *dsk, uint32_t cluster)
{
	struct fat32_dirent *de;
	if (!dsk) {
		return NULL;
	}
#ifdef LT1000_BIOS
	de = &bios_de;
#else
	de = calloc(1, sizeof *de);
#endif	
	if (!de) {
		fat32_errno = FAT32_ERR_OOM;
		return NULL;
	}
	
	de->dsk         = dsk;
	de->cur_cluster = (cluster == 0) ? dsk->vbr.root_directory_cluster : cluster;
	if (data_region_sector_op(dsk, de->cur_cluster, de->sec_no, de->secbuf, 0)) {
		free(de);
		return NULL;
	}
	return de;
}

// return the next directory entry in the directory
struct fat32_dirent_raw *fat32_readdir(struct fat32_dirent *de)
{
	if (!de) {
		return NULL;
	}
top:
	if (de->dir_pos < 16) {
		// load the de->dir_pos'th directory entry from this secbuf
		uint32_t x, off = de->dir_pos * 32;
		memcpy(de->de.filename, &de->secbuf[off + 0], 8);
		memcpy(de->de.fileext, &de->secbuf[off + 8], 3);
		for (x = 0; x < 8; x++) { if (de->de.filename[x] == ' ') de->de.filename[x] = 0; }
		for (x = 0; x < 3; x++) { if (de->de.fileext[x] == ' ') de->de.fileext[x] = 0; }
		de->de.filename[8] = 0;
		de->de.fileext[4] = 0;
		
		de->de.flags         = de->secbuf[off + 11];
		de->de.start_cluster = de->secbuf[off + 0x1A] |
		                       ((uint32_t)de->secbuf[off + 0x1B] << 8) | 
		                       ((uint32_t)de->secbuf[off + 0x14] << 16) | 
		                       ((uint32_t)de->secbuf[off + 0x15] << 24);
		de->de.file_size     = de->secbuf[off + 0x1C] |
		                       ((uint32_t)de->secbuf[off + 0x1D] << 8) | 
		                       ((uint32_t)de->secbuf[off + 0x1E] << 16) | 
		                       ((uint32_t)de->secbuf[off + 0x1F] << 24);

		// are we at the end?
		if (de->de.filename[0] == 0x00) {
			return NULL;
		}

		(de->dir_pos)++;
		
		// skip if empty entry
		if (de->de.filename[0] == 0xE5) {
			goto top;
		}
		
		// skip if part of LFN
		if ((de->de.flags == 0xF) || (de->de.flags & 0x08)) {
			goto top;
		}

		// return entry
		return &(de->de);
	}
	
	// we ran out of entries in this sector so move to next
	++(de->sec_no);
	de->dir_pos = 0;
	if (de->sec_no == de->dsk->vbr.sectors_per_cluster) {
		de->cur_cluster = next_cluster(de->dsk, de->cur_cluster);
		if (de->cur_cluster >= 0x0FFFFFF8) {
			return NULL;
		}
		de->sec_no  = 0;
	}

	// read sector
	if (data_region_sector_op(de->dsk, de->cur_cluster, de->sec_no, de->secbuf, 0)) {
		return NULL;
	}
	goto top;
}

// find the directory entry for a given path
struct fat32_dirent_raw *fat32_find_path(struct fat32_disk *dsk, const char *path)
{
	uint32_t cluster = 0;
	struct fat32_dirent *di = NULL;
	struct fat32_dirent_raw *resde, *de = NULL;
	char tgtfilename[9], tgtfileext[4];
	uint32_t x;
	
	if (!dsk || !path) {
		return NULL;
	}
	
top:
	// skip any leading slashes
	while (*path == '/') ++path;
	
	free(di);
	memset(tgtfilename, 0, sizeof tgtfilename);
	memset(tgtfileext, 0, sizeof tgtfileext);
	tgtfilename[0] = '.';
	
	// parse path into filename/ext upto NUL or / or .
	x = 0;
	while (x < 8 && *path != '/' && *path != '.' && *path) {
		tgtfilename[x++] = *path++;
	}
	
	if (x && *path == '.' && path[1] != '.') {
		++path;
		x = 0;
		while (x < 3 && *path != '/' && *path) {
			tgtfileext[x++] = *path++;
		}
	} else if (x == 0 && path[0] == '.' && path[1] == '.') {
		// special case filename is ".."
		strcpy(tgtfilename, "..");
		path += 2;
	}
	
//	txt_printf("tgtfilename == [%s]\n\r", tgtfilename);
//	txt_printf("tgtfileext  == [%s]\n\r", tgtfileext);
//	txt_printf("path        == [%s]\n\r", path);
	
	// now let's read this directory until we find this pattern
	di = fat32_opendir(dsk, cluster);
	if (!di) {
		return NULL;
	}
	
	while ((de = fat32_readdir(di))) {
//		txt_printf("de: [%s] [%s]\n\r", de->filename, de->fileext);
		if (!strcmp(de->filename, tgtfilename) && (!tgtfileext[0] || !strcmp(de->fileext, tgtfileext))) {
			// entry is a directory and the path isn't completed yet
			if ((de->flags & FAT32_F_DIR) && (*path == '/')) {
				cluster = de->start_cluster;
				goto top;
			}
			
			// we're done if NUL
			if (*path == 0) {
#ifdef LT1000_BIOS
				resde = &bios_de_raw;
#else				
				resde = calloc(1, sizeof *resde);
#endif				
				if (!resde) {
					free(di);
					fat32_errno = FAT32_ERR_OOM;
					return NULL;
				}
				*resde = *de;
				free(di);
				return resde;
			}
			
			// path isn't complete but entry isn't a directory...
			free(di);
			fat32_errno = FAT32_ERR_INV_PATH;
			return NULL;
		}
	}
	
	// we hit the end ..
	free(di);
	fat32_errno = FAT32_ERR_PATH_NOT_FOUND;
	return NULL;
}

// open up a file
struct fat32_file *fat32_open(struct fat32_disk *dsk, char *fpath)
{
	struct fat32_file *file;
	
	if (!dsk || !fpath) {
		return NULL;
	}
	
#ifdef LT1000_BIOS
	file = &bios_file;
#else	
	file = calloc(1, sizeof *file);
#endif	
	if (!file) {
		fat32_errno = FAT32_ERR_OOM;
		return NULL;
	}
	file->dsk = dsk;
	file->de  = fat32_find_path(dsk, fpath);
    if (file->de->flags & FAT32_F_DIR) {
        /* Opening a directory as a file is not supported */
        fat32_errno = FAT32_ERR_INV_PATH;
        free(file->de);
        free(file);
        return NULL;
    }

	
	// prime first sector
	file->cur_cluster = file->de->start_cluster;
	if (file->de->file_size) {
		if (data_region_sector_op(dsk, file->cur_cluster, 0, file->secbuf, 0)) {
			free(file->de);
			free(file);
			return NULL;
		}
	}
	return file;
}

void fat32_close(struct fat32_file *file)
{
	if (file) {
		free(file->de);
	}
	free(file);
}

// read from a file
uint32_t fat32_read(struct fat32_file *file, uint8_t *dst, uint32_t len)
{
	uint32_t bread = 0;

	if (!file || !file->de) {
		return 0;
	}
	
	// if we're at the end of the file do nothing
	if (file->cur_cluster >= 0x0FFFFFF8) {
		return 0;
	}
	while (file->fpos != file->de->file_size && len) {
		uint32_t cnt, secoff;
		secoff = file->fpos & 511;
		
		// does the read cross a sector boundary?
		if ((secoff + len) > 512) {
			cnt = 512 - secoff;
		} else {
			if ((file->fpos + len) >= file->de->file_size) {
				cnt = file->de->file_size - file->fpos;
			} else {
				cnt = len;
			}
		}
		
		memcpy(dst, &file->secbuf[secoff], cnt);
		file->fpos += cnt;
		bread      += cnt;
		secoff      = file->fpos & 511;
		len        -= cnt;
		
		if (!secoff) {
			// end of sector
			++(file->sec_no);
			if (file->sec_no == file->dsk->vbr.sectors_per_cluster) {
				// next sector
				file->sec_no = 0;
				file->cur_cluster = next_cluster(file->dsk, file->cur_cluster);
				if (file->cur_cluster >= 0x0FFFFFF8) {
					// end of file
					return bread;
				}
			}
			// read next sector in
			if (data_region_sector_op(file->dsk, file->cur_cluster, file->sec_no, file->secbuf, 0)) {
				fat32_errno = FAT32_ERR_SEC_READ;
				return bread;
			}
		}
	}
	return bread;
}

int fat32_seek(struct fat32_file *file, uint32_t offset)
{
    if (!file || !file->de)
        return -1;

    /* Clamp offset to file size – seeking past EOF just positions at EOF */
    if (offset > file->de->file_size)
        offset = file->de->file_size;

    file->fpos = offset;

    if (offset == file->de->file_size) {
        /* EOF: set marker so subsequent reads return 0 */
        file->cur_cluster = 0x0FFFFFFF;
        file->sec_no = 0;
        return 0;
    }

    /* Compute sector index relative to start of file */
    uint32_t sector_index = offset >> 9;          /* divide by 512 */
    file->sec_no = sector_index % file->dsk->vbr.sectors_per_cluster;
    uint32_t clusters_to_advance = sector_index / file->dsk->vbr.sectors_per_cluster;

    /* Walk the FAT chain to the target cluster */
    file->cur_cluster = file->de->start_cluster;
    for (uint32_t i = 0; i < clusters_to_advance; ++i) {
        file->cur_cluster = next_cluster(file->dsk, file->cur_cluster);
        if (file->cur_cluster >= 0x0FFFFFF8) {
            /* Unexpected end of chain */
            return -1;
        }
    }

    /* Load the sector that contains the new offset (if the file is non‑empty) */
    if (data_region_sector_op(file->dsk, file->cur_cluster, file->sec_no, file->secbuf, 0)) {
        fat32_errno = FAT32_ERR_SEC_READ;
        return -1;
    }
    return 0;
}
