# pseudo build process
# 1. In dosbox in cf/ run BIOS.BAT
# 2. Run "make cf/lib/bios.h"
# 3. In dosbox in cf/ run M.BAT
# 4. make hex_to_cf
# 5. run ./hex_to_cf cf/GPIO.HEX disk/COMMAND.CF 0000 0000 1000
# 6. make populate_fs
# 7. dd if=disk.fs of=/dev/sdX ibs=512
# 8. sync

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
.PHONY: boot.bin
boot.bin: hex_to_cf cf/boot.hex
	./hex_to_cf cf/boot.hex boot.bin E200 EFFF

cf/boot.hex: cf/boot.c cf/lib/bios.h
	emu2 MCF/CCF.COM 'cf/boot.c' -fopa -- MCDIR='C:\MCF'
	emu2 MCF/ASMCF.EXE 'cf/boot.asm' -fs -- MCDIR='C:\MCF'

sym_to_biosh: tools/sym_to_biosh.c
	gcc tools/sym_to_biosh.c -o sym_to_biosh

.PHONY: cf/lib/bios.h
cf/lib/bios.h: sym_to_biosh cf/bios.lst
	./sym_to_biosh < cf/bios.lst > cf/lib/bios.h

cf/bios.asm: cf/bios.c	
	emu2 MCF/CCF.COM 'cf/bios.c' -fopa -- MCDIR='C:\MCF'

cf/bios.lst: cf/bios.asm
	emu2 MCF/ASMCF.EXE 'cf/bios.asm' -fs -- MCDIR='C:\MCF'

# Build the disk.fs file system image with the bootloader any files in disk/* end up in the disk image
.PHONY: populate_fs
populate_fs: boot.bin patch_fs cf/lib/bios.h
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
	rm -rf *.bin *.vvp *.vcd *.pass *.log lds lds.hex boot_hex_to_rom boot_test_sim.hex *.mi hex_to_cf patch_fs disk.fs sym_to_biosh cf/*.asm cf/*.hex cf/*.lst cf/lib/bios.h
