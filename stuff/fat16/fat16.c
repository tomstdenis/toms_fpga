#include "fat16.h"

#define DEBUG printf
//#define DEBUG(...)

// convert a directory starting cluster to a data cluster
uint16_t fat16_starting_cluster_to_data_cluster(struct fat16_volinfo *fv, uint16_t starting_cluster)
{
	return fv->data_cluster + starting_cluster - 2;
}

// map a cluster to a disk sector
void fat16_cluster_to_sector(struct fat16_volinfo *fv, uint16_t p[2])
{
	p[1] = (p[1] << fv->log2_cluster_sec) | (p[0] >> fv->log2_cluster2_sec);
	p[0] = (p[0] << fv->log2_cluster_sec);
}

// map a sector to a byte address
void fat16_sector_to_byte(uint16_t p[2])
{
	p[1] = (p[1] << 9) | (p[0] >> 7);
	p[0] = p[0] << 9;
}

// map a byte address back to a sector address
void fat16_byte_to_sector(uint16_t p[2])
{
	p[0] = (p[0] >> 9) | (p[1] << 7);
	p[1] = p[1] >> 9;
}

// add a 16-bit offset to a 32-bit byte offset
void fat16_add_byte_offset(uint16_t p[2], uint16_t off)
{
	p[0] += off;
	p[1] += (p[0] < off);
}

// add a 32-bit offset to a 32-bit byte offset
void fat16_add_byte_loffset(uint16_t p[2], uint16_t off[2])
{
	p[0] += off[0];
	p[1] += off[1] + (p[0] < off[0]);
}

// compare a and b, return 1 if GT, 0 if EQ, -1 if LT
int fat16_cmp_loffset(uint16_t a[2], uint16_t b[2])
{
	if (a[1] > b[1]) return 1;
	if (a[1] < b[1]) return -1;
	if (a[0] > b[0]) return 1;
	if (a[0] < b[0]) return -1;
	return 0;
}

// init a FAT-16 volume state
// secbuf should point to a 512 byte buffer it can use to hold sectors
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
	fv->log2_cluster 		   = 0;
	fv->number_of_fats         = secbuf[0x0010];
	fv->number_of_root_entries = ((uint16_t)secbuf[0x0012] << 8) | secbuf[0x0011];
	fv->sectors_per_fat        = ((uint16_t)secbuf[0x0017] << 8) | secbuf[0x0016];
	fv->reserved_sectors       = ((uint16_t)secbuf[0x000F] << 8) | secbuf[0x000E];
	
	// cluster offsets
	fv->fat_cluster            = (fv->reserved_sectors / fv->sectors_per_cluster);
	fv->root_dir_cluster       = fv->fat_cluster + (fv->number_of_fats * (fv->sectors_per_fat / fv->sectors_per_cluster));
	fv->data_cluster           = fv->root_dir_cluster + (((fv->number_of_root_entries * 32) / 512) / fv->sectors_per_cluster);
	
	// compute log2 of cluster size
	sector[0] = fv->bytes_per_cluster;
	while (sector[0] != 1) {
		++(fv->log2_cluster);
		sector[0] >>= 1;
	}
	fv->log2_cluster2 = 16 - fv->log2_cluster;
	fv->log2_cluster_sec = fv->log2_cluster - 9;
	fv->log2_cluster2_sec = 16 - fv->log2_cluster_sec;
}

// given a cluster find the next cluster according to the FAT
// values >= 0xFFF8 mean end of chain.
uint16_t fat16_next_cluster(struct fat16_volinfo *fv, uint16_t cluster)
{
	uint16_t sector[2];
	uint16_t off;
	
/*
 * 'cluster' is an index into a table starting at sector (fv->fat_cluster * fv->sectors_per_cluster * 512 + cluster * 2) / 512 */
 
	sector[0] = fv->fat_cluster;				// start at the starting of the first FAT table
	fat16_cluster_to_sector(fv, sector);		// convert cluster to sector 
	fat16_sector_to_byte(sector);				// convert sector byte
	fat16_add_byte_offset(sector, cluster);
	fat16_add_byte_offset(sector, cluster);
	
	off = (sector[0] >> 1) & 0xFF;  // byte offset into sector
	fat16_byte_to_sector(sector);
	sector_op(sector, fv->secbuf, 0);
	DEBUG("next cluster is 0x%04x\n", ((uint16_t *)fv->secbuf)[off]);
	return ((uint16_t *)fv->secbuf)[off];
}

// open a directory 'fat16_de' that can be used with fat16_nextdirent()
// cluster==0 means use the root directory
void fat16_opendir(struct fat16_volinfo *fv, struct fat16_de *de, uint16_t cluster)
{
	uint16_t sector[2];
	
	cluster = cluster ? cluster : fv->root_dir_cluster;
	
	memset(de, 0, sizeof *de);
	de->fv = fv;
	de->cur_cluster = cluster;

	sector[0] = cluster;
	fat16_cluster_to_sector(fv, sector);
	sector_op(sector, fv->secbuf, 0);		// read dirent
}

