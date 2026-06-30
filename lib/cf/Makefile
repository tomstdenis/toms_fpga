all: populate_fs

# Convert a motohex to Gowin EDA/verilog style hex data
boot_hex_to_rom: tools/boot_hex_to_rom.c
	gcc tools/boot_hex_to_rom.c -o boot_hex_to_rom

# the actual file we stuff in at F000..F7FF as the bios rom
mon_p25.hex.mi: boot_hex_to_rom cf/bios.hex
	./boot_hex_to_rom < cf/bios.hex > mon_p25.hex.mi

# Converts a motohex to a .CF program we'll be able to load in CFLEA-DOS
hex_to_cf: tools/hex_to_cf.c
	gcc tools/hex_to_cf.c -o hex_to_cf

# Tool to patch the disk image to include our boot.bin boot loader 
patch_fs: tools/patch_fs.c
	gcc tools/patch_fs.c -o patch_fs

# The bootloader the loads /COMMAND.CF from a FAT-16 formatted SD card (no partition)
boot.bin: hex_to_cf cf/boot.c cf/lib/bios.h
	emu2 MCF/CCF.COM 'cf/boot.c' -fopa -- MCDIR='C:\MCF'
	emu2 MCF/ASMCF.EXE 'cf/boot.asm' -fs -- MCDIR='C:\MCF'
	./hex_to_cf cf/boot.hex boot.bin E200 EFFF

sym_to_biosh: tools/sym_to_biosh.c
	gcc tools/sym_to_biosh.c -o sym_to_biosh

cf/lib/boot.h: sym_to_biosh boot.bin
	./sym_to_biosh < cf/boot.lst | grep -E '(BIOS_H|BOOT_|FAT16_|endif)' >  cf/lib/boot.h
	 
cf/lib/bios.h: sym_to_biosh cf/bios.c hex_to_cf
	emu2 MCF/CCF.COM 'cf/bios.c' -fopa -- MCDIR='C:\MCF'
	emu2 MCF/ASMCF.EXE 'cf/bios.asm' -fs -- MCDIR='C:\MCF'
	./sym_to_biosh < cf/bios.lst > cf/lib/bios.h
	./hex_to_cf cf/bios.hex cf/bios.cf F000 0000 F000

cf/bios.hex: cf/lib/bios.h 

.PHONY: disk/HELLO.CF
disk/HELLO.CF: cf/hello.c
	emu2 MCF/CCF.COM 'cf/hello.c' -fopl -- MCDIR='C:\MCF'
	./hex_to_cf cf/hello.hex disk/HELLO.CF 0000 0000 1000

.PHONY: disk/COMMAND.CF
disk/COMMAND.CF: cf/gpio.c
	emu2 MCF/CCF.COM 'cf/gpio.c' -fopl -- MCDIR='C:\MCF'
	./hex_to_cf cf/gpio.hex disk/COMMAND.CF 0000 0000 1000

.PHONY: disk/DEMO.CF
disk/DEMO.CF: cf/demo.c
	emu2 MCF/CCF.COM 'cf/demo.c' -fopl -- MCDIR='C:\MCF'
	./hex_to_cf cf/demo.hex disk/DEMO.CF 0000 0000 1000

diskfiles: disk/COMMAND.CF disk/DEMO.CF disk/HELLO.CF

# Build the disk.fs file system image with the bootloader any files in disk/* end up in the disk image
.PHONY: populate_fs
populate_fs: boot.bin patch_fs diskfiles cf/lib/boot.h
	rm -f disk.fs
	truncate --size 32M disk.fs
	mkfs.fat -F 16 -R 136 disk.fs
	mcopy -i disk.fs disk/* ::/
	./patch_fs disk.fs boot.bin

.PHONY: spi.vcd
spi.vcd:
	sigrok-cli -d fx2lafw --config samplerate=24m --samples=50M -O vcd -o spi.vcd

clean:
	rm -rf *.bin *.vvp *.vcd *.pass *.log lds lds.hex boot_hex_to_rom boot_test_sim.hex cf/lib/boot.h
	rm -rf *.mi hex_to_cf patch_fs disk.fs sym_to_biosh cf/*.hex cf/*.lst cf/*.asm cf/lib/bios.h cf/*.cf *.fst *.vcd
