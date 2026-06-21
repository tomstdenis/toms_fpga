#include "fat16.h"
#include <stdint.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>

FILE *f;
unsigned sector_op(uint16_t sector[2], uint8_t *data, unsigned wr_en)
{
	// here we can use 32-bit because this is just a PC demo
	uint32_t addr = ((uint32_t)sector[1] << 16) | sector[0];
	addr <<= 9;
//	printf("Reading from sector 0x%04x%04x\n", sector[1], sector[0]);
	if (fseek(f, addr, SEEK_SET)) {
		return 0xFFFF;
	}
	if (wr_en) {
		fwrite(data, 1, 512, f);
	} else {
		fread(data, 1, 512, f);
	}
	return 0;
}

/*
struct fat16_volinfo {
// from the header
	uint8_t sec_cluster;
	uint8_t no_fats;
	uint16_t no_root;
	uint16_t sectors_per_fat;
	uint16_t resv_sec;
// computed from header
	uint16_t fat_cluster;
	uint16_t root_dir_cluster;
	uint16_t data_cluster;
// our buffer we can work with to do operations
	uint8_t *secbuf;
};
*/

void dump_file(struct fat16_volinfo *fv, uint16_t cluster)
{
	do {
		printf("File cluster: %u\n", cluster);
		cluster = fat16_next_cluster(fv, cluster);
	} while (cluster < 0xFFF8);
}

void walk_directory(struct fat16_volinfo *fv, uint16_t cluster)
{
	struct fat16_de de;
	struct fat16_dirent *dirent;
	unsigned char tmpbuf[512];
	fat16_opendir(fv, &de, cluster);
	while ((dirent = fat16_nextdirent(fv, &de))) {
		char buf[16];
		
		memset(buf, 0, sizeof(buf)); memcpy(buf, dirent->filename, 8); printf("Filename: [%s], ", buf);
		memset(buf, 0, sizeof(buf)); memcpy(buf, dirent->ext, 3); printf("ext: [%s], ", buf);
		printf("starting cluster: 0x%02x%02x, ", dirent->starting_cluster[1], dirent->starting_cluster[0]);
		printf("filesize: 0x%02x%02x%02x%02x, ", dirent->filesize[3], dirent->filesize[2], dirent->filesize[1], dirent->filesize[0]); 
		printf("attribute: 0x%02x", dirent->attrib);
		printf("\n");
		
		if (!memcmp(dirent->filename, "RND     ", 8) && !memcmp(dirent->ext, "BIN", 3)) {
			memcpy(tmpbuf, fv->secbuf, 512);
			dump_file(fv, ((uint16_t)dirent->starting_cluster[1] << 8) | dirent->starting_cluster[0]);
			memcpy(fv->secbuf, tmpbuf, 512);
		}
		
		if (dirent->attrib & 0x10 && dirent->filename[0] != '.') {
			//directory
			printf("Walking into directory...\n");
			memcpy(tmpbuf, fv->secbuf, 512);
			walk_directory(fv, fat16_starting_cluster_to_data_cluster(fv, ((uint16_t)dirent->starting_cluster[1] << 8) | dirent->starting_cluster[0]));
			memcpy(fv->secbuf, tmpbuf, 512);
		}
	}
}

int main(void)
{
	struct fat16_volinfo fv;
	struct fat16_dirent *dirent;
	uint8_t secbuf[512], RNDBIN[8192];
	FILE *rnd;
	
	// load rnd
	rnd = fopen("RND.BIN", "rb");
	if (!rnd) {
		printf("RND.BIN not there mate, try harder.\n");
		return -1;
	}
	if (fread(RNDBIN, 1, 8192, rnd) != 8192) {
		printf("RND.BIN not 8192 bytes, like I know shit's tough but like get more disk space...\n");
		return -1;
	}
	fclose(rnd);
	
	f = fopen("test.fs", "rb");
	
	fat16_initvol(&fv, secbuf);
	
	// dump some info
	printf("Disk Information:\n");
	printf("Sectors per cluster: %u\nbytes per cluster: %u (%u, %u)\nnumber of fats: %u\nno_root: %u\nsectors_per_fat: %u\nresv_sec: %u\n",
		fv.sec_cluster, fv.byte_cluster, fv.log2_cluster, fv.log2_cluster_sec, fv.no_fats, fv.no_root, fv.sec_fat, fv.resv_sec);
		
	printf("fat sector: %u\nroot dir sector: %u\ndata sector: %5u\n",
		fv.fat_cluster * fv.sec_cluster,
		fv.root_dir_cluster * fv.sec_cluster,
		fv.data_cluster * fv.sec_cluster);
		
	printf("dirent size: %u\n", (unsigned)sizeof(struct fat16_dirent));
	printf("-----\n\n");
	
	// walk the root directory
	walk_directory(&fv, 0);
	
	// try path walks
	printf("\nTrying to walk path \"/RND.BIN\"\n");
	dirent = fat16_walk_path(&fv, "/RND.BIN");
	if (dirent) {
		char buf[16];
		memset(buf, 0, sizeof(buf)); memcpy(buf, dirent->filename, 8); printf("Filename: [%s], ", buf);
		memset(buf, 0, sizeof(buf)); memcpy(buf, dirent->ext, 3); printf("ext: [%s], ", buf);
		printf("starting cluster: 0x%02x%02x, ", dirent->starting_cluster[1], dirent->starting_cluster[0]);
		printf("filesize: 0x%02x%02x%02x%02x, ", dirent->filesize[3], dirent->filesize[2], dirent->filesize[1], dirent->filesize[0]); 
		printf("attribute: 0x%02x", dirent->attrib);
		printf("\n");
	} else {
		printf("Path not found\n");
	}
	
	printf("\nTrying to walk path \"/SUBDIR/SUBFILE.TXT\"\n");
	dirent = fat16_walk_path(&fv, "/SUBDIR/SUBFILE.TXT");
	if (dirent) {
		char buf[16];
		memset(buf, 0, sizeof(buf)); memcpy(buf, dirent->filename, 8); printf("Filename: [%s], ", buf);
		memset(buf, 0, sizeof(buf)); memcpy(buf, dirent->ext, 3); printf("ext: [%s], ", buf);
		printf("starting cluster: 0x%02x%02x, ", dirent->starting_cluster[1], dirent->starting_cluster[0]);
		printf("filesize: 0x%02x%02x%02x%02x, ", dirent->filesize[3], dirent->filesize[2], dirent->filesize[1], dirent->filesize[0]); 
		printf("attribute: 0x%02x", dirent->attrib);
		printf("\n");
	} else {
		printf("Path not found\n");
	}
	
	// simple file test (to be replaced with stride test)
	{
		struct fat16_file file;
		uint16_t r;
		uint8_t buf[8192];
		
		if (fat16_open_file(&fv, &file, "/RND.BIN")) {
			printf("Couldn't open file /RND.BIN...\n");
			return -1;
		}
		 
		r = fat16_read_file(&fv, &file, buf, 10240);
		printf("Read %u bytes from file\n", r);
		if (r != 8192 || memcmp(buf, RNDBIN, 8192)) {
			printf("Read data differs from master\n");
			return -1;
		} else {
			printf("File contents compare correctly.\n");
		}
	}

}
