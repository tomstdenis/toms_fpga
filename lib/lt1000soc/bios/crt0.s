.section .text._start
.global _start
.type _start, @function

_start:
    /* 1. Initialize Stack Pointer to top of TCM (0x02008000) */
    la      sp, __stack_top

    /* 2. Option: Initialize Global Pointer if relaxed addressing is used */
    .option push
    .option norelax
    la      gp, __global_pointer$
    .option pop

    /* 3. Copy initialized data section (.data) from ROM to TCM */
    la      a0, __data_load_start
    la      a1, __data_start
    la      a2, __data_end
1:
    bgeu    a1, a2, 2f
    lw      t0, 0(a0)
    sw      t0, 0(a1)
    addi    a0, a0, 4
    addi    a1, a1, 4
    j       1b
2:

    /* 4. Zero out uninitialized data section (.bss) in TCM */
    la      a0, __bss_start
    la      a1, __bss_end
    li      t0, 0
3:
    bgeu    a0, a1, 4f
    sw      t0, 0(a0)
    addi    a0, a0, 4
    j       3b
4:

    /* 5. Jump to C/C++ entry point */
    tail    bios_main

.size _start, . - _start
