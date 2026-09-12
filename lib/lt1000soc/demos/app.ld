MEMORY
{
    TCM   (rwx) : ORIGIN = 0x02000000, LENGTH = 64K
    PSRAM (rwx) : ORIGIN = 0x08000000, LENGTH = 16M
}

/* Define the stack pointer at the very top of 64KB TCM */
_stack_top = ORIGIN(TCM) + LENGTH(TCM);

SECTIONS
{
    .text : {
        KEEP(*crt0.o(.text .text.*))
        *(.text*)
        *(.rodata*)
    } > PSRAM

    .data : {
        *(.data*)
        
        /* Define __global_pointer$ in the middle of small data */
        . = ALIGN(4);
        PROVIDE(__global_pointer$ = . + 0x800);
        *(.sdata*)
    } > PSRAM

    .bss : {
        . = ALIGN(4);
        __bss_start = .;
        *(.sbss*)
        *(.bss*)
        *(COMMON)
        . = ALIGN(4);
        __bss_end = .;
    } > PSRAM

    _stack_top = ORIGIN(TCM) + LENGTH(TCM);
    __stack = _stack_top;
}
