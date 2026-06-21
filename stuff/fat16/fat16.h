#ifndef FAT16_H_
#define FAT16_H_

// simple FAT16 library for sector==512 file systems

#include <stdint.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>

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
};

// a FAT16 directory entry
struct fat16_dirent {
	uint8_t filename[8];
	uint8_t ext[3];
	uint8_t attrib;
	uint8_t res0;
	uint8_t ctime_ms;
	uint8_t ctime[2];								// creation time
	uint8_t cdate[2];								// creation date
	uint8_t ldate[2];								// last access date
	uint8_t res1[2];
	uint8_t lwtime[2];								// last write time
	uint8_t lwdate[2];								// last write date
	uint8_t scluster[2];							// starting cluster
	uint8_t filesz[4];
};

// FAT16 directory walker structure
struct fat16_de {
	uint16_t cur_cluster;							// current sector we're reading from
	uint8_t cur_sector;								// current sector # in the cluster
	uint8_t cur_entry;								// current entry in the sector
};

// a currently open file
struct fat16_file {
	uint16_t scluster;								// starting cluster
	uint16_t filesz[2];								// file size
	uint16_t filepos[2];							// current file position
};

void fat16_c_to_s(struct fat16_volinfo *fv, uint16_t p[2]);			// cluster to sector addressing
void fat16_s_to_b(uint16_t p[2]);									// sector to byte addressing
void fat16_b_to_s(uint16_t p[2]);									// byte to sector addressing
void fat16_add_16(uint16_t p[2], uint16_t off);						// add 16 bits to a 32-bit value
void fat16_add_32(uint16_t p[2], uint16_t off[2]);					// add 32 bits to a 32-bit value
int fat16_cmp_32(uint16_t a[2], uint16_t b[2]);						// compare 32-bit a to 32-bit b

uint16_t fat16_initvol(struct fat16_volinfo *fv, uint8_t *secbuf);		// init the volinfo structure
uint16_t fat16_sc2dc(struct fat16_volinfo *fv, uint16_t scluster);		// convert starting cluster to data cluster
uint16_t fat16_n_c(struct fat16_volinfo *fv, uint16_t cluster);			// find the next cluster

void fat16_opendir(struct fat16_volinfo *fv, struct fat16_de *de, uint16_t cluster);		// open a directory
struct fat16_dirent *fat16_nextdir(struct fat16_volinfo *fv, struct fat16_de *de);		// walk to next entry
struct fat16_dirent *fat16_wpath(struct fat16_volinfo *fv, char *path);					// walk a file system path to a dirent

uint16_t fat16_fopen(struct fat16_volinfo *fv, struct fat16_file *file, char *path);
uint16_t fat16_fread(struct fat16_volinfo *fv, struct fat16_file *file, uint8_t *dst, uint16_t len);

#endif
