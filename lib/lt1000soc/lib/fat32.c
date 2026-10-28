#ifndef HOSTPC
#include "lt1000.h"
#else
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <stddef.h>
#include <stdarg.h>
#include <string.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include "fat32.h"

static int sd_sector_op(int sel, int div, uint32_t sector, uint8_t *buf, int op)
{
	static uint8_t cache[512];
	static uint32_t cache_sec = 0xFFFFFFFF;
	static int cache_dirty = 0;
	static FILE *host_file;

	host_file = fopen("disk.img", "r+");
	if (!host_file) {
		printf("Dude there's no disk.img!!!\n");
		exit(-1);
	}

	if (cache_sec == sector) {
//		printf("cached sector op: sector==%u, op==%u\n", sector, op);
		if (op) {
			memcpy(cache, buf, 512);
			cache_dirty = 1;
		} else {
			memcpy(buf, cache, 512);
		}
		fclose(host_file);
		return 0;
	}

	if (cache_sec != 0xFFFFFFFF && cache_dirty) {
		// flush cache first
		fseek(host_file, cache_sec * 512, SEEK_SET);	
		fwrite(cache, 1, 512, host_file);
	}
	cache_dirty = 0;
	cache_sec   = sector;
	fseek(host_file, sector * 512, SEEK_SET);
	fread(cache, 1, 512, host_file);

//	printf("Sector op: sector==%u, op==%u\n", sector, op);
	fseek(host_file, sector * 512, SEEK_SET);
	if (op) {
		fwrite(buf, 1, 512, host_file);
	} else {
		fread(buf, 1, 512, host_file);
	}
	fclose(host_file);
	return 0;
}

#endif

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

// read/write a sector from the data region
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

// return the first free cluster 
static uint32_t next_free_cluster(struct fat32_disk *dsk)
{
#ifndef LT1000_BIOS
	uint32_t cluster = 64;
	uint32_t fat_sector;
	uint32_t byte_offset;
	uint32_t raw_entry;
	uint8_t secbuf[512];

	fat32_errno = 0;
	for(;;) {
		fat_sector = cluster >> 7;
		if (fat_sector >= dsk->vbr.sectors_per_fat) {
			return 0;
		}
		fat_sector += dsk->fat_sector;
		byte_offset = (cluster & 0x7F) * 4;

		if (sd_sector_op(dsk->cs_sel, dsk->oper_div, fat_sector, secbuf, 0)) {
			fat32_errno = FAT32_ERR_SEC_READ;
			return 0; // Return EOC/Error
		}
		
		// Read 32-bit little-endian entry
		raw_entry = secbuf[byte_offset] | 
				((uint32_t)secbuf[byte_offset + 1] << 8)  |
				((uint32_t)secbuf[byte_offset + 2] << 16) | 
				((uint32_t)secbuf[byte_offset + 3] << 24);

		if (raw_entry == 0) {
			return cluster;
		}
		++cluster;
	};
	return 0;
#endif
}

// return what a given cluster points to
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
	
	// compute fat sector and byte offset
	fat_sector = cluster >> 7;
	if (fat_sector > dsk->vbr.sectors_per_fat) {
		fat32_errno = FAT32_ERR_INV_CLUSTER_ADDR;
		return 0;
	}
	fat_sector += dsk->fat_sector;
	byte_offset = (cluster & 0x7F) * 4;
	
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

