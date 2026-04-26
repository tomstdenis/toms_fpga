; library functions
.EQU UART_ADDR 0xFFFF

; Quickguide
; Typically things expect the UART in r15:r14 and user pointers in r13:r12
; Single values are passed in/returned via r1

; *** OUTPUT ***
; PrintHexByte: Prints 'r1' in hex to r15:r14
; PrintNewLine: Prints a \n\r to r15:r14
; PrintStr:     Prints a NUL terminated string pointed to by r13:r12 to r15:r14

; *** INPUT ***
; ReadHexByte:  Reads a hex byte (upper or lower case) from R15:R14 into r1
; ReadStr:		Reads a string (terminated by \r or \n) from R15:R14 into R13:R12, handles backspace(08) properly.
