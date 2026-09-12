all: loader gfx_circle.bin gfx_wire.bin

loader: loader.c
	gcc loader.c -o loader

gfx_wire.bin: gfx_wire.c
	@riscv32-unknown-elf-gcc -march=rv32imc -mabi=ilp32 -O3 -ffreestanding -nostartfiles -T app.ld crt0.s gfx_wire.c -o gfx_wire.elf
	@riscv32-unknown-elf-objcopy -O binary gfx_wire.elf gfx_wire.bin

gfx_circle.bin: gfx_circle.c
	@riscv32-unknown-elf-gcc -march=rv32imc -mabi=ilp32 -O3 -ffreestanding -nostartfiles -T app.ld crt0.s gfx_circle.c -o gfx_circle.elf
	@riscv32-unknown-elf-objcopy -O binary gfx_circle.elf gfx_circle.bin
	
clean:
	@rm -f *.bin *.elf loader
