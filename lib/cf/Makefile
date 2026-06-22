# Convert a motohex to Gowin EDA/verilog style hex data
boot_hex_to_rom: tools/boot_hex_to_rom.c
	gcc tools/boot_hex_to_rom.c -o boot_hex_to_rom

# the actual file we stuff in at F000..F7FF as the bios rom
mon_p25.hex.mi: boot_hex_to_rom
	./boot_hex_to_rom < cf/BIOS.HEX > mon_p25.hex.mi

# Converts a motohex to a .CF program we'll be able to load in CFLEA-DOS
hex_to_cf: tools/hex_to_cf.c
	gcc tools/hex_to_cf.c -o hex_to_cf

# Tool to patch the disk image to include our boot.bin boot loader 
patch_fs: tools/patch_fs.c
	gcc tools/patch_fs.c -o patch_fs

# The bootloader the loads /COMMAND.CF from a FAT-16 formatted SD card (no partition) 
boot.bin: hex_to_cf
	./hex_to_cf cf/BOOT.HEX boot.bin E200 EFFF

# Build the disk.fs file system image with the bootloader any files in disk/* end up in the disk image
.PHONY: populate_fs
populate_fs: boot.bin patch_fs
	rm -f disk.fs
	truncate --size 32M disk.fs
	mkfs.fat -F 16 -R 8 disk.fs
	mkdir -p mnt_test
	sudo mount -o loop,uid=$$(id -u),gid=$$(id -g) disk.fs mnt_test
	cp disk/* mnt_test/
	sudo umount mnt_test
	rmdir mnt_test
	./patch_fs disk.fs boot.bin

clean:
	rm -rf *.bin *.vvp *.vcd *.pass *.log lds lds.hex boot_hex_to_rom boot_test_sim.hex *.mi hex_to_cf patch_fs disk.fs
