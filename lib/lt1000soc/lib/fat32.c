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
#include <ctype.h>
#include "fat32.h"

static int sd_sector_op(int sel, int div, uint32_t sector, uint8_t *buf, int op)
{
	static FILE *host_file;

	host_file = fopen("disk.img", "r+");
	if (!host_file) {
		printf("Dude there's no disk.img!!!\n");
		exit(-1);
	}

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

	// filter for invalid clusters
	if ((cluster < 2) || (cluster >= FAT32_MAX_CLUSTER)) {
		fat32_errno = FAT32_ERR_INV_CLUSTER_ADDR;
		return -1;
	}
	
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
	static uint32_t starting_cluster = 0;
	uint32_t cluster = starting_cluster ? starting_cluster : 2;
	uint32_t fat_sector;
	uint32_t byte_offset;
	uint32_t raw_entry;
	uint8_t secbuf[512];

	fat32_errno = 0;
	for(;;) {
		++cluster;
		fat_sector = cluster >> 7;
		if (fat_sector >= dsk->vbr.sectors_per_fat) {
			// didn't find one but did we start at a known free offset?
			if (starting_cluster) {
				starting_cluster = 0;
				return next_free_cluster(dsk);
			} else {
				return 0;
			}
		}
		fat_sector += dsk->fat_sector;

		if (sd_sector_op(dsk->cs_sel, dsk->oper_div, fat_sector, secbuf, 0)) {
			fat32_errno = FAT32_ERR_SEC_READ;
			return 0; // Return EOC/Error
		}
		
		// scan over all of the entries in this sector
		while (cluster & 0x7F) {
			byte_offset = (cluster & 0x7F) * 4;

			// Read 32-bit little-endian entry
			raw_entry = secbuf[byte_offset] | 
					((uint32_t)secbuf[byte_offset + 1] << 8)  |
					((uint32_t)secbuf[byte_offset + 2] << 16) | 
					((uint32_t)secbuf[byte_offset + 3] << 24);

			if (raw_entry == 0) {
				// try starting at the next cluster next time around
				starting_cluster = cluster;
				return cluster;
			}
			++cluster;
		}
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
	if (cluster >= FAT32_MAX_CLUSTER) {
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
	if (cluster >= FAT32_MAX_CLUSTER) {
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
		update_cluster(dsk, free_cluster, FAT32_MAX_CLUSTER);
		// update the parent to form a chain if any
		if (parent_cluster != 0 && parent_cluster < FAT32_MAX_CLUSTER) {
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
		if (n_cluster >= FAT32_MAX_CLUSTER) {
			// we hit the last cluster
			break;
		}
		start_cluster = n_cluster;
	}

	// start_cluster is now the last cluster so append a new one
	return prep_new_cluster(dsk, start_cluster);
#endif
}

static int is_emptydir(struct fat32_disk *dsk, uint32_t start_cluster)
{
	uint8_t secbuf[512];
	uint32_t x, secno, first;

	secno = 0;
	first = 1; // first sector of first cluster skip the first two entries . and ..
	for (;;) {
		// read directory cluster in
		if (data_region_sector_op(dsk, start_cluster, secno, secbuf, 0)) {
			return -1;
		}

		// check all of the entries
		for (x = 0; x < (512/32); x++) {
			uint32_t y = 32 * x;
			if ((first && x >= 2) || !first) {
				if (!secbuf[y]) {
					return 1;
				}
				if (secbuf[y] != 0xE5) {
					return 0;
				}
			}
		}
		first = 0;
		
		// next sector
		++secno;
		if (secno == dsk->vbr.sectors_per_cluster) {
			secno = 0;
			start_cluster = next_cluster(dsk, start_cluster);
			if (start_cluster >= FAT32_MAX_CLUSTER) {
				return 1;
			}
		}
	}
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
    dsk->vbr.bytes_per_sector = secbuf[0xB] | ((uint32_t)secbuf[0xC] << 8);                 // bytes 0xB..0xC
    if (dsk->vbr.bytes_per_sector != 512) {
        fat32_errno = FAT32_ERR_INV_SEC_SIZE;
        free(dsk);
        return NULL;
    }

	dsk->vbr.sectors_per_cluster    = secbuf[0xD];											// bytes 0xD
	dsk->vbr.reserved_sectors       = secbuf[0xE] | ((uint32_t)secbuf[0xF] << 8);			// bytes 0xE..0xF
	dsk->vbr.number_of_fats         = secbuf[0x10];											// bytes 0x10
	dsk->vbr.sectors_per_fat        = secbuf[0x24] |
										((uint32_t)secbuf[0x25] << 8) | 		// bytes 0x24..0x27
								   		((uint32_t)secbuf[0x26] << 16) |
										((uint32_t)secbuf[0x27] << 24);
	dsk->vbr.root_directory_cluster = secbuf[0x2C] |
										((uint32_t)secbuf[0x2D] << 8) | 		// bytes 0x2C..0x2F
								   		((uint32_t)secbuf[0x2E] << 16) |
										((uint32_t)secbuf[0x2F] << 24);

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
	if (de->dir_pos < (512/32)) {
		// load the de->dir_pos'th directory entry from this secbuf
		uint32_t x, off = de->dir_pos * 32;
		memcpy(de->de.filename, &de->secbuf[off + 0], 8);
		memcpy(de->de.fileext, &de->secbuf[off + 8], 3);
		for (x = 0; x < 8; x++) { if (de->de.filename[x] == ' ') de->de.filename[x] = 0; }
		for (x = 0; x < 3; x++) { if (de->de.fileext[x] == ' ') de->de.fileext[x] = 0; }
		de->de.filename[8] = 0;
		de->de.fileext[4]  = 0;
		
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

		// increment dir_pos for either going to the next entry locally or the next clal to this function
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
		de->sec_no      = 0;
		de->cur_cluster = next_cluster(de->dsk, de->cur_cluster);
		if (de->cur_cluster >= FAT32_MAX_CLUSTER) {
			return NULL;
		}
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

	// handle trying to find root
	if (path[0] == 0 || !strcmp(path, "/")) {
		// this is kinda a special case for fat32_create(), not all fields are initialized
		di = calloc(1, sizeof *di);
		di->dsk              = dsk;		// disk pointer
		di->de.start_cluster = dsk->vbr.root_directory_cluster;
		if (odi) {
			*odi         = *di;
			odi->de.self = odi;
		}
		de = calloc(1, sizeof *de);
		*de = di->de;
		free(di);
		return de;
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
		tgtfilename[x++] = toupper(*path++);
	}
	
	if (x && *path == '.' && path[1] != '.') {
		++path;
		x = 0;
		while (x < 3 && *path != '/' && *path) {
			tgtfileext[x++] = toupper(*path++);
		}
	} else if (x == 0 && path[0] == '.' && path[1] == '.') {
		// special case filename is ".."
		strcpy(tgtfilename, "..");
		path += 2;
	}

	// now let's read this directory until we find this pattern
	di = fat32_opendir(dsk, cluster);
	if (!di) {
		return NULL;
	}
	
	while ((de = fat32_readdir(di))) {
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

	// if it's a directory is it empty?
		if ((de->flags & FAT32_F_DIR) && !is_emptydir(dsk, de->start_cluster)) {
			free(de);
			fat32_errno = FAT32_ERR_INV_DIR_NOT_EMPTY;
			return -1;
		}

	// hulk smash the clusters
		cluster = de->start_cluster;
		while (cluster < FAT32_MAX_CLUSTER) {
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

int fat32_create(struct fat32_disk *dsk, char *fpath, uint8_t attribute, uint32_t start_cluster)
{
#ifndef LT1000_BIOS
	char *dir_sep;
	uint8_t secbuf[512], filename[9], filext[4];
	uint32_t x, dir_cluster, dir_secno, dir_idx;
	struct fat32_file *file;
	struct fat32_dirent_raw *de;
	int found;
	char path[512];

	// store path convert to upper for convenience
	memset(path, 0, sizeof path);
	for (x = 0; fpath[x] && x < (sizeof(path) - 1); x++) {
		path[x] = toupper(fpath[x]);
	}

	// sanity check path .. should be [A-Z/_\.0-9]
	for (x = 0; path[x]; x++) {
		uint8_t c = path[x];
		if (!((c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || (c == '/') || (c == '.') || (c == '_'))) {
			fat32_errno = FAT32_ERR_INV_PATH;
			return -1;
		}
	}

	// walk back to last / so we can separate the directory from filename
		dir_sep = path + strlen(path) - 1;
		while (dir_sep != path && *dir_sep != '/') --dir_sep;
		if (*dir_sep != '/') {
			fat32_errno = FAT32_ERR_INV_PATH;
			return -1;
		}
		*dir_sep = 0; // null it out making two strings
		
	// fat32_find_path() the directory
		de = fat32_find_path(dsk, path, NULL);
		if (!de) {
			return -1;
		}
	// parse filename into parts 
		memset(filename, ' ', 8); filename[8] = 0;
		memset(filext, ' ', 3); filext[3] = 0;
		x = 0;
		++dir_sep;

	// handle special
		if (!strcmp(dir_sep, "..")) {
			filename[0] = '.';
			filename[1] = '.';
		} else if (!strcmp(dir_sep, ".")) {
			filename[0] = '.';
		} else {
			while (x < 8 && *dir_sep && *dir_sep != '.') {
				filename[x++] = *(dir_sep++);
			}
			if (*dir_sep == '.') {
				x = 0;
				++dir_sep;
				while (x < 3 && *dir_sep) {
					filext[x++] = *(dir_sep++);
				}
			}
			// should be end of string now
			if (dir_sep[x]) {
				fat32_errno = FAT32_ERR_INV_PATH;
				free(de);
				return -1;
			}
		}
	// init parameters
		dir_cluster = de->start_cluster;
		dir_secno   = 0;
	// find slot for it
		found = 0;
		while (!found) {
			// read directory sector
			if (data_region_sector_op(dsk, dir_cluster, dir_secno, secbuf, 0)) {
				free(de);
				return -1;
			}
			// iterate over all dirents in this sector looking for 0xE5 or 0x00, break when found
			for (dir_idx = 0; dir_idx <  512 / 32; dir_idx++) {
				if (secbuf[dir_idx * 32] == 0xE5 || !secbuf[dir_idx * 32]) {
					found = 1;
					break;
				}
			}
			if (!found) {
				// if another sector move to it and read it in, reset parameters
				dir_secno += 1;
				if (dir_secno >= dsk->vbr.sectors_per_cluster) {
					// advance cluster, append as necessary
					dir_secno = 0;
					dir_cluster = next_cluster(dsk, dir_cluster);
					if (dir_cluster >= FAT32_MAX_CLUSTER) {
						dir_cluster = append_new_cluster(dsk, de->start_cluster);
					}
				}
			}
		}
	// at point dir_cluster, dir_secno, dir_idx point to where we can store the new entry		
	// allocate cluster for starting_cluster
		uint32_t starting_cluster = (start_cluster == 0) ? 
			prep_new_cluster(dsk, 0) : 
			((start_cluster == 0xFFFFFFFF) ? 0 : start_cluster); // all F maps to start_cluster of 0
		if (starting_cluster >= FAT32_MAX_CLUSTER) {
			free(de);
			return -1;
		}
	// fill in dirent (name, size, starting_cluster, etc)
		x = dir_idx * 32;
		// zero out dirent, put spaces in filename spots
		memset(&secbuf[x], 0, 32);
		memcpy(&secbuf[x], filename, 8);
		memcpy(&secbuf[x+8], filext, 3);
		secbuf[x + 11]   = attribute;
		secbuf[x + 0x1A] = (starting_cluster)&0xFF;
		secbuf[x + 0x1B] = (starting_cluster>>8)&0xFF;
		secbuf[x + 0x1C] = (starting_cluster>>16)&0xFF;
		secbuf[x + 0x1D] = (starting_cluster>>24)&0xFF;

	// write dirent back
		if (data_region_sector_op(dsk, dir_cluster, dir_secno, secbuf, 1)) {
			free(de);
			return -1;
		}

	// done
		return 0;
#endif
}

// create a directory
int fat32_createdir(struct fat32_disk *dsk, char *fpath)
{
	uint32_t x, newcluster, parentcluster;
	struct fat32_dirent_raw *de;
	char npath[512];
	
	memset(npath, 0, sizeof npath);
	strncpy(npath, fpath, sizeof(npath) - 4);

	// create new directory entry
		if (fat32_create(dsk, npath, FAT32_F_DIR, 0)) {
			return -1;
		}

	// we need to create two files now a "." and then a ".." in that order
		// first fine the start_cluster of this 
		de = fat32_find_path(dsk, npath, NULL);
		strcat(npath, "/.");
		fat32_create(dsk, npath, FAT32_F_DIR, de->start_cluster);
		free(de);
		npath[strlen(npath) - 2] = 0; // remove added /.

		// now rewind off the to the parent dir
		x = strlen(npath) - 1;
		while (x && npath[x] != '/') {
			--x;
		}
		npath[x] = 0;

		de = fat32_find_path(dsk, npath, NULL);
		memset(npath, 0, sizeof npath);
		strncpy(npath, fpath, sizeof(npath) - 4);
		strcat(npath, "/..");
		// parent for root dir subdirs isn't de->start_cluster it's 0
		fat32_create(dsk, npath, FAT32_F_DIR, (de->start_cluster != 2) ? de->start_cluster : 0xFFFFFFFF);
		free(de);

	return 0;
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
static uint32_t fat32_fileop(struct fat32_file *file, uint8_t *buf, uint32_t len, int op)
{
	uint32_t blen = 0;

	if (!file || !file->de) {
		return 0;
	}

write_top:
	// if we're at the end of the file do nothing
	if (file->cur_cluster >= FAT32_MAX_CLUSTER) {
		return 0;
	}
	while (file->fpos != file->de->file_size && len) {
		uint32_t cnt, secoff;
		secoff = file->fpos & 511;
		
		// does the operation cross a sector boundary?
		if ((secoff + len) >= 512) {
			cnt = 512 - secoff;
			cnt = cnt > len ? len : cnt;
		} else {
			cnt = len;
		}

		// does the operation length (now 'cnt') cross the file size?
		if ((file->fpos + cnt) >= file->de->file_size) {
			cnt = file->de->file_size - file->fpos;
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
#ifndef LT1000_BIOS
			if (file->secdirty) {
				// write sector to disk
				if (data_region_sector_op(file->dsk, file->cur_cluster, file->sec_no, file->secbuf, 1)) {
					fat32_errno = FAT32_ERR_SEC_WRITE;
					return blen;
				}
				file->secdirty = 0;
			}
#endif
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
		if ((file->cur_cluster == file->de->start_cluster && file->sec_no == 0 && file->fpos == 0) || (file->fpos & 511)) {
			// start of file
			// we can write upto 512 - secoff to the current sector
			uint32_t rem = (512 - (file->fpos & 511));
			file->de->file_size += (len >= rem) ? rem : len;
			file->lendirty       = 1;
			goto write_top;
		}
		// at this point we're at a sector boundary and not the start of the file
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
		// 3) if not move to the next cluster (appending as required)
		// move to next cluster
		file->sec_no      = 0;
		file->cur_cluster = next_cluster(file->dsk, file->cur_cluster);
		if (file->cur_cluster >= FAT32_MAX_CLUSTER) {
			// append a new cluster if we are at the end of the file
			file->cur_cluster = append_new_cluster(file->dsk, file->de->start_cluster);
			// new clusters are zeroed by default
			memset(file->secbuf, 0, 512);
		} else {
			// we moved to the next cluster so read in the first sector
			if (data_region_sector_op(file->dsk, file->cur_cluster, file->sec_no, file->secbuf, 0)) {
				fat32_errno = FAT32_ERR_SEC_READ;
				return blen;
			}
		}
		if (file->cur_cluster < FAT32_MAX_CLUSTER) {
			// this is sector based so we can only advance the file size by at most the current
			// buffered sector
			file->de->file_size += (len > 512) ? 512 : len;
			file->lendirty       = 1;
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
#ifndef LT1000_BIOS
	return fat32_fileop(file, buf, len, 1);
#endif
}

int fat32_seek(struct fat32_file *file, uint32_t offset)
{
    if (!file || !file->de) {
        return -1;
	}

	// write sector back if dirty
#ifndef LT1000_BIOS
	if (file->secdirty) {
		if (data_region_sector_op(file->dsk, file->cur_cluster, file->sec_no, file->secbuf, 1)) {
			fat32_errno = FAT32_ERR_SEC_WRITE;
			return -1;
		}
		file->secdirty = 0;
	}
#endif

	/* Clamp offset to file size – seeking past EOF just positions at EOF */
    if (offset > file->de->file_size) {
        offset = file->de->file_size;
	}

    file->fpos = offset;
    if (offset == file->de->file_size) {
        /* EOF: set marker so subsequent reads return 0 */
        file->cur_cluster = 0x0FFFFFFF;
        file->sec_no = 0;
        return 0;
    }

    /* Compute sector index relative to start of file */
    uint32_t sector_index = offset >> 9;          /* divide by 512 */
    uint32_t clusters_to_advance = sector_index / file->dsk->vbr.sectors_per_cluster;
    file->sec_no = sector_index % file->dsk->vbr.sectors_per_cluster;
    file->cur_cluster = file->de->start_cluster;
    /* Walk the FAT chain to the target cluster */
    for (uint32_t i = 0; i < clusters_to_advance; ++i) {
        file->cur_cluster = next_cluster(file->dsk, file->cur_cluster);
        if (file->cur_cluster >= FAT32_MAX_CLUSTER) {
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
