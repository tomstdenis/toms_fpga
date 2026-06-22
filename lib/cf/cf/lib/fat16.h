#ifndef FAT16_H_
#define FAT16_H_

// simple FAT16 library for sector==512 file systems
// This code is intended to be used with DDS Micro-C which is an
// almost ANSI C compliant C compiler that has several annoying limitations
// but for reasons of nostalgia and I'm insane I'm using anyways
// 1. Symbols can only have 15 chars, they will collide if the first 15 are the same
// 2. Struct members are NOT it seems in their own name space so they will collide
// 3. It only supports 16 bit data types

// With that in mind ... I present you this madness that is simply meant to be able
// to walk a FAT16 tree, find a file, and read from it.  Kinda bare bones.  No writing
// support (yet?)

#define uint8_t unsigned char
#define uint16_t unsigned

extern uint16_t sector_op(uint16_t sector[2], uint8_t *data, uint16_t wr_en);

// our structure holding info about the volume
struct fat16_volinfo {
// from the header
	uint8_t sec_cluster;							// sectors per cluster
	uint16_t byte_cluster;							// bytes per cluster
	uint16_t lg2_bpc;								// log2 # of bytes per cluster
	uint16_t lg2_bpc2;								// 16 - log2 # of bytes per cluster
	uint16_t lg2_spc;								// log2 # of sectors per cluster
	uint16_t lg2_spc2;								// 16 - log2 of # of sectors per cluster
	uint8_t no_fats;								// number of FATs
	uint16_t no_root;								// number of root entries
	uint16_t sec_fat;								// sectors per FAT
	uint16_t resv_sec;								// reserved sectors
// computed from header
	uint16_t fat_c;									// starting cluster of the FAT
	uint16_t root_dir_c;							// starting cluster of the root directory
	uint16_t data_c;								// starting cluster of data region
// our buffer we can work with to do operations
	uint8_t *secbuf;
	
// dirent 
	uint8_t *dirent;
	
// de walker
	uint16_t de_cluster;
	uint8_t  de_sector;
	uint8_t  de_entry;
	
// file
	uint16_t f_cluster;
	uint16_t f_size[2];
	uint16_t f_pos[2];
};

#define D_FNAME(fv)   (&fv->dirent[0])
#define D_EXT(fv)     (&fv->dirent[8])
#define D_ATTRIB(fv)  (fv->dirent[0x0B])
#define D_CLUSTER(fv) (((uint16_t)(fv->dirent[0x1B])<<8) | fv->dirent[0x1A])
#define D_FZ0(fv)	  (((uint16_t)(fv->dirent[0x1D])<<8) | fv->dirent[0x1C])			
#define D_FZ1(fv)	  (((uint16_t)(fv->dirent[0x1F])<<8) | fv->dirent[0x1E])			

// helper functions
void fat16_c_to_s(struct fat16_volinfo *fv, uint16_t p[2]);			// cluster to sector addressing
void fat16_s_to_b(uint16_t p[2]);									// sector to byte addressing
void fat16_b_to_s(uint16_t p[2]);									// byte to sector addressing
void fat16_add_16(uint16_t p[2], uint16_t off);						// add 16 bits to a 32-bit value
void fat16_add_32(uint16_t p[2], uint16_t off[2]);					// add 32 bits to a 32-bit value
int fat16_cmp_32(uint16_t a[2], uint16_t b[2]);						// compare 32-bit a to 32-bit b

// volume/FAT related
uint16_t fat16_initvol(struct fat16_volinfo *fv, uint8_t *secbuf);	// init the volinfo structure
uint16_t fat16_sc2dc(struct fat16_volinfo *fv, uint16_t scluster);	// convert starting cluster to data cluster
uint16_t fat16_n_c(struct fat16_volinfo *fv, uint16_t cluster);		// find the next cluster

// directory related
void fat16_opendir(struct fat16_volinfo *fv, uint16_t cluster);		// open a directory
uint16_t fat16_nextdir(struct fat16_volinfo *fv);					// walk to next entry
uint16_t fat16_wpath(struct fat16_volinfo *fv, char *path);			// walk a file system path to a dirent

// file related
uint16_t fat16_fopen(struct fat16_volinfo *fv, char *path);
uint16_t fat16_fread(struct fat16_volinfo *fv, uint8_t *dst, uint16_t len);

#endif
