; TomMon

; Simple commands all end with a cr and/or lf
; DXXXX[.YYYY]            -- dump from XXXX to YYYY by default it dumps from XXXX to XXXX+1
; EXXXX Y1[ Y2 Y3...]     -- Enter byte(s) at XXXX, optionally specify more bytes space delimited
; GXXXX                   -- Patch 0000..0001 to AJMP to XXXX, if XXXX == 0000 then it just jumps there (via boot app mode)
; R						  -- reboot into boot rom
;
; No real error handling, expects hex in upper case only
;
; The way 'G' works is if you're jumping to 0000 it calls SRES 8 and boots your app
; if you are not it patches 0000 to AJMP to your app this means if 0000 is used by your 
; app for code/data but isn't your boot entry point this will break things.
;
;
.PROG_SIZE 0x100				; only include this line if you're building a TomMon ROM, if you use this in your app comment this line out
.INC lib/uart/uart.s
.ALIGN 0x10
:TomMon
	LDI 0,0x00					; enforce r0 == 0x00 in case it was changed by accident
	LDI 15,<UART_ADDR			; setup pointer
	LDI 14,>UART_ADDR
	LDI 4,0x20					; r4 == SPC for later
:TomMonLoop
	LCALL PrintNewline
	LDI 1,0x2A					; *
	STM 1,15,14					; print *
	LDI 1,0x20					; SPC
	STM 1,15,14
	LDM 1,15,14					; read character
	STM 1,15,14					; echo char
	LDI 2,0x44					; 'D'
	CMPEQ 1,2
	JC TomMonDcmd
	LDI 2,0x45					; 'E'
	CMPEQ 1,2
	JC TomMonEcmd
	LDI 2,0x47					; 'G'
	CMPEQ 1,2
	JC TomMonGcmd
	LDI 2,0x52					; 'R'
	CMPEQ 1,2
	JC TomMonRcmd
	JMP TomMonLoop				; Not valid letter just jump to top
:TomMonDcmd						; Handle 'D' commands
	; user entered D so we're reading r8:r7 = XXXX and optionally r6:r5 == YYYY (defaults to XXXX+1 if not found)
	LCALL TomMonReadr8r7
	LDM 1,15,14					; read next char
	STM 1,15,14					; echo char
	LDI 2,0x2E					; '.'
	LDI 3,0x0F					; for seeing if we're on a 16-byte boundary later
	CMPEQ 1,2
	JC TomMonDreadY
	INC 5,7						; r5 = r7 + 1 (default YYYY == XXXX + 1)
	ADC 6,8,0					; carry into r6
	JMP TomMonDtop
:TomMonDreadY					; read YYYY
	LCALL ReadHexByte
	MOV 6,1						; r6 == top YYYY
	LCALL ReadHexByte
	MOV 5,1						; now r6:r5 == YYYY
:TomMonDtop						; top of 'D' command loop where we print the address + space
	; print XXXX in hex on a new line
	LCALL PrintNewline
	MOV 1,8
	LCALL PrintHexByte			; print top of XXXX
	MOV 1,7
	LCALL PrintHexByte			; print bottom of XXXX
	STM 4,15,14					; print SPC
:TomMonDloop					; 'D' command loop where we output bytes until the next address is a multiple of 16
	LDM 1,8,7					; load byte
	LCALL PrintHexByte
	STM 4,15,14					; print byte and space
	INC 7,7
	ADC 8,8,0					; increment r8:r7
	CMPEQ 7,5					; compare r5/r7
	JNC TomMonDnext
	CMPEQ 8,6					; compare r6/r8
	JC TomMonLoop				; we're done go to top
:TomMonDnext					; print the next byte
	; next byte, but first do we newline?
	AND 1,7,3					; r1 = r7 & 15
	JNZ TomMonDloop				; not a multiple of 16 so keep outputting
	JMP TomMonDtop				; multiple of 16 so go to next line and print address
:TomMonEcmd
	LCALL TomMonReadr8r7		; read XXXX into r8:r7
:TomMonEloop
	LDM 1,15,14					; load next char
	STM 1,15,14					; echo char
	CMPEQ 1,4					; is it a space?
	JNC TomMonLoop				; not space so go to top of loop
	LCALL ReadHexByte			; load byte into r1
	STM 1,8,7					; store byte
	INC 7,7						; increment r8:r7
	ADC 8,8,0
	JMP TomMonEloop
:TomMonGcmd
	LCALL TomMonReadr8r7		; get address in r8r7
	OR 1,8,7					; is it zero?
	JNZ TomMonGpatch			; patch the reset vector
	SRES 8						; Jump to user app at 0000 directly
:TomMonGpatch					; write AJMP 8,7 to 0x0000 which is 0x8087
	LDI 1,0x01
	LDI 2,0x87
	STM 2,0,0					; store 0x87 at 0000
	LDI 2,0x80
	STM 2,0,1					; store 0x80 at 0001
	SRES 8
:TomMonRcmd
	SRES 0x10					; jump to boot rom
.ALIGN 0x10
:TomMonReadr8r7
	LCALL ReadHexByte			; read hex byte into r1
	MOV 8,1						; store in r8
	LCALL ReadHexByte
	MOV 7,1						; now r8:r7 holds XXXX
	RET

