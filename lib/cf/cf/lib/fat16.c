#include "cf/lib/fat16.h"

#ifdef USE_BOOT

uint16_t sector_op(uint16_t sector[2], uint8_t *data, uint16_t wr_en)
{
	asm {
		JMP SECTOR_OP
	};
}

// convert a directory starting cluster to a data cluster
uint16_t fat16_sc2dc(struct fat16_volinfo *fv, uint16_t scluster)
{
	asm {
		JMP FAT16_SC2DC
	};
}

// map a cluster to a disk sector
void fat16_c_to_s(struct fat16_volinfo *fv, uint16_t p[2])
{
	asm {
		JMP FAT16_C_TO_S
	};
}

// map a sector to a byte address
void fat16_s_to_b(uint16_t p[2])
{
	asm {
		JMP FAT16_S_TO_B
	};
}

// map a byte address back to a sector address
void fat16_b_to_s(uint16_t p[2])
{
	asm {
		JMP FAT16_B_TO_S
	};
}

// add a 16-bit offset to a 32-bit byte offset
void fat16_add_16(uint16_t p[2], uint16_t off)
{
	asm {
		JMP FAT16_ADD_16
	};
}

// add a 32-bit offset to a 32-bit byte offset
void fat16_add_32(uint16_t p[2], uint16_t off[2])
{
	asm {
		JMP FAT16_ADD_32
	};
}

// compare a and b, return 1 if GT, 0 if EQ, -1 if LT
int fat16_cmp_32(uint16_t a[2], uint16_t b[2])
{
	asm {
		JMP FAT16_CMP_32
	};
}

// init a FAT-16 volume state
// secbuf should point to a 512 byte buffer it can use to hold sectors
uint16_t fat16_initvol(struct fat16_volinfo *fv, uint8_t *secbuf)
{
	asm {
		JMP FAT16_INITVOL
	};
}

// given a cluster find the next cluster according to the FAT
// values >= 0xFFF8 mean end of chain.
uint16_t fat16_n_c(struct fat16_volinfo *fv, uint16_t cluster)
{
	asm {
		JMP FAT16_N_C
	};
}

// open a directory 'fat16_de' that can be used with fat16_nextdir()
// cluster==0 means use the root directory
void fat16_opendir(struct fat16_volinfo *fv, uint16_t cluster)
{
	asm {
		JMP FAT16_OPENDIR
	};
}

// return the next directory entry for the currently open directory
// or NULL if we hit the end
uint16_t fat16_nextdir(struct fat16_volinfo *fv) 
{
	asm {
		JMP FAT16_NEXTDIR
	};
}

// walk a directory with a path, returns a dirent on success or NULL on error
// paths start from the root and must begin with /
uint16_t fat16_wpath(struct fat16_volinfo *fv, char *path)
{
	asm {
		JMP FAT16_WPATH
	};
}

// open a file, populates 'file' with the handle, returns 0 on success
uint16_t fat16_fopen(struct fat16_volinfo *fv, char *path)
{
	asm {
		JMP FAT16_FOPEN
	};
}

// read from a file upto either len bytes or the end of the file whichever comes first
// returns the # of bytes actually read
uint16_t fat16_fread(struct fat16_volinfo *fv, uint8_t *dst, uint16_t len)
{
	asm {
		JMP FAT16_FREAD
	};
}

#else
// convert a directory starting cluster to a data cluster
uint16_t fat16_sc2dc(struct fat16_volinfo *fv, uint16_t scluster)
{
	return fv->data_c + scluster - 2;
}

// map a cluster to a disk sector
void fat16_c_to_s(struct fat16_volinfo *fv, uint16_t p[2])
{
	p[1] = (p[1] << fv->lg2_spc) | (p[0] >> fv->lg2_spc2);
	p[0] = (p[0] << fv->lg2_spc);
}

// map a sector to a byte address
void fat16_s_to_b(uint16_t p[2])
{
	p[1] = (p[1] << 9) | (p[0] >> 7);
	p[0] = p[0] << 9;
}

