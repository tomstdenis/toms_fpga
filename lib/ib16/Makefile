all: test_ib16_v2.pass

mon.s.bin: app/mon.s ib16_as
	./ib16_as app/mon.s --bin mon.s.bin --list mon.s.lst

test_ib16_v2.pass: ib16_v2.v ib16_v2_tb.v ecp5_demo.s.bin boot_rom.s.bin boot_rom_ecp5.s.bin
	verilator -DSIM --lint-only ib16_v2.v ib16_v2_tb.v
	iverilog -DSIM -Wall -o sim.vvp ib16_v2.v ib16_v2_tb.v
	(vvp sim.vvp -fst > $@.log && touch $@) || cat $@.log

ecp5_demo.s.bin: ecp5_demo.s ecp5_demo.s ib16_as
# 8KB version
#	cpp -DIRQ_VECTOR=0x1E00 -DDEMO_PROG_SIZE=3968 ecp5_demo.s | grep -v \^# > /tmp/ecp5_demo.s 
#	./ib16_as --define DEMO_ORG 0x0000 --define IRQ_VECTOR 0x1E00 --define DEMO_PROG_SIZE 0x0F80 ecp5_demo.s --bin ecp5_demo.s.bin --list ecp5_demo.s.lst
# 32KB version
#	./ib16_as --define DEMO_ORG 0x0000 --define IRQ_VECTOR 0x7E00 --define DEMO_PROG_SIZE 0x3F80 ecp5_demo.s --bin ecp5_demo.s.bin --list ecp5_demo.s.lst --hex ecp5_demo.s.hex --mon ecp5_demo.s.mon
# 58KB version for primer25k/ecp5
	./ib16_as --define DEMO_ORG 0x0000 --define IRQ_VECTOR 0xE600 --define DEMO_PROG_SIZE 0x7380 ecp5_demo.s --bin ecp5_demo.s.bin --list ecp5_demo.s.lst --hex ecp5_demo.s.hex --mon ecp5_demo.s.mon

boot_rom.s.bin: boot_rom.s ib16_as
	./ib16_as boot_rom.s --bin boot_rom.s.bin --list boot_rom.s.lst --rom boot_rom.s.rom --hex boot_rom_s.hex

boot_rom_p25k.s.bin: boot_rom_p25k.s ib16_as
	./ib16_as boot_rom_p25k.s --bin boot_rom_p25k.s.bin --rom boot_rom_p25k.s.rom --list boot_rom_p25k.s.lst --hex boot_rom_p25k.s.hex

boot_rom_ecp5.s.bin: boot_rom_ecp5.s ib16_as
	./ib16_as boot_rom_ecp5.s --bin boot_rom_ecp5.s.bin --rom boot_rom_ecp5.s.rom --list boot_rom_ecp5.s.lst --hex boot_rom_ecp5.s.hex

nano1k_demo.s.bin: nano1k_demo.s ib16_as
	./ib16_as nano1k_demo.s --bin nano1k_demo.s.bin --list nano1k_demo.s.lst

ib16_as: ib16_as.c
	gcc -O3 -Wall ib16_as.c -o ib16_as

upload: upload.c
	gcc -O0 -Wall upload.c -o upload

upload_p25k: upload_p25k.c
	gcc -O0 -Wall upload_p25k.c -o upload_p25k

clean:
	rm -f *.vvp *.vcd *.pass *.log ib16_as *.hex *.bin upload upload_p25k *.s.lst *.s.rom  *.s.mon
