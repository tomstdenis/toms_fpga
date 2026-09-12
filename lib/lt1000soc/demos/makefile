all: loader gfx_circle.bin gfx_wire.bin gfx_plasma.bin gfx_flatcube.bin gfx_breakout.bin gfx_breakout2.bin gfx_hblank.bin

loader: loader.c
	gcc loader.c -o loader

gfx_hblank.bin: gfx_hblank.c
	@riscv32-unknown-elf-gcc -march=rv32imc -mabi=ilp32 -Os -ffreestanding -nostartfiles -T app.ld crt0.s gfx_hblank.c -o gfx_hblank.elf
	@riscv32-unknown-elf-objcopy -O binary gfx_hblank.elf gfx_hblank.bin

gfx_breakout2.bin: gfx_breakout2.c
	@riscv32-unknown-elf-gcc -march=rv32imc -mabi=ilp32 -Os -ffreestanding -nostartfiles -T app.ld crt0.s gfx_breakout2.c -o gfx_breakout2.elf
	@riscv32-unknown-elf-objcopy -O binary gfx_breakout2.elf gfx_breakout2.bin

gfx_breakout.bin: gfx_breakout.c
	@riscv32-unknown-elf-gcc -march=rv32imc -mabi=ilp32 -Os -ffreestanding -nostartfiles -T app.ld crt0.s gfx_breakout.c -o gfx_breakout.elf
	@riscv32-unknown-elf-objcopy -O binary gfx_breakout.elf gfx_breakout.bin

gfx_flatcube.bin: gfx_flatcube.c
	@riscv32-unknown-elf-gcc -march=rv32imc -mabi=ilp32 -Os -ffreestanding -nostartfiles -T app.ld crt0.s gfx_flatcube.c -o gfx_flatcube.elf
	@riscv32-unknown-elf-objcopy -O binary gfx_flatcube.elf gfx_flatcube.bin

gfx_plasma.bin: gfx_plasma.c
	@riscv32-unknown-elf-gcc -march=rv32imc -mabi=ilp32 -Os -ffreestanding -nostartfiles -T app.ld crt0.s gfx_plasma.c -o gfx_plasma.elf
	@riscv32-unknown-elf-objcopy -O binary gfx_plasma.elf gfx_plasma.bin

gfx_wire.bin: gfx_wire.c
	@riscv32-unknown-elf-gcc -march=rv32imc -mabi=ilp32 -Os -ffreestanding -nostartfiles -T app.ld crt0.s gfx_wire.c -o gfx_wire.elf
	@riscv32-unknown-elf-objcopy -O binary gfx_wire.elf gfx_wire.bin

gfx_circle.bin: gfx_circle.c
	@riscv32-unknown-elf-gcc -march=rv32imc -mabi=ilp32 -Os -ffreestanding -nostartfiles -T app.ld crt0.s gfx_circle.c -o gfx_circle.elf
	@riscv32-unknown-elf-objcopy -O binary gfx_circle.elf gfx_circle.bin
	
clean:
	@rm -f *.bin *.elf loader