// map a byte address back to a sector address
void fat16_b_to_s(uint16_t p[2])
{
	p[0] = (p[0] >> 9) | (p[1] << 7);
	p[1] = p[1] >> 9;
}

// add a 16-bit offset to a 32-bit byte offset
void fat16_add_16(uint16_t p[2], uint16_t off)
{
	p[1] += ((p[0] += off) < off);
}

// add a 32-bit offset to a 32-bit byte offset
void fat16_add_32(uint16_t p[2], uint16_t off[2])
{
	p[1] += off[1] + ((p[0] += off[0]) < off[0]);
}

// compare a and b, return 1 if GT, 0 if EQ, -1 if LT
int fat16_cmp_32(uint16_t a[2], uint16_t b[2])
{
	if (a[1] > b[1]) return 1;
	if (a[1] < b[1]) return -1;
	if (a[0] > b[0]) return 1;
	if (a[0] < b[0]) return -1;
	return 0;
}

// init a FAT-16 volume state
// secbuf should point to a 512 byte buffer it can use to hold sectors
uint16_t fat16_initvol(struct fat16_volinfo *fv, uint8_t *secbuf)
{
	uint16_t sector[2];
	
	memset(fv, 0, sizeof(struct fat16_volinfo));
	fv->secbuf = secbuf;
	
	// read boot sector
	sector[0] = sector[1] = 0;
	if (sector_op(sector, secbuf, 0)) {
		return 0xFF;
	}
	
	// parse fields
	fv->sec_cluster    = secbuf[0x000D];
	fv->byte_cluster   = fv->sec_cluster << 9;
	fv->lg2_bpc        = 0;
	fv->no_fats        = secbuf[0x0010];
	fv->no_root 	   = *((uint16_t*)(secbuf+0x11)); // ((uint16_t)secbuf[0x0012] << 8) | secbuf[0x0011];
	fv->sec_fat        = *((uint16_t*)(secbuf+0x16)); // ((uint16_t)secbuf[0x0017] << 8) | secbuf[0x0016];
	fv->resv_sec       = *((uint16_t*)(secbuf+0xE)); // ((uint16_t)secbuf[0x000F] << 8) | secbuf[0x000E];
	
	// cluster offsets
	fv->fat_c            = (fv->resv_sec / fv->sec_cluster);
	fv->root_dir_c       = fv->fat_c + (fv->no_fats * (fv->sec_fat / fv->sec_cluster));
	fv->data_c           = fv->root_dir_c + (((fv->no_root * 32) / 512) / fv->sec_cluster);
	
	// compute log2 of cluster size
	sector[0] = fv->byte_cluster;
	while (sector[0] != 1) {
		++(fv->lg2_bpc);
		sector[0] >>= 1;
	}
	fv->lg2_bpc2 = 16 - fv->lg2_bpc;
	fv->lg2_spc  = fv->lg2_bpc - 9;
	fv->lg2_spc2 = 16 - fv->lg2_spc;
	
	return 0;
}

// given a cluster find the next cluster according to the FAT
// values >= 0xFFF8 mean end of chain.
uint16_t fat16_n_c(struct fat16_volinfo *fv, uint16_t cluster)
{
	uint16_t sector[2];
	uint16_t off;
	
/*
 * 'cluster' is an index into a table starting at sector (fv->fat_c * fv->sec_cluster * 512 + cluster * 2) / 512 */
 
	sector[1] = 0;
	sector[0] = fv->fat_c;				// start at the starting of the first FAT table
	fat16_c_to_s(fv, sector);			// convert cluster to sector 
	fat16_s_to_b(sector);				// convert sector byte
	fat16_add_16(sector, cluster);
	fat16_add_16(sector, cluster);
	
	off = (sector[0] >> 1) & 0xFF;  // byte offset into sector
	fat16_b_to_s(sector);
	sector_op(sector, fv->secbuf, 0);
	//DEBUG("next cluster of 0x%04x is 0x%04x\n", cluster, ((uint16_t *)fv->secbuf)[off]);
	return ((uint16_t *)fv->secbuf)[off];
}

