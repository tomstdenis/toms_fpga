CC      := riscv32-unknown-elf-gcc
OBJCOPY := riscv32-unknown-elf-objcopy

CFLAGS  := -I../inc/ -march=rv32im -mabi=ilp32 -Os -ffreestanding -nostartfiles -T app.ld -ffunction-sections -fdata-sections
# Force the linker to include all objects from lt1000.a and garbage-collect unused logic
LDFLAGS := -Wl,--whole-archive ../lib/lt1000.a -Wl,--no-whole-archive -Wl,--gc-sections

# Automatically find all C files except host/special binaries
RISCV_SRCS := $(filter-out loader.c, $(wildcard *.c))
BINS       := $(RISCV_SRCS:.c=.bin)

.PHONY: all clean

all: ../lib/lt1000.a loader $(BINS)

# Subdirectory library build
../lib/lt1000.a:
	$(MAKE) -C ../lib

# Native host tool build
loader: loader.c
	gcc $< -o $@

# Pattern rule for cross-compiled RISC-V binaries
%.bin: %.c crt0.s ../lib/lt1000.a
	$(CC) $(CFLAGS) crt0.s $< $(LDFLAGS) -o $*.elf
	$(OBJCOPY) -O binary $*.elf $@

clean:
	rm -f *.bin *.elf loader
