// BOOT.BIN is basically a tiny shell we can use to launch other apps
#include "lt1000.h"

// copy base[0..len-1] to PSRAM and then jump to start of PSRAM
TCM_FUNC(launch_app) static void launch_app(uint32_t *base, uint32_t len)
{
}

static void do_dir(struct fat32_disk *dsk, char *path, char *cmd)
{
	struct fat32_dirent *dir;
	struct fat32_dirent_raw *de;
	uint32_t dircluster = 0;
	
	if (path[1] != 0) {
		de = fat32_find_path(dsk, path);
		if (!de) {
			txt_printf("! Path [%s] not found on disk to display\r\n", path);
			return;
		}
		
		if (!(de->flags & FAT32_F_DIR)) {
			txt_printf("! Path [%s] is not a directory\r\n", path);
			free(de);
			return;
		}
		dircluster = de->start_cluster;
		free(de);
	}
	
	dir = fat32_opendir(dsk, dircluster);
	if (dir) {
		txt_printf("Contents of directory: %s\n\r   NAME\t\tEXT\tFILESIZE\tFLAGS\r\n", path);
		while ((de = fat32_readdir(dir))) {
			if (strcmp(de->filename, ".") && strcmp(de->filename, "..")) {
				txt_printf("%8s\t%3s\t%10u\t%x\r\n", de->filename, de->fileext, de->file_size, de->flags);
			}
		}
		free(dir);
	}
}

static void do_cd(struct fat32_disk *dsk, char *path, char *cmd)
{
	struct fat32_dirent_raw *de;
	char newpath[1024];

	if (cmd[0] == '/') {
		strcpy(newpath, cmd);
	} else {
// TODO: need to "apply" cmd to path not simple concat (should hoist that out)
		sprintf(newpath, "%s/%s", strlen(path) > 1 ? path : "", cmd);
	}
	
	de = fat32_find_path(dsk, newpath);
	if (!de) {
		txt_printf("! Path [%s] not found on disk\r\n", newpath);
		return;
	}
	
	if (!(de->flags & FAT32_F_DIR)) {
		txt_printf("! Path [%s] is not a directory\r\n", newpath);
		free(de);
		return;
	}
	free(de);
	strcpy(path, newpath);
}

static void do_cat(struct fat32_disk *dsk, char *path, char *cmd)
{
	struct fat32_file *file;
	char newpath[1024];
	
	sprintf(newpath, "%s/%s", path, cmd);
	file = fat32_open(dsk, newpath);
	if (file) {
		char buf[80];
		uint32_t x, y;
		while ((x = fat32_read(file, buf, sizeof buf)) != 0) {
			for (y = 0; y < x; y++) {
				txt_putc(buf[y]);
			}
		}
		free(file);
	} else {
		txt_printf("File [%s] not found\r\n", newpath);
	}
}

static void do_exec(struct fat32_disk *dsk, char *path, char *cmd)
{
}


void main(void)
{
	char path[1024], cmd[512];
	struct fat32_disk *dsk;
	
	txt_init();
	
	// init disk
	dsk = fat32_init_disk(0, 4);
	if (!dsk) {
		txt_printf("Could not open disk...\r\n");
		delay_ms(2000);
		return;
	}

	// initial path
	strcpy(path, "/");
	
	for (;;) {
		txt_printf("%s$ ", path);
		txt_gets(cmd);
		txt_printf("\r\n");
		
		if (!memcmp(cmd, "dir", 3)) {
			do_dir(dsk, path, cmd + 4);
		} else if (!memcmp(cmd, "cd", 2)) {
			do_cd(dsk, path, cmd + 3);
		} else if (!memcmp(cmd, "cat", 3)) {
			do_cat(dsk, path, cmd + 4);
		} else if (!memcmp(cmd, "exit", 4)) {
			return;
		} else {
			do_exec(dsk, path, cmd);
		}
	}
}
