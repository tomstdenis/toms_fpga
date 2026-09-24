#include "lt1000.h"

int fat32_errno;

// initialize a disk by reading the MBR and configuring local params
struct fat32_disk *fat32_init_disk(uint32_t cs_sel, uint32_t oper_div)
{
	struct fat32_disk *dsk;
	uint32_t x;
	uint8_t secbuf[512];
	
	// read MBR
	if (sd_sector_op(cs_sel, oper_div, 0, secbuf, 0)) {
		fat32_errno = FAT32_ERR_SEC_READ;
		return NULL;
	}
	
	// is it valid?
	if (secbuf[510] != 0x55 || secbuf[511] != 0xAA) {
		fat32_errno = FAT32_ERR_INV_MBR;
		return NULL;
	}

	dsk = calloc(1, sizeof *dsk);
	if (!dsk) {
		fat32_errno = FAT32_ERR_OOM;
		return NULL;
	}
	dsk->cs_sel   = cs_sel;
	dsk->oper_div = oper_div;

	// get start of partition 1
	dsk->lba_start = secbuf[0x1C6] | ((uint32_t)secbuf[0x1C7] << 8) | 						// bytes 0x1C6..0x1C9
					 ((uint32_t)secbuf[0x1C8] << 16) | ((uint32_t)secbuf[0x1C9] << 24);

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
	dsk->vbr.bytes_per_sector       = secbuf[0xB] | ((uint32_t)secbuf[0xC] << 8);			// bytes 0xB..0xC
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
	
	de = calloc(1, sizeof *de);
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

// open up a file
struct fat32_file *fat32_open(struct fat32_disk *dsk, char *fpath)
{
}

// read from a file
uint32_t fat32_read(struct fat32_file *file, uint8_t *dst, uint32_t len)
{
}

int fat32_seek(struct fat32_file *file, uint32_t offset)
{
}


