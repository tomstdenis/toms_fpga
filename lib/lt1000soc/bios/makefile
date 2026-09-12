bios_lane0.vh: bios.bin
	@make -C ../tools
	@../tools/mkbioshex

bios.bin: bios.elf
	@size bios.elf
	@riscv32-unknown-elf-objcopy -O binary --pad-to=0x01002000 --gap-fill=0x00 bios.elf bios.bin

bios.elf: bios.c crt0.s bios.ld
	@riscv32-unknown-elf-gcc -march=rv32imc -mabi=ilp32 -Os --specs=picolibc.specs -nostartfiles -T bios.ld crt0.s bios.c -o bios.elf

clean:
	@rm -f bios.elf
