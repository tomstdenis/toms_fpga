MEMORY
{
    RAM (rwx)   : ORIGIN = 0x00000000, LENGTH = 128K
    FLASH (rx)  : ORIGIN = 0x00020000, LENGTH = 128K
}

SECTIONS
{
    .text :
    {
        _start = .;           /* Entry point symbol */
        *(.text.init)        /* Put reset/startup code first */
        *(.text .text.*)
        *(.rodata .rodata.*)
        . = ALIGN(4);
        _etext = .;          /* End of text */
    } > FLASH

    /* Global Pointer: Positioned 0x800 bytes into the data segment */
    /* to maximize the use of the 12-bit signed offset. */
    .data : 
    {
        . = ALIGN(16);
        __global_pointer$ = . + 0x800; 
        _sdata = .;          /* Start of data (for copying) */
        *(.data .data.*)
        *(.sdata .sdata.*)   /* Small data */
        . = ALIGN(4);
        _edata = .;          /* End of data */
    } > RAM AT > FLASH

    /* LMA (Load Address) of data for the startup copy loop */
    _sidata = LOADADDR(.data);

    .bss :
    {
        . = ALIGN(4);
        __bss_start = .;     /* Standard BSS start symbol */
        _sbss = .;           
        *(.bss .bss.*)
        *(.sbss .sbss.*)     /* Small BSS */
        *(COMMON)
        . = ALIGN(4);
        __bss_end = .;       /* Standard BSS end symbol */
        _ebss = .;
    } > RAM

    /* Define the end of allocated memory (useful for sbrk/heap) */
    _end = .;
}
