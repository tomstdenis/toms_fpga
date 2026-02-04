MEMORY
{
    /* Single 32KiB block of BRAM */
    BRAM (rwx) : ORIGIN = 0x00000000, LENGTH = 32K
}

SECTIONS
{
    /* 1. Code and Read-Only Data */
    .text :
    {
        . = ALIGN(4);
        _start = .;          
        *(.text.init)        /* Reset/startup code at address 0 */
        *(.text .text.*)
        *(.rodata .rodata.*)
        . = ALIGN(4);
        _etext = .;          
    } > BRAM

    /* 2. Initialized Data */
    /* Note: Since we load the whole 32K image to RAM, we don't need AT > FLASH */
    .data : 
    {
        . = ALIGN(16);
        /* Global Pointer positioned for 12-bit signed offset access */
        __global_pointer$ = . + 0x800; 
        _sdata = .;          
        *(.data .data.*)
        *(.sdata .sdata.*)   
        . = ALIGN(4);
        _edata = .;          
    } > BRAM

    /* 3. Uninitialized Data (Zeroed by startup code) */
    .bss :
    {
        . = ALIGN(4);
        _sbss = .;
        __bss_start = .;     
        *(.bss .bss.*)
        *(.sbss .sbss.*)     
        *(COMMON)
        . = ALIGN(4);
        _ebss = .;
        __bss_end = .;       
    } > BRAM

    /* 4. Define the Heap start and Stack end */
    . = ALIGN(4);
    _end = .;                /* End of BSS, start of heap */
    
    /* Optional: Define the Stack Top at the very end of our 32K.
       In your startup.s, you can do 'la sp, _stack_top'
    */
    _stack_top = ORIGIN(BRAM) + LENGTH(BRAM);
}
