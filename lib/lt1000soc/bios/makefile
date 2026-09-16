bios_lane0.vh: ../lib/lt1000.a bios.bin
	@make -C ../tools
	@../tools/mkbioshex

../lib/lt1000.a:
	@make -C ../lib

bios.bin: bios.elf
	@size bios.elf
	riscv32-unknown-elf-objcopy -O binary --pad-to=0x01002000 --gap-fill=0x00 bios.elf bios.bin

bios.elf: bios.c crt0.s bios.ld
	riscv32-unknown-elf-gcc -ffunction-sections -fdata-sections -Wl,--gc-sections -march=rv32im -mabi=ilp32 -Os -ffreestanding -nostartfiles -T bios.ld crt0.s bios.c -o bios.elf
	
clean:
	rm -f bios.elf
