all: loader gfx_circle.bin

loader: loader.c
	gcc loader.c -o loader

gfx_circle.bin: gfx_circle.c app.ld
	@riscv32-unknown-elf-gcc -march=rv32imc -mabi=ilp32 -Os -ffreestanding -nostartfiles -T app.ld crt0.s gfx_circle.c -o gfx_circle.elf
	@riscv32-unknown-elf-objcopy -O binary gfx_circle.elf gfx_circle.bin
	
clean:
	@rm -f *.bin *.elf loader
