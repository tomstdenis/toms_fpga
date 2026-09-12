.section .text
.global _start
.type _start, @function

_start:
    /* 1. Disable interrupts during startup (if applicable) */
    
    /* 2. Initialize Global Pointer (gp) for linker relaxation */
    .option push
    .option norelax
    la gp, __global_pointer$
    .option pop

    /* 3. Initialize Stack Pointer (sp) to top of TCM */
    la sp, __stack

    /* 4. Clear BSS section in PSRAM */
    la t0, __bss_start
    la t1, __bss_end
bss_clear_loop:
    bgeu t0, t1, bss_done
    sw zero, 0(t0)
    addi t0, t0, 4
    j bss_clear_loop

bss_done:
    /* 5. Jump to application main */
    jal ra, main

    /* 6. Infinite loop if main returns */
1:  j 1b