// open a directory 'fat16_de' that can be used with fat16_nextdir()
// cluster==0 means use the root directory
void fat16_opendir(struct fat16_volinfo *fv, uint16_t cluster)
{
	uint16_t sector[2];
	
	cluster = cluster ? cluster : fv->root_dir_c;
	
	fv->de_cluster = cluster;
	fv->de_entry   = 0;
	fv->de_sector  = 0;

	sector[1] = 0;
	sector[0] = cluster;
	fat16_c_to_s(fv, sector);
	sector_op(sector, fv->secbuf, 0);		// read dirent
}

// return the next directory entry for the currently open directory
// or NULL if we hit the end
uint16_t fat16_nextdir(struct fat16_volinfo *fv) 
{
	uint16_t sector[2];

top:
	//DEBUG("nextdirent: %u, %u, %u\n", fv->de_cluster, fv->de_sector, fv->de_entry);
	// still inside the sector? (there are 16 dirent's per sector)
	if (fv->de_entry < 16) {
		fv->dirent = &(fv->secbuf[32 * fv->de_entry++]);
		if (D_FNAME(fv)[0] == 0) {
			//DEBUG("filename[0] is zero...\n");
			// end of this directory
			return 0xFFFF;
		} else if (D_FNAME(fv)[0] == 0xE5) {
			//DEBUG("filename[0] is 0xE5\n");
			// this entry is a deleted file
			goto top;
		}
		return 0;
	}
	// we're at the end of the sector so we need to get the next
	if (fv->de_sector == (fv->sec_cluster - 1)) {
		// we're at the end of this cluster so we need to read the FAT to find the next in the chain
		fv->de_cluster = fat16_n_c(fv, fv->de_cluster);
		if (fv->de_cluster >= 0xFFF8) {
			// end of cluster chain
			//DEBUG("de->cluser is >= 0xFFF8\n");
			return 0xFFFF;
		}
		fv->de_sector = 0;
	} else {
		++(fv->de_sector);
	}
	
	// read next sector
	sector[1] = 0;
	sector[0] = fv->de_cluster;
	fat16_c_to_s(fv, sector);
	sector[0] += fv->de_sector;
	if (sector[0] < fv->de_sector) {
		// carry into top 16 bits
		++sector[1];
	}
	sector_op(sector, fv->secbuf, 0);
	
	// go back to top 
	goto top;
}

// walk a directory with a path, returns a dirent on success or NULL on error
// paths start from the root and must begin with /
uint16_t fat16_wpath(struct fat16_volinfo *fv, char *path)
{
	char pathname[13]; // 8 . 3
	char filename[11];
	uint16_t x, y, dircluster;

	dircluster = 0;
top:

	//DEBUG("Starting with [%s]\n", path);

	// check for leading /
	if (*path++ != '/') return 0xFFFF;

	// extract fname
	x = 0;
	while (*path != '/' && *path && x < 12) {
		pathname[x++] = *path++;
	}
	pathname[x] = 0;
	
	//DEBUG("remaining path == [%s]\n", path);
	//DEBUG("pathname == [%s]\n", pathname);
	
	// sanity check
	if (x == 12 && *path && *path != '/') {
		//DEBUG("Error: pathname is too long\n");
		return 0xFFFF;
	}
	
	// format filename/ext
	memset(filename, ' ', 11);
	
	// scan out pathname to filename+ext
	x = y = 0;
	while (x < 8 && pathname[y] != '.' && pathname[y]) {
		filename[x++] = pathname[y++];
	}
	if (pathname[y] == '.') {
		x = 0;
		++y;
		while (x < 3 && pathname[y]) {
			filename[8 + x++] = pathname[y++];
		}
	}
	
	//DEBUG("filename = [%c%c%c%c%c%c%c%c]\n", filename[0], filename[1], filename[2], filename[3], filename[4], filename[5], filename[6], filename[7]);
	//DEBUG("ext = [%c%c%c]\n", ext[0], ext[1], ext[2]);
	
	// now let's open the directory
	fat16_opendir(fv, dircluster);
	
	while (!fat16_nextdir(fv)) {
		if (!memcmp(filename, D_FNAME(fv), 11)) {
			// found it, but do we need to loop?
			if (*path == '/') {
				if (D_ATTRIB(fv) & 0x10) {
					// it's a directory so loop
					dircluster = fat16_sc2dc(fv, D_CLUSTER(fv));
					goto top;
				} else {
					// it's not a directory so error
					//DEBUG("Error: dirent isn't a directory\n");
					return 0xFFFF;
				}
			} else {
				return 0;
			}
		}
	}
	return 0xFFFF;
}

