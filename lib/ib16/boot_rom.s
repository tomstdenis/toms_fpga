; nano1k boot loader
.PROG_SIZE 0x20
.BIN_START 0x2000
.ORG 0x2000

.EQU UART_ADDR 0xFFFF   ; Blocking 8N1 230.4K baud UART

; ROM starts at 2000
LDI 14,>UART_ADDR		; R15:R14 points to UART
LDI 15,<UART_ADDR
LDI 0,0
LDI 1,0					; start writing to 0
LDI 4,0x5A				; magic constant we wait for before reading data bytes
:FLUSH
LDM 3,15,14
CMPEQ 3,4				; compare R3 to R4 (uart byte to 0x5A)
JNC FLUSH				; dump 
LDM 2,15,14				; load number of pages from UART

:LOOP
LDM 3,15,14				; read from UART
STM 3,15,14				; echo char back
STM 3,1,0				; store 
INC 0,0					; increment base
JNC LOOP
:ELOOP2					; this is where we test if there's another 256 byte page
INC 1,1					; increment page number
CMPEQ 1,2				; compare page number against page count
JNC LOOP2				; if we're not there we jump to the 2nd phase where we don't echo back anymore
						; if we get here we're done so we force r0 == 0 and then boot the user app at PC=0000
XOR 0,0,0				; ensure r0 is zero before boot using app
SRES 8					; boot user app
:LOOP2					; don't echo back for offset >= 256
LDM 3,15,14				; read from UART
STM 3,1,0				; store 
INC 0,0					; increment base
JNC LOOP2
JMP ELOOP2
