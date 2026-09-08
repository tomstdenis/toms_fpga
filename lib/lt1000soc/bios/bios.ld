OUTPUT_ARCH("riscv")
ENTRY(_start)

MEMORY
{
    ROM (rx)  : ORIGIN = 0x01000000, LENGTH = 8K
    TCM (rwx) : ORIGIN = 0x02000000, LENGTH = 32K
}

/* Define top of TCM for the stack: 0x02000000 + 32K */
__stack_top = ORIGIN(TCM) + LENGTH(TCM);

SECTIONS
{
    /* Code and read-only data live in ROM */
    .text : ALIGN(4) {
        *(.text._start)   /* Ensure _start is at the absolute top of ROM */
        *(.text .text.*)
        *(.rodata .rodata.*)
        *(.srodata .srodata.*)
    } > ROM

    /* Loaded initialization data: stored in ROM, copied to TCM at boot */
    .data : ALIGN(4) {
        __data_start = .;
        *(.data .data.*)
        *(.sdata .sdata.*)
        . = ALIGN(4);
        __data_end = .;
    } > TCM AT > ROM

    /* VMA/LMA symbols for .data initialization */
    __data_load_start = LOADADDR(.data);

    /* Uninitialized data resides in TCM */
    .bss (NOLOAD) : ALIGN(4) {
        __bss_start = .;
        *(.bss .bss.*)
        *(.sbss .sbss.*)
        *(COMMON)
        . = ALIGN(4);
        __bss_end = .;
    } > TCM

    /* Provide Global Pointer for small-data optimization */
    . = ALIGN(16);
    __global_pointer$ = . + 0x800;
}