#ifndef FAT16_H_
#define FAT16_H_

// simple FAT16 library for sector==512 file systems

#include <stdint.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>

extern unsigned sector_op(uint16_t sector[2], uint8_t *data, unsigned wr_en);

struct fat16_volinfo {
// from the header
	uint8_t sectors_per_cluster;
	uint16_t bytes_per_cluster;
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

struct fat16_de {
	struct fat16_volinfo *fv;
	uint16_t cur_cluster;		// current sector we're reading from
	uint8_t cur_sector;			// current sector # in the cluster
	uint8_t cur_entry;			// current entry in the sector
};

unsigned fat16_initvol(struct fat16_volinfo *fv, uint8_t *secbuf);
uint16_t fat16_starting_cluster_to_data_cluster(struct fat16_volinfo *fv, uint16_t starting_cluster);
void fat16_opendir(struct fat16_volinfo *fv, struct fat16_de *de, uint16_t cluster);
struct fat16_dirent *fat16_nextdirent(struct fat16_de *de);
uint16_t fat16_next_cluster(struct fat16_volinfo *fv, uint16_t cluster);



#endif
