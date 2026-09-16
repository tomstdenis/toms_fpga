CFLAGS=-I../inc/ -march=rv32im -mabi=ilp32 -Os -ffreestanding -nostartfiles -T app.ld -ffunction-sections -fdata-sections
LDFLAGS= ../lib/lt1000.a  -Wl,--gc-sections

all: ../lib/lt1000.a loader gfx_circle.bin gfx_wire.bin gfx_plasma.bin gfx_flatcube.bin gfx_breakout.bin gfx_breakout2.bin gfx_hblank.bin spisd.bin mcfg.bin yield.bin

../lib/lt1000.a:
	make -C ../lib

loader: loader.c
	gcc loader.c -o loader

yield.bin: yield.c
	riscv32-unknown-elf-gcc ${CFLAGS} crt0.s yield.c ${LDFLAGS} -o yield.elf
	riscv32-unknown-elf-objcopy -O binary yield.elf yield.bin

mcfg.bin: mcfg.c
	riscv32-unknown-elf-gcc ${CFLAGS} crt0.s mcfg.c ${LDFLAGS} -o mcfg.elf
	riscv32-unknown-elf-objcopy -O binary mcfg.elf mcfg.bin

spisd.bin: spisd.c
	riscv32-unknown-elf-gcc ${CFLAGS} crt0.s spisd.c ${LDFLAGS} -o spisd.elf
	riscv32-unknown-elf-objcopy -O binary spisd.elf spisd.bin

gfx_hblank.bin: gfx_hblank.c
	riscv32-unknown-elf-gcc ${CFLAGS} crt0.s gfx_hblank.c ${LDFLAGS} -o gfx_hblank.elf
	riscv32-unknown-elf-objcopy -O binary gfx_hblank.elf gfx_hblank.bin

gfx_breakout2.bin: gfx_breakout2.c
	riscv32-unknown-elf-gcc ${CFLAGS} crt0.s gfx_breakout2.c ${LDFLAGS} -o gfx_breakout2.elf
	riscv32-unknown-elf-objcopy -O binary gfx_breakout2.elf gfx_breakout2.bin

gfx_breakout.bin: gfx_breakout.c
	riscv32-unknown-elf-gcc ${CFLAGS} crt0.s gfx_breakout.c ${LDFLAGS} -o gfx_breakout.elf
	riscv32-unknown-elf-objcopy -O binary gfx_breakout.elf gfx_breakout.bin

gfx_flatcube.bin: gfx_flatcube.c
	riscv32-unknown-elf-gcc ${CFLAGS} crt0.s gfx_flatcube.c ${LDFLAGS} -o gfx_flatcube.elf
	riscv32-unknown-elf-objcopy -O binary gfx_flatcube.elf gfx_flatcube.bin

gfx_plasma.bin: gfx_plasma.c
	riscv32-unknown-elf-gcc ${CFLAGS} crt0.s gfx_plasma.c ${LDFLAGS} -o gfx_plasma.elf
	riscv32-unknown-elf-objcopy -O binary gfx_plasma.elf gfx_plasma.bin

gfx_wire.bin: gfx_wire.c
	riscv32-unknown-elf-gcc ${CFLAGS} crt0.s gfx_wire.c ${LDFLAGS} -o gfx_wire.elf
	riscv32-unknown-elf-objcopy -O binary gfx_wire.elf gfx_wire.bin

gfx_circle.bin: gfx_circle.c
	riscv32-unknown-elf-gcc ${CFLAGS} crt0.s gfx_circle.c ${LDFLAGS} -o gfx_circle.elf
	riscv32-unknown-elf-objcopy -O binary gfx_circle.elf gfx_circle.bin
	
clean:
	rm -f *.bin *.elf loader