// update a cluster value in each FAT
// returns the old value (handy for unlinking a chain)
// returns 0 on error
static uint32_t update_cluster(struct fat32_disk *dsk, uint32_t cluster, uint32_t newvalue)
{
#ifndef LT1000_BIOS
	uint32_t n_fat, old_cluster, fat_sector, byte_offset;
	uint8_t secbuf[512];
	
	// return ok for invalid clusters
	if (cluster >= 0x0FFFFFF8) {
		return cluster;
	}

	fat32_errno = 0;

	// compute fat sector and byte offset
	fat_sector = cluster >> 7;
	if (fat_sector > dsk->vbr.sectors_per_fat) {
		fat32_errno = FAT32_ERR_INV_CLUSTER_ADDR;
		return 0;
	}
	fat_sector += dsk->fat_sector;
	byte_offset = (cluster & 0x7F) * 4;

	for (n_fat = 0; n_fat < dsk->vbr.number_of_fats; n_fat++) {
		// read sector in
		if (sd_sector_op(dsk->cs_sel, dsk->oper_div, fat_sector, secbuf, 0)) {
			fat32_errno = FAT32_ERR_SEC_READ;
			return 0;
		}

		// if this is the first FAT then save the previous cluster value
		if (n_fat == 0) {
			old_cluster =
				((uint32_t)secbuf[byte_offset]) | 
				((uint32_t)secbuf[byte_offset+1] << 8) | 
				((uint32_t)secbuf[byte_offset+2] << 16) | 
				((uint32_t)secbuf[byte_offset+3] << 24);
		}

		// update cluster
		secbuf[byte_offset]   = (newvalue) & 0xFF;
		secbuf[byte_offset+1] = (newvalue>>8) & 0xFF;
		secbuf[byte_offset+2] = (newvalue>>16) & 0xFF;
		secbuf[byte_offset+3] = (newvalue>>24) & 0xFF;

		// write sector out
		if (sd_sector_op(dsk->cs_sel, dsk->oper_div, fat_sector, secbuf, 1)) {
			fat32_errno = FAT32_ERR_SEC_WRITE;
			return 0;
		}

		// advance to next FAT
		fat_sector += dsk->vbr.sectors_per_fat;
	}
	return old_cluster;
#endif	
}

// allocate a new cluster, zero it out, append it to another cluster if any
static uint32_t prep_new_cluster(struct fat32_disk *dsk, uint32_t parent_cluster)
{
#ifndef LT1000_BIOS
	uint32_t free_cluster, secno;
	uint8_t secbuf[512];

	free_cluster = next_free_cluster(dsk);
	if (free_cluster) {
		fat32_errno = 0;

		// update the free cluster to be allocated
		update_cluster(dsk, free_cluster, 0x0FFFFFF8);
		// update the parent to form a chain if any
		if (parent_cluster != 0) {
			update_cluster(dsk, parent_cluster, free_cluster);
		}

		// now clear the cluster
		memset(secbuf, 0, 512);
		for (secno = 0; secno < dsk->vbr.sectors_per_cluster; secno++) {
			data_region_sector_op(dsk, free_cluster, secno, secbuf, 1);
		}
		return free_cluster;
	} else {
		return 0;
	}
#endif
}

// allocate a new cluster, zero it out, append it to the end of a cluster chain
static uint32_t append_new_cluster(struct fat32_disk *dsk, uint32_t start_cluster)
{
#ifndef LT1000_BIOS
	uint32_t n_cluster;

	for (;;) {
		n_cluster = next_cluster(dsk, start_cluster);
		if (n_cluster >= 0x0FFFFFF8) {
			// we hit the last cluster
			break;
		}
		start_cluster = n_cluster;
	}

	// start_cluster is now the last cluster so append a new one
	return prep_new_cluster(dsk, start_cluster);
#endif
}


// --- exported library functions ---

// initialize a disk by reading the MBR and configuring local params
struct fat32_disk *fat32_init_disk(uint32_t cs_sel, uint32_t oper_div)
{
	struct fat32_disk *dsk;
	uint8_t secbuf[512];
	
	// there's no MBR when in HOSTPC mode so we skip over that
#ifndef HOSTPC
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
#endif

#ifdef LT1000_BIOS
	dsk = &bios_dsk;
	bios_memset(dsk, 0, sizeof *dsk);
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

#ifdef HOSTPC
	// it's a raw FAT32 in hostpc mode there's no MBR...
	dsk->lba_start = 0;
#endif	

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

// open a directory starting at a given cluster
struct fat32_dirent *fat32_opendir(struct fat32_disk *dsk, uint32_t cluster)
{
	struct fat32_dirent *de;
	if (!dsk) {
		return NULL;
	}
#ifdef LT1000_BIOS
	de = &bios_de;
	bios_memset(de, 0, sizeof *de);
#else
	de = calloc(1, sizeof *de);
#endif	
	if (!de) {
		fat32_errno = FAT32_ERR_OOM;
		return NULL;
	}
	
	de->dsk         = dsk;		// disk pointer
	de->de.self     = de;		// dirent_raw points to it's parent dirent
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

