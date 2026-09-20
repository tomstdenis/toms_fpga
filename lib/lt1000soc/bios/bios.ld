OUTPUT_ARCH("riscv")
ENTRY(_start)

MEMORY
{
    ROM (rx)  : ORIGIN = 0x01000000, LENGTH = 8K
    TCM (rwx) : ORIGIN = 0x02000000, LENGTH = 64K
}

__stack_top = ORIGIN(TCM) + LENGTH(TCM);

SECTIONS
{
	.text : ALIGN(4) {
        KEEP(*(.text.init))          /* Pin startup code right at ORIGIN(ROM) */
        *(.text .text.*)             /* All other executable code */
        *(.rodata .rodata.*)         /* Read-only data / string literals */
        *(.srodata .srodata.*)
        . = ALIGN(4);
    } > ROM
    
    __data_load_start = LOADADDR(.data);

    .data : ALIGN(4) {
        __data_start = .;
        *(.data .data.*)
        *(.sdata .sdata.*)
        . = ALIGN(4);
        __data_end = .;
    } > TCM AT > ROM

    .bss (NOLOAD) : ALIGN(4) {
        __bss_start = .;
        *(.bss .bss.*)
        *(.sbss .sbss.*)
        *(COMMON)
        . = ALIGN(4);
        __bss_end = .;
    } > TCM

    /* Position GP in the middle of small data section in TCM */
    . = ALIGN(16);
    PROVIDE(__global_pointer$ = __data_start + 0x800);
}
