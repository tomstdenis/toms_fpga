#include "lt1000.h"

int walk_dir(struct fat32_disk *dsk, char *name, uint32_t cluster)
{
	char pathname[512];
	struct fat32_dirent *di;
	struct fat32_dirent_raw *de;
	
	di = fat32_opendir(dsk, cluster);
	if (!di) {
		printf("Could not open directory at cluster %u\n", cluster);
		return -1;
	}
	
	while ((de = fat32_readdir(di))) {
		if (strcmp(de->filename, ".") && strcmp(de->filename, "..")) {
			if (de->fileext[0]) {
				sprintf(pathname, "%s/%s.%s", name, de->filename, de->fileext);
			} else {
				sprintf(pathname, "%s/%s", name, de->filename);
			}
			printf("%s, start=%u, size=%u, flags=%u\n", pathname, de->start_cluster, de->file_size, de->flags);
			if (de->flags & FAT32_F_DIR) {
				walk_dir(dsk, pathname, de->start_cluster);
			}
		}
	}
	free(di);
}		

int main(void)
{
	struct fat32_disk *dsk;
	getch();
	
	dsk = fat32_init_disk(0, 4);
	if (!dsk) {
		printf("err == %d\n", fat32_errno);
	} else {
		printf("Disk info:\n");
		printf("Bytes per sector: %u\n", dsk->vbr.bytes_per_sector);
		printf("Sector per cluster: %u\n", dsk->vbr.sectors_per_cluster);
		printf("Resv sectors: %u\n", dsk->vbr.reserved_sectors);
		printf("Number of fats: %u\n", dsk->vbr.number_of_fats);
		printf("sectors per fat: %u\n", dsk->vbr.sectors_per_fat);
		printf("Root dir cluster: %u\n", dsk->vbr.root_directory_cluster);
		
		printf("LBA start: %u\n", dsk->lba_start);
		printf("FAT start: %u\n", dsk->fat_sector);
		printf("Data start: %u\n", dsk->data_region_sector);
		
		walk_dir(dsk, "", 0);
	}
}
