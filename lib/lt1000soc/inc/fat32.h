#ifndef LT1000_FAT32_H
#define LT1000_FAT32_H

#define FAT32_ERR_SEC_READ 			-1
#define FAT32_ERR_SEC_WRITE			-2
#define FAT32_ERR_INV_MBR 			-3
#define FAT32_ERR_INV_VBR 			-4
#define FAT32_ERR_OOM				-5
#define FAT32_ERR_INV_PATH          -6
#define FAT32_ERR_PATH_NOT_FOUND	-7
#define FAT32_ERR_INV_SEC_SIZE      -8
#define FAT32_ERR_INV_PART_TYPE     -9

#define FAT32_F_RDONLY 0x01
#define FAT32_F_HIDDEN 0x02
#define FAT32_F_SYSTEM 0x04
#define FAT32_F_VOLNAM 0x08
#define FAT32_F_DIR    0x10
#define FAT32_F_ARC    0x20

// MBR/VBR
struct fat32_mbr {
	uint32_t
		bytes_per_sector,					// bytes per sector must be 512
		sectors_per_cluster,				// sectors per cluster
		reserved_sectors,					// number of sectors reserved after the MBR before the FAT
		number_of_fats,						// number of FAT tables
		sectors_per_fat,					// # of sectors per FAT table
		root_directory_cluster;				// start of root directory
};

struct fat32_disk {
	struct fat32_mbr vbr;
	uint32_t
		cs_sel,								// CS pin selector
		oper_div,							// SPI clk divider
		lba_start,							// linear byte address where partition 1 starts
		fat_sector,							// sector of start of FAT
		data_region_sector;					// sector of start of data region
};

// one directory entry
struct fat32_dirent_raw {
	uint8_t filename[9];
	uint8_t fileext[4];
	uint8_t flags;
	uint32_t start_cluster;
	uint32_t file_size; 
};

struct fat32_dirent {
	struct fat32_disk *dsk;
	uint32_t
		dir_pos,							// position inside the secbuf
		sec_no,								// sector inside the cluster
		cur_cluster;						// which cluster are we at
	uint8_t secbuf[512];
	struct fat32_dirent_raw de;
};

struct fat32_file {
	struct fat32_disk       *dsk;			// the disk
	struct fat32_dirent_raw *de;			// directory entry for this file
	uint32_t
		fpos,								// byte offset into file
		sec_no,								// which sector of the cluster are we in
		cur_cluster;						// which cluster are we on
	uint8_t secbuf[512];
};

extern int fat32_errno;

struct fat32_disk *fat32_init_disk(uint32_t cs_sel, uint32_t oper_div);
struct fat32_dirent *fat32_opendir(struct fat32_disk *dsk, uint32_t cluster);
struct fat32_dirent_raw *fat32_readdir(struct fat32_dirent *de);

struct fat32_dirent_raw *fat32_find_path(struct fat32_disk *dsk, const char *path);
struct fat32_file *fat32_open(struct fat32_disk *dsk, char *fpath);
void fat32_close(struct fat32_file *file);
uint32_t fat32_read(struct fat32_file *file, uint8_t *dst, uint32_t len);
int fat32_seek(struct fat32_file *file, uint32_t offset);


#endif
