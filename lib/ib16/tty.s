; Functions

; ttyScroll(void) -- Scroll the screen
; ttyPutc(r1 = char to print)
; ttyPuts(r15:14 == NUL terminated string to print)
; ttyPrintCRL(void) -- Print a CR/LF pair
; ttyPrintHex(r1 == byte value to print)

; Simple TTY library
.EQU TXTMEM  0xE800				; start of text memory
.EQU TXTMEM2 0xE850				; start of 2nd line
.EQU TXTSCROLLSIZE 0x0780		; how many bytes to scroll

; print a HEX char in r1
.ALIGN 0x10
:ttyPrintHex
	PUSH 15
	PUSH 14
	PUSH 4
	PUSH 3
	PUSH 2
	PUSH 1
	SWAP 2,1		; r2 = r1 <<< 4
	LDI 3,0x0F		; r3 = 0x0f
	AND 2,2,3		; now r2 = input[7:4]
	AND 3,1,3		; r3 = input[3:0]
	LDI 4,0x0A
	CMPLT 2,4		; is first nibble below ten
	JNC PHEXFNA
	; less then 10 so add '0'
	LDI 4,0x30
	ADD 1,2,4			; r1 = r2 + '0'
	JMP PHEXNN
:PHEXFNA
	LDI 4,0x37		; 'A' - 10
	ADD 1,2,4		; r1 = r2 + 'A'
:PHEXNN
	LCALL ttyPutc	; print top nibble
	LDI 4,0x0A
	CMPLT 3,4		; is second nibble below ten
	JNC PHEXFNA2
	; less then 10 so add '0'
	LDI 4,0x30
	ADD 1,3,4			; r1 = r2 + '0'
	JMP PHEXNN2
:PHEXFNA2
	LDI 4,0x37		; 'A' - 10
	ADD 1,3,4		; r1 = r2 + 'A'
:PHEXNN2
	LCALL ttyPutc	; print top nibble
	POP 1
	POP 2
	POP 3
	POP 4
	POP 14
	POP 15
	RET
	

; Print a newline/cr
.ALIGN 0x10
:ttyPrintCRNL
	PUSH 1
	LDI 1,0x0A
	LCALL ttyPutc
	LDI 1,0x0D
	LCALL ttyPutc
	POP 1
	RET

; Put a string
.ALIGN 0x10
:ttyPuts
	PUSH 15
	PUSH 14
	PUSH 1
	
:TTYPUTSLOOP
	LDM 1,15,14
	JZ TTYPUTSEND
	LCALL ttyPutc
	INC 14,14
	ADC 15,15,0
	JMP TTYPUTSLOOP
:TTYPUTSEND
	POP 1
	POP 14
	POP 15
	RET

; Put a character including \n and \r
.ALIGN 0x10
:ttyPutc
	PUSH 15
	PUSH 14
	PUSH 13
	PUSH 12
	PUSH 11
	PUSH 10
	PUSH 4
	PUSH 3
	PUSH 2

	; load X, Y
	LDI 15,<TTY_XY
	LDI 14,>TTY_XY
	LDM 2,15,14		; load X
	INC 14,14
	LDM 3,15,14		; load Y
		
	; is the character a \r?
	LDI 4,0x0D		; \r
	CMPEQ 1,4
	JC PUTC_CR
	LDI 4,0x0A		; \n
	CMPEQ 1,4
	JC PUTC_NL
	; regular char
	; compute r13:r12 = TXTMEM + Y * 80 + X using the lookup table
	LDI 13,<TTY_YOFF	; r13:r12 points to the TTY_YOFF table
	LDI 12,>TTY_YOFF
	ADD 4,3,3		; double Y (since our lookup table has 2 bytes per entry)
	ADD 12,12,4		; add 2*Y 
	ADC 13,13,0     ; add carry to 13
	LDM 10,13,12	; r11:r10 == pointer to video memory
	INC 12,12
	LDM 11,13,12
	ADD 10,10,2		; add X to video address
	ADC 11,11,0		; carry
	STM 1,11,10		; store character to video memory
	INC 2,2			; increment X
	LDI 4,0x50		; compare to 80
	CMPEQ 2,4
	JNC PUTC_END	; not at end of line
	LDI 2,0x00		; zero X, now we're basically at PUTC_NL
:PUTC_NL			; newline	
	INC 3,3			; Y = Y + 1
	LDI 4,0x19		; compare to 25
	CMPEQ 3,4
	JNC PUTC_END		; Y < 25
	LDI 3,0x18		; force Y = 24
	LCALL ttyScroll ; scroll the screen
	JMP PUTC_END
:PUTC_CR			; carriage return
	; reset X
	LDI 2,0x00		; X = 0	
:PUTC_END
	; store X, Y
	STM 3,15,14
	DEC 14,14
	STM 2,15,14
	
	POP 2
	POP 3
	POP 4
	POP 10
	POP 11
	POP 12
	POP 13
	POP 14
	POP 15
	RET

; Scroll window
.ALIGN 0x10
:ttyScroll
	PUSH 15
	PUSH 14
	PUSH 13
	PUSH 12
	PUSH 11
	PUSH 10
	PUSH 1
	
	; R15:R14 => start of memory (destination)
	; R13:R12 => next row (source)
	; R11:R10 => # of bytes to copy
	
	LDI 15,<TXTMEM	; point to video memory
	LDI 14,>TXTMEM
	LDI 13,<TXTMEM2	; point to the next line
	LDI 12,>TXTMEM2
	LDI 11,<TXTSCROLLSIZE
	LDI 10,>TXTSCROLLSIZE
:TXT_LOOP0
	LDM 1,13,12		; load byte
	STM 1,15,14		; store byte
	INC 14,14		; increment r15:r14
	ADC 15,15,0     ; carry
	INC 12,12		; increment r13:r12
	ADC 13,13,0		; carry
	DEC 10,10		; decrement r11:r10
	JNC TXT_NC3
	DEC 11,11		; carry into r11
:TXT_NC3
	OR 1,10,11		; or r11:r10
	JNZ TXT_LOOP0	; loop if we still have bytes left
	; now we need to blank the bottom line
	LDI 1,0x20		; store a space
	LDI 13,0x50		; 80 bytes
:TXT_LOOP1
	STM 1,15,14		; store
	INC 14,14		; increment r15:r15
	JNZ TXT_NC4
	INC 15,15
:TXT_NC4
	DEC 13,13		; decrement byte counter
	JNZ TXT_LOOP1
	
	POP 1
	POP 10
	POP 11
	POP 12
	POP 13
	POP 14
	POP 15
	RET
	
; the X and Y byte, align 2 so we can always reliably increment one byte of the pointer to read/store Y
.ALIGN 0x02
:TTY_XY
.DW 0
:TTY_YOFF    ; stores 0xE800 + Y * 80
.DW 0xe800
.DW 0xe850
.DW 0xe8a0
.DW 0xe8f0
.DW 0xe940
.DW 0xe990
.DW 0xe9e0
.DW 0xea30
.DW 0xea80
.DW 0xead0
.DW 0xeb20
.DW 0xeb70
.DW 0xebc0
.DW 0xec10
.DW 0xec60
.DW 0xecb0
.DW 0xed00
.DW 0xed50
.DW 0xeda0
.DW 0xedf0
.DW 0xee40
.DW 0xee90
.DW 0xeee0
.DW 0xef30
.DW 0xef80

