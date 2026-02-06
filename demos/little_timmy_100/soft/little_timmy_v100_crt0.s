.section .text.init
.global _start

_start:
    # 1. Disable interrupts 
    # (Note: If your V1 FSM doesn't implement CSRs yet, 
    # you might need to comment this out to avoid an 'Illegal Instruction')
    # csrci mstatus, 8

    # 2. Initialize the Global Pointer (gp)
    .option push
    .option norelax
    la gp, __global_pointer$
    .option pop

    # 3. Initialize the Stack Pointer (sp)
    # Using the symbol from our linker script (top of 32KiB)
    la sp, _stack_top 

    # 4. Clear BSS (Zero out uninitialized variables)
    # This is critical so that global variables start at 0
    la a0, __bss_start
    la a1, __bss_end
    bgeu a0, a1, 2f
1:
    sw zero, (a0)
    addi a0, a0, 4
    bltu a0, a1, 1b
2:

    # 5. Copy .data from FLASH to RAM 
    # REMOVED: In our flat BRAM model, the UART loader already 
    # placed the .data section in its execution address.

    # 6. Call your C main function
    jal main

    # 7. Loop forever if main returns
loop:
    j loop