// return the next directory entry for the currently open directory
// or NULL if we hit the end
struct fat16_dirent *fat16_nextdirent(struct fat16_de *de) 
{
	uint16_t sector[2];

top:
	DEBUG("nextdirent: %u, %u, %u\n", de->cur_cluster, de->cur_sector, de->cur_entry);
	// still inside the sector? (there are 16 dirent's per sector)
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


// path must start with /
struct fat16_dirent *fat16_walk_path(struct fat16_volinfo *fv, char *path, uint16_t dircluster)
{
	char pathname[13]; // 8 . 3
	char filename[8], ext[3];
	struct fat16_de de;
	struct fat16_dirent *dirent;
	uint16_t x, y;

top:

	DEBUG("Starting with [%s]\n", path);

	// check for leading /
	if (*path++ != '/') return NULL;

	// extract fname
	x = 0;
	memset(pathname, 0, sizeof pathname);
	while (*path != '/' && *path && x < 12) {
		pathname[x++] = *path++;
	}
	
	DEBUG("remaining path == [%s]\n", path);
	DEBUG("pathname == [%s]\n", pathname);
	
	// sanity check
	if (x == 12 && *path && *path != '/') {
		DEBUG("Error: pathname is too long\n");
		return NULL;
	}
	
	// format filename/ext
	memset(filename, ' ', 8);
	memset(ext, ' ', 3);
	
	// scan out pathname to filename+ext
	x = y = 0;
	while (x < 8 && pathname[y] != '.' && pathname[y]) {
		filename[x++] = pathname[y++];
	}
	if (pathname[y] == '.') {
		x = 0;
		++y;
		while (x < 3 && pathname[y]) {
			ext[x++] = pathname[y++];
		}
	}
	
	DEBUG("filename = [%c%c%c%c%c%c%c%c]\n", 
		filename[0], filename[1], filename[2], filename[3],
		filename[4], filename[5], filename[6], filename[7]);
	
	DEBUG("ext = [%c%c%c]\n", ext[0], ext[1], ext[2]);
	
	// now let's open the directory
	fat16_opendir(fv, &de, dircluster);
	
	while ((dirent = fat16_nextdirent(&de))) {
		DEBUG("dirent == %p\n", dirent);
		if (!memcmp(filename, dirent->filename, 8) && !memcmp(ext, dirent->ext, 3)) {
			// found it, but do we need to loop?
			if (*path == '/') {
				if (dirent->attrib & 0x10) {
					// it's a directory so loop
					dircluster = fat16_starting_cluster_to_data_cluster(fv, ((uint16_t)dirent->starting_cluster[1] << 8) | dirent->starting_cluster[0]);
					goto top;
				} else {
					// it's not a directory so error
					DEBUG("Error: dirent isn't a directory\n");
					return NULL;
				}
			} else {
				return dirent;
			}
		}
	}
	return NULL;
}

uint16_t fat16_open_file(struct fat16_volinfo *fv, struct fat16_file *file, char *path)
{
	struct fat16_dirent *dirent;
	
	memset(file, 0, sizeof *file);
	file->fv = fv;
	
	// walk path from root
	dirent = fat16_walk_path(fv, path, 0);
	if (dirent) {
		file->starting_cluster = fat16_starting_cluster_to_data_cluster(fv, ((uint16_t)dirent->starting_cluster[1] << 8) | dirent->starting_cluster[0]);
		file->filesize[0] = ((uint16_t)dirent->filesize[1] << 8) | dirent->filesize[0];
		file->filesize[1] = ((uint16_t)dirent->filesize[3] << 8) | dirent->filesize[2];
		return 0;
	}
	return 0xFFFF;
}

uint16_t fat16_read_file(struct fat16_file *file, uint8_t *dst, uint16_t len)
{
	uint16_t bread, tmp[2], n, secoff, ncluster, cluster;
	
	bread = 0;

	// are we at the end of the file 
	tmp[0] = file->filepos[0];
	tmp[1] = file->filepos[1];
	fat16_add_byte_offset(tmp, len);
	if (fat16_cmp_loffset(file->filesize, tmp) == -1) { // is the filepos+len > filesize?
		// len bytes would be past the end of the file
		len = file->filesize[0] - file->filepos[0];
	}
	
	bread = len;
	
	while (len) {
		// how many bytes can we read from a sector based on the current filepos
		secoff = file->filepos[0] & 0x1FF;
		if ((len + secoff) > 512) {
			n = 512 - secoff;
		} else {
			n = len;
		}
		
		// how many clusters in is file->filepos?
		ncluster = (file->filepos[0] >> file->fv->log2_cluster) | (file->filepos[1] << file->fv->log2_cluster2);
		
		// now walk the FAT until we find this sector 
		cluster = file->starting_cluster;
		while (ncluster--) {
			cluster = fat16_next_cluster(file->fv, cluster);
		}
		
		// now we have the cluster to read let's map that to a sector
		tmp[0] = cluster;
		fat16_cluster_to_sector(file->fv, tmp);
		
		// now add the sector number in this cluster
		fat16_add_byte_offset(tmp, (file->filepos[0] >> 9) & (file->fv->sectors_per_cluster - 1));
		
		// now we have the sector on disk to read...
		sector_op(tmp, file->fv->secbuf, 0);
		
		// now copy out based on the offset inside the sector
		memcpy(dst, file->fv->secbuf + secoff, n);
		
		dst += n;
		len -= n;
		fat16_add_byte_offset(file->filepos, n);
	}

	return bread;
}
