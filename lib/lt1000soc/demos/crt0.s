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

    /* 5. Copy TCM code payload from PSRAM (LMA) to TCM (VMA) */
    la t0, __tcm_code_start
    la t1, __tcm_code_end
    la t2, __tcm_code_load_start
tcm_copy_loop:
    bgeu t0, t1, tcm_copy_done
    lw t3, 0(t2)
    sw t3, 0(t0)
    addi t0, t0, 4
    addi t2, t2, 4
    j tcm_copy_loop
tcm_copy_done:

    /* 6. Jump to application main */
    jal ra, main

	/* 7. Jump to BIOS ROM */
    lui     t0, 0x01000
    jalr    ra, t0, 0
