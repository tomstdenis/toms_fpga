#ifndef FAT16_H_
#define FAT16_H_

// simple FAT16 library for sector==512 file systems

#include <stdint.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>

extern unsigned sector_op(uint16_t sector[2], uint8_t *data, unsigned wr_en);

// our structure holding info about the volume
struct fat16_volinfo {
// from the header
	uint8_t sectors_per_cluster;
	uint16_t bytes_per_cluster;
	uint16_t log2_cluster;
	uint16_t log2_cluster2;
	uint16_t log2_cluster_sec;
	uint16_t log2_cluster2_sec;
	uint8_t number_of_fats;
	uint16_t number_of_root_entries;
	uint16_t sectors_per_fat;
	uint16_t reserved_sectors;
// computed from header
	uint16_t fat_cluster;
	uint16_t root_dir_cluster;
	uint16_t data_cluster;
// our buffer we can work with to do operations
	uint8_t *secbuf;
};

// a FAT16 directory entry
struct fat16_dirent {
	uint8_t filename[8];
	uint8_t ext[3];
	uint8_t attrib;
	uint8_t res0;
	uint8_t creation_time_ms;
	uint8_t creation_time[2];
	uint8_t creation_date[2];
	uint8_t last_access_date[2];
	uint8_t res1[2];
	uint8_t last_write_time[2];
	uint8_t last_write_date[2];
	uint8_t starting_cluster[2];
	uint8_t filesize[4];
};

// FAT16 directory walker structure
struct fat16_de {
	struct fat16_volinfo *fv;
	uint16_t cur_cluster;		// current sector we're reading from
	uint8_t cur_sector;			// current sector # in the cluster
	uint8_t cur_entry;			// current entry in the sector
};

// a currently open file
struct fat16_file {
	struct fat16_volinfo *fv;
	uint16_t starting_cluster;
	uint16_t filesize[2];
	uint16_t filepos[2];
};

void fat16_cluster_to_sector(struct fat16_volinfo *fv, uint16_t p[2]);
void fat16_sector_to_byte(uint16_t p[2]);
void fat16_byte_to_sector(uint16_t p[2]);
void fat16_add_byte_offset(uint16_t p[2], uint16_t off);
void fat16_add_byte_loffset(uint16_t p[2], uint16_t off[2]);
int fat16_cmp_loffset(uint16_t a[2], uint16_t b[2]);

unsigned fat16_initvol(struct fat16_volinfo *fv, uint8_t *secbuf);
uint16_t fat16_starting_cluster_to_data_cluster(struct fat16_volinfo *fv, uint16_t starting_cluster);
uint16_t fat16_next_cluster(struct fat16_volinfo *fv, uint16_t cluster);

void fat16_opendir(struct fat16_volinfo *fv, struct fat16_de *de, uint16_t cluster);
struct fat16_dirent *fat16_nextdirent(struct fat16_de *de);
struct fat16_dirent *fat16_walk_path(struct fat16_volinfo *fv, char *path);

uint16_t fat16_open_file(struct fat16_volinfo *fv, struct fat16_file *file, char *path);
uint16_t fat16_read_file(struct fat16_file *file, uint8_t *dst, uint16_t len);

#endif
