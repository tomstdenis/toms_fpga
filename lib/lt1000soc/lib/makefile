CFLAGS=-I../inc/ -march=rv32im -mabi=ilp32 -Os -ffreestanding -nostartfiles -ffunction-sections -fdata-sections
CC=riscv32-unknown-elf-gcc
AR=riscv32-unknown-elf-ar

lt1000.a: sbrk.o serial.o sd.o string.o yield.o mem.o gfx.o
	${AR} rs lt1000.a *.o

.PHONY: clean
clean:
	rm -f *.o *.a