// open a file, populates 'file' with the handle, returns 0 on success
uint16_t fat16_fopen(struct fat16_volinfo *fv, char *path)
{
	// walk path from root
	if (!fat16_wpath(fv, path)) {
		fv->f_cluster = D_CLUSTER(fv);
		fv->f_size[0] = D_FZ0(fv);
		fv->f_size[1] = D_FZ1(fv);
		fv->f_pos[0]  = 0;
		fv->f_pos[1]  = 0;
		return 0;
	}
	return 0xFFFF;
}

// read from a file upto either len bytes or the end of the file whichever comes first
// returns the # of bytes actually read
uint16_t fat16_fread(struct fat16_volinfo *fv, uint8_t *dst, uint16_t len)
{
	uint16_t bread, tmp[2], n, secoff, ncluster, cluster;
	
	bread = 0;

	// are we at the end of the file 
	tmp[0] = fv->f_pos[0];
	tmp[1] = fv->f_pos[1];
	fat16_add_16(tmp, len);
	if (fat16_cmp_32(fv->f_size, tmp) == -1) { // is the filepos+len > filesz?
		// len bytes would be past the end of the file
		len = fv->f_size[0] - fv->f_pos[0];
	}

/*
 * The loop below could be optimized by caching the current cluster address/sector contents
 * but since this is meant for small memory environments where you could have multiple files
 * open at once we brute force the FAT cluster walk and sector read even if you're just reading
 * 1 byte at a time.  This allows fv->secbuf to be reused across other file accesses.
 * Which means you really should minimize the # of calls to this function.
 */

	// now we loop reading len bytes which may span multiple sectors or clusters
	while (len) {
		// how many bytes can we read from a sector based on the current filepos
		secoff = fv->f_pos[0] & 0x1FF;
		if ((len + secoff) > 512) {
			n = 512 - secoff;
		} else {
			n = len;
		}
		
		// how many clusters in is fv->f_pos? (divided filepos by the # of bytes in a cluster or shift by lg2_bpc)
		ncluster = (fv->f_pos[0] >> fv->lg2_bpc) | (fv->f_pos[1] << fv->lg2_bpc2);

		//DEBUG("len==%x, secoff==%x, n==%x, filepos==%04x%04x, ncluster=%x\n", len, secoff, n, fv->f_pos[1], fv->f_pos[0], ncluster);
		
		// now walk the FAT until we find this sector 
		cluster = fv->f_cluster;
		while (ncluster--) {
			cluster = fat16_n_c(fv, cluster);
			if (cluster >= 0xFFF8) {
				// somehow we hit a terminal FAT cluster so return
				return bread;
			}
		}
		
		// now we have the cluster to read let's map that to a sector
		tmp[1] = 0;
		tmp[0] = fat16_sc2dc(fv, cluster);							// map it to the data region
		fat16_c_to_s(fv, tmp);										// convert cluster address to sector address
		
		// now add the sector number in this cluster (this will work upto 16K clusters)
		fat16_add_16(tmp, (fv->f_pos[0] >> 9) & (fv->sec_cluster - 1)); // add the # of sectors into this cluster we are
		
		// now we have the sector on disk to read...
		sector_op(tmp, fv->secbuf, 0);
		
		// now copy out based on the offset inside the sector
		memcpy(dst, fv->secbuf + secoff, n);
		
		// update pointers/counters
		dst += n;
		len -= n;
		bread += n;
		fat16_add_16(fv->f_pos, n);
	}

	return bread;
}
#endif
