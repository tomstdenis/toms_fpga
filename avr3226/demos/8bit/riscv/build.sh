#example build
#set env first

# setup path to point to where you have riscv tools installed
export PATH=/opt/riscv:${PATH}

# build for a RISC32IM_zicsr processor, don't use any libc or start files, it's all bare bones!
riscv32-unknown-elf-gcc -march=rv32im_zicsr -Os -flto -ffreestanding -nostartfiles -T myriscv.ld mycrt0.s test.c -o test
# can also build compressed opcodes
riscv32-unknown-elf-gcc -march=rv32imc_zicsr -Os -flto -ffreestanding -nostartfiles -T myriscv.ld mycrt0.s test.c -o test_c
# convert to binary
#riscv32-unknown-elf-objcopy -O binary test ../emuflash.bin
riscv32-unknown-elf-objcopy -O binary test_c ../emuflash.bin
# resize to 128KB which is the standard flash size
truncate -s 128K ../emuflash.bin
