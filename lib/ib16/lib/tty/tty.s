; Functions

; ttyClear(void) -- Clear Screen
; ttyScroll(void) -- Scroll the screen
; ttyMoveXY(r1 = x, r2 = y) -- move cursor (no bounds checking)
; ttyGetXY(r1 <= x, r2 <= y) -- retrieve cursor position

; ttyPutc(r1 = char to print)
; ttyPrintXY(r1 = x, r2 = y, r3 = char to print)
; ttyPuts(r15:14 == NUL terminated string to print)
; ttyPrintCRL(void) -- Print a CR/LF pair
; ttyPrintHex(r1 == byte value to print)

; Simple TTY library
.EQU TXTMEM  0xE800				; start of text memory
.EQU TXTMEM2 0xE850				; start of 2nd line
.EQU TXTSCROLLSIZE 0x0780		; how many bytes to scroll

