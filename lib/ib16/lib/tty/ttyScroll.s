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

