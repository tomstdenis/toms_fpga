CFLAGS=-I../inc/ -march=rv32im -mabi=ilp32 -Os -ffreestanding -nostartfiles
CC=riscv32-unknown-elf-gcc
AR=riscv32-unknown-elf-ar

lt1000.a: serial.o sd.o
	${AR} rs lt1000.a *.o

.PHONY: clean
clean:
	rm -f *.o *.a
