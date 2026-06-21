all: test_cf.pass

test_cf.pass: cf.v cf_tb.v ../math/serial_divide.v
	verilator --lint-only cf.v cf_tb.v ../math/serial_divide.v
	iverilog -Wall -o sim.vvp cf.v cf_tb.v ../math/serial_divide.v
	(vvp sim.vvp -fst > $@.log && touch $@) || cat $@.log
	
boot_hex_to_rom: boot_hex_to_rom.c
	gcc boot_hex_to_rom.c -o boot_hex_to_rom
	
hex_to_cf: hex_to_cf.c
	gcc hex_to_cf.c -o hex_to_cf
	
patch_fs: patch_fs.c
	gcc patch_fs.c -o patch_fs

mon_p25.hex.mi: boot_hex_to_rom
	./boot_hex_to_rom < BIOS.HEX > mon_p25.hex.mi

boot.bin: hex_to_cf
	./hex_to_cf BOOT.HEX boot.bin E200 EFFF

.PHONY: populate_fs
populate_fs: boot.bin patch_fs
	rm -f disk.fs
	truncate --size 32M disk.fs
	mkfs.fat -F 16 disk.fs
	mkdir -p mnt_test
	sudo mount -o loop,uid=$$(id -u),gid=$$(id -g) disk.fs mnt_test
	cp disk/* mnt_test/
	sudo umount mnt_test
	rmdir mnt_test
	./patch_fs disk.fs boot.bin

clean:
	rm -rf *.bin *.vvp *.vcd *.pass *.log lds lds.hex boot_hex_to_rom boot_test_sim.hex *.mi hex_to_cf patch_fs disk.fs