		// it's the next valid file/directory entry
		de->de.dirent_source.dir_pos     = de->dir_pos - 1;			// dir_pos was incremented before here
		de->de.dirent_source.sec_no      = de->sec_no;
		de->de.dirent_source.cur_cluster = de->cur_cluster;

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
struct fat32_dirent_raw *fat32_find_path(struct fat32_disk *dsk, const char *path, struct fat32_dirent *odi)
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
				bios_memset(resde, 0, sizeof *resde);
#else				
				resde = calloc(1, sizeof *resde);
#endif				
				if (!resde) {
					free(di);
					fat32_errno = FAT32_ERR_OOM;
					return NULL;
				}
				*resde = *de;
				// if the user requests the directory itself
				if (odi) {
					*odi = *di;
				}
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

int fat32_unlink(struct fat32_disk *dsk, char *fpath)
{
#ifndef LT1000_BIOS
	struct fat32_dirent_raw *de;
	struct fat32_dirent      di;
	uint32_t cluster;
	int r;
	
	// find the file
	de = fat32_find_path(dsk, fpath, &di);
	if (de == NULL) {
		return -1;
	}

	// hulk smash the clusters
	cluster = de->start_cluster;
	while (cluster < 0x0FFFFFF8) {
		cluster = update_cluster(dsk, cluster, 0);
	}

	// now debleatenated it from the directory itself
		// read directory sector
		if (data_region_sector_op(di.dsk, de->dirent_source.cur_cluster, de->dirent_source.sec_no, di.secbuf, 0)) {
			free(de);
			return -1;
		}

		// mark filename with 0xE5, we're at the 32 * dir_pos'th entry in the sector
		// filename is the first 8 bytes of the entry
		di.secbuf[32 * de->dirent_source.dir_pos] = 0xE5;

		// write sector back
		if (data_region_sector_op(di.dsk, de->dirent_source.cur_cluster, de->dirent_source.sec_no, di.secbuf, 1)) {
			free(de);
			return -1;
		}

	free(de);
	return 0;
#endif
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
	bios_memset(file, 0, sizeof *file);
#else	
	file = calloc(1, sizeof *file);
#endif	
	if (!file) {
		fat32_errno = FAT32_ERR_OOM;
		return NULL;
	}
	file->dsk = dsk;
	file->de  = fat32_find_path(dsk, fpath, NULL);
	if (!file->de) {
		free(file);
		return NULL;
	}
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
		if (data_region_sector_op(dsk, file->cur_cluster, file->sec_no, file->secbuf, 0)) {
			free(file->de);
			free(file);
			return NULL;
		}
	}
	return file;
}

void fat32_close(struct fat32_file *file)
{
	fat32_errno = 0;
	if (file && file->de) {
#ifndef LT1000_BIOS
		if (file->secdirty) {
			// data is dirty write to disk
			if (data_region_sector_op(file->dsk, file->cur_cluster, file->sec_no, file->secbuf, 1)) {
				fat32_errno = FAT32_ERR_SEC_WRITE;
			}
			file->secdirty = 0;
		}

		if (file->lendirty) {
			// we need to update the length in the directory entry
			// read directory entry
			if (data_region_sector_op(file->dsk, file->de->dirent_source.cur_cluster, file->de->dirent_source.sec_no, file->secbuf, 0) == 0) {
				// update length
				uint32_t off = file->de->dirent_source.dir_pos * 32; // 32 bytes per entry
				file->secbuf[off + 0x1C] = file->de->file_size & 0xFF;
				file->secbuf[off + 0x1D] = (file->de->file_size >> 8) & 0xFF;
				file->secbuf[off + 0x1E] = (file->de->file_size >> 16) & 0xFF;
				file->secbuf[off + 0x1F] = (file->de->file_size >> 24) & 0xFF;
				if (data_region_sector_op(file->dsk, file->de->dirent_source.cur_cluster, file->de->dirent_source.sec_no, file->secbuf, 1)) {
					fat32_errno = FAT32_ERR_SEC_WRITE;
				}
			} else {
				fat32_errno = FAT32_ERR_SEC_READ;
			}
			file->lendirty = 0;
		}
#endif
		free(file->de);
	}
	free(file);
}

// read from a file
// TODO: port this to fat32_op with a wr_en parameter then make fat32_read a wrapper
static uint32_t fat32_fileop(struct fat32_file *file, uint8_t *buf, uint32_t len, int op)
{
	uint32_t blen = 0;

	if (!file || !file->de) {
		return 0;
	}

write_top:
	// if we're at the end of the file do nothing
	if (file->cur_cluster >= 0x0FFFFFF8) {
		return 0;
	}
	while (file->fpos != file->de->file_size && len) {
		uint32_t cnt, secoff;
		secoff = file->fpos & 511;
		
		// does the operation cross a sector boundary?
		if ((secoff + len) > 512) {
			cnt = 512 - secoff;
		} else {
			if ((file->fpos + len) >= file->de->file_size) {
				cnt = file->de->file_size - file->fpos;
			} else {
				cnt = len;
			}
		}
		
		if (op == 0) {
			// read
			memcpy(buf, &file->secbuf[secoff], cnt);
		} else {
			// write (mark sector as dirty)
			file->secdirty = 1;
			memcpy(&file->secbuf[secoff], buf, cnt);
		}
		buf        += cnt;
		file->fpos += cnt;
		blen       += cnt;
		secoff      = file->fpos & 511;
		len        -= cnt;
		
		if (!secoff) {
			// end of sector
			if (file->secdirty) {
				// write sector to disk
				if (data_region_sector_op(file->dsk, file->cur_cluster, file->sec_no, file->secbuf, 1)) {
					fat32_errno = FAT32_ERR_SEC_WRITE;
					return blen;
				}
				file->secdirty = 0;
			}

			// move to next sector in cluster
			++(file->sec_no);
			if (file->sec_no == file->dsk->vbr.sectors_per_cluster) {
				// next sector
				file->sec_no = 0;
				file->cur_cluster = next_cluster(file->dsk, file->cur_cluster);
				if (file->cur_cluster >= 0x0FFFFFF8) {
					// end of file (break out to handle writes)
					break;
				}
			}
			// read next sector in
			if (data_region_sector_op(file->dsk, file->cur_cluster, file->sec_no, file->secbuf, 0)) {
				fat32_errno = FAT32_ERR_SEC_READ;
				return blen;
			}
		}
	}
	// if we're writing and there's data left we need to figure out how to
	// increase the file size
#ifndef LT1000_BIOS
	if (op == 1 && len) {
		// 1) can we just enlarge the file size to fill the current sector?  if so do that goto top
		if (file->fpos & 511) {
			// we can write upto 512 - secoff to the current sector
			file->de->file_size += (512 - (file->fpos & 511));
			file->lendirty       = 1;
			goto write_top;
		}
		// 2) If not can we move to the next sector in this cluster?  If so read it in, then goto top
		file->sec_no += 1;
		if (file->sec_no < file->dsk->vbr.sectors_per_cluster) {
			// move to next sector in the cluster and enlarge filesize by sector or remaining
			file->de->file_size += (len > 512) ? 512 : len;
			file->lendirty       = 1;
			// read in sector
			if (data_region_sector_op(file->dsk, file->cur_cluster, file->sec_no, file->secbuf, 0)) {
				fat32_errno = FAT32_ERR_SEC_READ;
				return blen;
			}
			goto write_top;
		}
		// 3) if not add a cluster to the file and load the first sector and jump to the top
		file->sec_no = 0;
		file->cur_cluster = append_new_cluster(file->dsk, file->cur_cluster);
		if (file->cur_cluster < 0x0FFFFFF8) {
			uint32_t bytes_per_cluster = file->dsk->vbr.bytes_per_sector * file->dsk->vbr.sectors_per_cluster;
			file->de->file_size += (len > bytes_per_cluster) ? bytes_per_cluster : len;
			file->lendirty       = 1;
			// new clusters are zeroed by default
			memset(file->secbuf, 0, 512);
			goto write_top;
		}
		// 4) if not return out of disk space error
		fat32_errno = FAT32_ERR_INV_OUT_OF_SPACE;
	}
#endif	
	return blen;
}

uint32_t fat32_read(struct fat32_file *file, uint8_t *buf, uint32_t len)
{
	return fat32_fileop(file, buf, len, 0);
}

uint32_t fat32_write(struct fat32_file *file, uint8_t *buf, uint32_t len)
{
	return fat32_fileop(file, buf, len, 1);
}

int fat32_seek(struct fat32_file *file, uint32_t offset)
{
    if (!file || !file->de)
        return -1;

	// write sector back if dirty
	if (file->secdirty) {
		if (data_region_sector_op(file->dsk, file->cur_cluster, file->sec_no, file->secbuf, 1)) {
			fat32_errno = FAT32_ERR_SEC_WRITE;
			return -1;
		}
		file->secdirty = 0;
	}

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
