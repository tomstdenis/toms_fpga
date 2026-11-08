.section .text.init
.global _start

_start:
    # 1. Disable interrupts (safety first)
    csrci mstatus, 8

    # 2. Initialize the Global Pointer (gp)
    # The linker script provides the __global_pointer$ symbol
    .option push
    .option norelax
    la gp, __global_pointer$
    .option pop

    # 3. Initialize the Stack Pointer (sp)
    # We'll point it to the end of RAM (128KB)
    li sp, 0x20000 

    # 4. Clear BSS (Zero out uninitialized variables)
    la a0, __bss_start
    la a1, __bss_end
    bgeu a0, a1, 2f
1:
    sw zero, (a0)
    addi a0, a0, 4
    bltu a0, a1, 1b
2:

    # 5. Copy .data from FLASH to RAM
    # (Only needed if you have initialized global variables)
    la a0, _sdata    # Destination in RAM
    la a1, _edata    # End destination in RAM
    la a2, _sidata   # Source in FLASH
    bgeu a0, a1, 4f
3:
    lw t0, (a2)
    sw t0, (a0)
    addi a0, a0, 4
    addi a2, a2, 4
    bltu a0, a1, 3b
4:

    # 6. Call your C main function
    jal main

    # 7. Loop forever if main returns
loop:
    j loop
