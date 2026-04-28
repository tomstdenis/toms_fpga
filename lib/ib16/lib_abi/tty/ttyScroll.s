; void ttyScroll(void)
;


.ALIGN 0x10
:ttyScroll
.REG txtmem_hi
.REG txtmem_lo
.REG txtmem2_hi
.REG txtmem2_lo
.REG txtscrollsize_hi
.REG txtscrollsize_lo
.REG tmp
.PUSHREGS
	
	; R15:R14 => start of memory (destination)
	; R13:R12 => next row (source)
	; R11:R10 => # of bytes to copy
	
	LDI txtmem_hi,<TXTMEM	; point to video memory
	LDI txtmem_lo,>TXTMEM
	LDI txtmem2_hi,<TXTMEM2	; point to the next line
	LDI txtmem2_lo,>TXTMEM2
	LDI txtscrollsize_hi,<TXTSCROLLSIZE
	LDI txtscrollsize_lo,>TXTSCROLLSIZE
:TXT_LOOP0
	; tmp = *txtmem2
	LDM tmp,txtmem2_hi,txtmem2_lo		; load byte
	; *txtmem = tmp
	STM tmp,txtmem_hi,txtmem_lo		; store byte
	; txtmem++;
	INC txtmem_lo,txtmem_lo		; increment r15:r14
	ADC txtmem_hi,txtmem_hi,0     ; carry
	; txtmem2++;
	INC txtmem2_lo,txtmem2_lo		; increment r13:r12
	ADC txtmem2_hi,txtmem2_hi,0		; carry
	; --textscroll_size;
	DEC txtscrollsize_lo,txtscrollsize_lo		; decrement r11:r10
	JNC TXT_NC3
	DEC txtscrollsize_hi,txtscrollsize_hi		; carry into r11
:TXT_NC3
	; if txtscrollsize != 0 then goto TXT_LOOP0
	OR tmp,txtscrollsize_hi,txtscrollsize_lo		; or r11:r10
	JNZ TXT_LOOP0	; loop if we still have bytes left
	; tmp = 0x20; // now we need to blank the bottom line
	LDI tmp,0x20		; store a space
	; txtscrollsize = 0x50;
	LDI txtscrollsize_hi,0x50		; 80 bytes
:TXT_LOOP1
	; *txtmem = 0x20;
	STM tmp,txtmem_hi,txtmem_lo		; store
	; ++txtmem;
	INC txtmem_lo,txtmem_lo		; increment r15:r15
	JNZ TXT_NC4
	INC txtmem_hi,txtmem_hi
:TXT_NC4
	; if --txtscrollsize then goto TXT_LOOP1
	DEC txtscrollsize_hi,txtscrollsize_hi		; decrement byte counter
	JNZ TXT_LOOP1

.POPREGS
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

