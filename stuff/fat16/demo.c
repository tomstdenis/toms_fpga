#include "fat16.h"
#include <stdint.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>

FILE *f;
uint16_t sector_op(uint16_t sector[2], uint8_t *data, uint16_t wr_en)
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
	uint16_t fat_c;
	uint16_t root_dir_c;
	uint16_t data_c;
// our buffer we can work with to do operations
	uint8_t *secbuf;
};
*/

void dump_file(struct fat16_volinfo *fv, uint16_t cluster)
{
	do {
		printf("File cluster: %u\n", cluster);
		cluster = fat16_n_c(fv, cluster);
	} while (cluster < 0xFFF8);
}

void walk_directory(struct fat16_volinfo *fv, uint16_t cluster)
{
	unsigned char tmpbuf[512];
	fat16_opendir(fv, cluster);
	while ((!fat16_nextdir(fv))) {
		char buf[16];
		
		memset(buf, 0, sizeof(buf)); memcpy(buf, D_FNAME(fv), 8); printf("Filename: [%s], ", buf);
		memset(buf, 0, sizeof(buf)); memcpy(buf, D_EXT(fv), 3); printf("ext: [%s], ", buf);
		printf("starting cluster: 0x%04x, ", D_CLUSTER(fv));
		printf("filesz: 0x%04x%04x, ", D_FZ1(fv), D_FZ0(fv)); 
		printf("attribute: 0x%02x", D_ATTRIB(fv));
		printf("\n");
		
		if (!memcmp(D_FNAME(fv), "RND     ", 8) && !memcmp(D_EXT(fv), "BIN", 3)) {
			memcpy(tmpbuf, fv->secbuf, 512);
			dump_file(fv, D_CLUSTER(fv));
			memcpy(fv->secbuf, tmpbuf, 512);
		}
		
		if (D_ATTRIB(fv) & 0x10 && D_FNAME(fv)[0] != '.') {
			//directory
			printf("Walking into directory...\n");
			memcpy(tmpbuf, fv->secbuf, 512);
			walk_directory(fv, fat16_sc2dc(fv, D_CLUSTER(fv)));
			memcpy(fv->secbuf, tmpbuf, 512);
		}
	}
}

int main(void)
{
	struct fat16_volinfo fv;
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
		fv.sec_cluster, fv.byte_cluster, fv.lg2_bpc, fv.lg2_spc, fv.no_fats, fv.no_root, fv.sec_fat, fv.resv_sec);
		
	printf("fat sector: %u\nroot dir sector: %u\ndata sector: %5u\n",
		fv.fat_c * fv.sec_cluster,
		fv.root_dir_c * fv.sec_cluster,
		fv.data_c * fv.sec_cluster);
	printf("-----\n\n");
	
	// walk the root directory
	walk_directory(&fv, 0);
		
	// simple file test (to be replaced with stride test)
	{
		uint16_t r;
		uint8_t buf[8192];
		
		if (fat16_fopen(&fv, "/RND.BIN")) {
			printf("Couldn't open file /RND.BIN...\n");
			return -1;
		}
		 
		r = fat16_fread(&fv, buf, 10240);
		printf("Read %u bytes from file\n", r);
		if (r != 8192 || memcmp(buf, RNDBIN, 8192)) {
			printf("Read data differs from master\n");
			return -1;
		} else {
			printf("File contents compare correctly.\n");
		}
	}

}
