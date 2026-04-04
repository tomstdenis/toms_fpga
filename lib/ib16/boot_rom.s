; BOOT ROM for ittybitty using the nano1k demo design
.EQU UART_ADDR 0xFFFF   ; Blocking 8N1 230.4K baud UART

; ROM starts at F000
.ORG F000
.BIN_START F000
.PROG_SIZE 128
:REBOOT
LDI 14,>UART_ADDR		; R15:R14 points to UART
LDI 15,<UART_ADDR
LDI 0,0
LDI 1,0					; start writing to 0
LDI 2,0x1F				; number of 256 byte pages...
LDI 4,0x5A				; magic constant we wait for before reading data bytes
:FLUSH
LDM 3,15,14
CMPEQ 3,4				; compare R3 to R4 (uart byte to 0x5A)
JNC FLUSH				; dump 

:LOOP
LDM 3,15,14				; read from UART
STM 3,15,14				; echo char back
STM 3,1,0				; store 
INC 0,0					; increment base
JNC LOOP
INC 1,1
CMPEQ 1,2
JNC LOOP
SRES 8					; boot user app
