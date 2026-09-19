MEMORY
{
    TCM   (rwx) : ORIGIN = 0x02000000, LENGTH = 64K
    PSRAM (rwx) : ORIGIN = 0x08000000, LENGTH = 16M
}

SECTIONS
{
    /* Main executable code & constants in PSRAM */
    .text : {
        KEEP(*(.text ._start))
        *(.text*)
        *(.rodata*)
        *(.srodata*)
        . = ALIGN(4);
    } > PSRAM
    
    /* TCM Code ONLY (VMA=TCM, LMA=PSRAM) */
    .tcm_code ORIGIN(TCM) : {
        . = ALIGN(4);
        __tcm_code_start = .;
        *(.tcm_code*)
        . = ALIGN(4);
        __tcm_code_end = .;
    } > TCM AT > PSRAM

    __tcm_code_load_start = LOADADDR(.tcm_code);

    /* Force all RAM variables and constants into PSRAM */
    .data : {
        . = ALIGN(4);
        *(.data*)
        *(.sdata*)
        . = ALIGN(4);
        PROVIDE(__global_pointer$ = . + 0x800);
    } > PSRAM AT > PSRAM

    .bss : {
        . = ALIGN(4);
        __bss_start = .;
        *(.sbss*)
        *(.bss*)
        *(COMMON)
        . = ALIGN(4);
        __bss_end = .;

		/* Define symbols for Newlib heap */
        _end = .;
        __end__ = .;             /* Some newlib builds look for __end__ */
        PROVIDE(end = .);        /* Standard libc fallback */
    } > PSRAM

	/* Define top of PSRAM for the heap (16MB total from 0x08000000) */
    _heap_max = ORIGIN(PSRAM) + LENGTH(PSRAM);
    
    _stack_top = ORIGIN(TCM) + LENGTH(TCM);
    __stack = _stack_top;
}
