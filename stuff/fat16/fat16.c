#include "fat16.h"

#define DEBUG printf

uint16_t fat16_starting_cluster_to_data_cluster(struct fat16_volinfo *fv, uint16_t starting_cluster)
{
	return fv->data_cluster + starting_cluster - 2;
}

void fat16_cluster_to_sector(struct fat16_volinfo *fv, uint16_t p[2])
{
	// port this to your local platform....
	uint32_t q;
	q = p[0] * fv->sectors_per_cluster;
	p[1] = (q >> 16);
	p[0] = (q & 0xFFFF);
}

void fat16_sector_to_byte(struct fat16_volinfo *fv, uint16_t p[2])
{
	p[1] = (p[1] << 9) | (p[0] >> 7);
	p[0] = p[0] << 9;
}

void fat16_byte_to_sector(struct fat16_volinfo *fv, uint16_t p[2])
{
	p[0] = (p[0] >> 9) | (p[1] << 7);
	p[1] = p[1] >> 9;
}

unsigned fat16_initvol(struct fat16_volinfo *fv, uint8_t *secbuf)
{
	uint16_t sector[2];
	
	memset(fv, 0, sizeof *fv);
	fv->secbuf = secbuf;
	
	// read boot sector
	sector[0] = sector[1] = 0;
	if (sector_op(sector, secbuf, 0)) {
		return 0xFF;
	}
	
	// parse fields
	fv->sectors_per_cluster    = secbuf[0x000D];
	fv->bytes_per_cluster      = fv->sectors_per_cluster << 9;
	fv->number_of_fats         = secbuf[0x0010];
	fv->number_of_root_entries = ((uint16_t)secbuf[0x0012] << 8) | secbuf[0x0011];
	fv->sectors_per_fat        = ((uint16_t)secbuf[0x0017] << 8) | secbuf[0x0016];
	fv->reserved_sectors       = ((uint16_t)secbuf[0x000F] << 8) | secbuf[0x000E];
	
	// cluster offsets
	fv->fat_cluster            = (fv->reserved_sectors / fv->sectors_per_cluster);
	fv->root_dir_cluster       = fv->fat_cluster + (fv->number_of_fats * (fv->sectors_per_fat / fv->sectors_per_cluster));
	fv->data_cluster           = fv->root_dir_cluster + (((fv->number_of_root_entries * 32) / 512) / fv->sectors_per_cluster); 
}

uint16_t fat16_next_cluster(struct fat16_volinfo *fv, uint16_t cluster)
{
	uint16_t sector[2];
	uint16_t off;
	
/*
 * 'cluster' is an index into a table starting at sector (fv->fat_cluster * fv->sectors_per_cluster * 512 + cluster * 2) / 512 */
 
	sector[0] = fv->fat_cluster;				// start at the starting of the first FAT table
	fat16_cluster_to_sector(fv, sector);		// convert cluster to sector 
	fat16_sector_to_byte(fv, sector);			// convert sector byte
	printf("%04x => %04x%04x\n", cluster, sector[1], sector[0]);
	for (off = 2; off--; ) {					// add 2*cluster
		sector[0] += cluster;
		if (sector[0] < cluster) {
			++sector[1];
		}
	}
	printf("%04x => %04x%04x\n", cluster, sector[1], sector[0]);
	
	off = (sector[0] >> 1) & 0xFF;  // byte offset into sector
	fat16_byte_to_sector(fv, sector);
	sector_op(sector, fv->secbuf, 0);
	DEBUG("next cluster is 0x%04x\n", ((uint16_t *)fv->secbuf)[off]);
	return ((uint16_t *)fv->secbuf)[off];
}

void fat16_opendir(struct fat16_volinfo *fv, struct fat16_de *de, uint16_t cluster)
{
	uint16_t sector[2];
	
	memset(de, 0, sizeof *de);
	de->fv = fv;
	de->cur_cluster = cluster;

	sector[0] = cluster;
	fat16_cluster_to_sector(fv, sector);
	sector_op(sector, fv->secbuf, 0);		// read dirent
}

struct fat16_dirent *fat16_nextdirent(struct fat16_de *de) 
{
	uint16_t sector[2];

top:
	DEBUG("nextdirent: %u, %u, %u\n", de->cur_cluster, de->cur_sector, de->cur_entry);
	// still inside the sector? 
	if (de->cur_entry < 16) {
		struct fat16_dirent *dirent;
		dirent = (struct fat16_dirent *)&(de->fv->secbuf[32 * de->cur_entry++]);
		if (dirent->filename[0] == 0) {
			DEBUG("filename[0] is zero...\n");
			// end of this directory
			return NULL;
		} else if (dirent->filename[0] == 0xE5) {
			DEBUG("filename[0] is 0xE5\n");
			// this entry is a deleted file
			goto top;
		}
		return dirent;
	}
	// we're at the end of the sector so we need to get the next
	if (de->cur_sector == (de->fv->sectors_per_cluster - 1)) {
		// we're at the end of this cluster so we need to read the FAT to find the next in the chain
		de->cur_cluster = fat16_next_cluster(de->fv, de->cur_cluster);
		if (de->cur_cluster >= 0xFFF8) {
			// end of cluster chain
			DEBUG("de->cluser is >= 0xFFF8\n");
			return NULL;
		}
		de->cur_sector = 0;
	} else {
		++(de->cur_sector);
	}
	
	// read next sector
	sector[0] = de->cur_cluster;
	fat16_cluster_to_sector(de->fv, sector);
	sector[0] += de->cur_sector;
	if (sector[0] < de->cur_sector) {
		// carry into top 16 bits
		++sector[1];
	}
	sector_op(sector, de->fv->secbuf, 0);
	
	// go back to top 
	goto top;
}
	
	
