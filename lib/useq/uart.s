; UART demo for 27MHz using 115.2K baud meaning each bit lasts 234.4 cycles 
; We use a variety of LDI/CLR/SETB/LSR/LD/ST to set the output bit
; to make sure we're covering more of the opcodes
.ORG 00

.EQU BIT_COUNTER E2		; This is the freewheeling delay after sending a pulse
.EQU INNER_COUNTER CA   ; This is the same delay but accounting for the overhead in the BITS loop

	LDIR0 0				; R0 = 0 so we output on pin 0
	LDI 1
	OUTBIT				; set line high for IDLE
:MAIN
	LDIR13 >HELLOTXT	; load R14:R13 with pointer to text
	LDIR14 <HELLOTXT
	CALL SENDSTR		; CALL SENDSTR

; let's insert a decent pause (this works out to ~34000 * 256 cycles... or about 322.4ms)
	LDIR1 FF			; R1 = FF, outer loop counter
:MAINLOOP1
	LDI FF				; inner loop counter
:MAINLOOP2
	WAITA				; Wait for A cycles, restoring A
	DEC					; Decrement A
	JNZ MAINLOOP2		; Enormous fucking delay....
	LD 1				; load outer counter	
	DEC					;
	ST 1				; store outer counter
	JNZ MAINLOOP1		; Loop outer

	; load first byte of string and increment it
	LDIR13 >HELLOTXT	; load R14:R13 with pointer to text
	LDIR14 <HELLOTXT
	LDM					; reads from memory pointed to by R14:R13 with post increment
	INC
	LDIR11 >HELLOTXT	; load R12:R11 with pointer to text
	LDIR12 <HELLOTXT
	STM					; writes to memory pointed to by R12:11 with post increment (this means you can memcpy with LDM/STM/LD/DEC/ST/JNZ sequence
	JMP MAIN 			; restart demo
	
:TXCHAR
; Transmit a char (internal subroutine...)
; INPUT:
;   R1 - Char to send
;   R0[2:0] - pin to write to
;
; Destroys:
;	 A
;    R[1] -> 0
;    R[2] -> 0 number of bits left
; CHAR to send is in A, R0[2:0] is set to the bit of o_port TX is on
	LDI 8
	ST 2   			; R[2] = bits to send

	CLR
	OUTBIT 			; Output A[0] which is 0, START bit (low)
	LDI BIT_COUNTER ; // 224 cycles to account for the 10 taken in the loop
	WAITA 			; Wait out the START bit

; bits (10 cycles + WAITA...)
:BITS
	LD 1  			; reload char to send
	OUTBIT 			; output bit A[0] to pin R[0][2:0]
	LSR   			; shift low
	ST 1  			; R[1] = shifted char to send
	LDI INNER_COUNTER ; delay for 115.2k baud
	WAITA 			; wait
	LD 2  			; bit count
	DEC   			; decrement
	ST 2  			; R[2] = bits left
	JNZ BITS

; STOP bit
	SETB 0,1		; Set bit 0 of A to 1 (STOP bit is a high)
	OUTBIT
	LDI BIT_COUNTER ; delay for 115.2k baud
	WAITA

:SENDSTR
; Function SENDSTR(R14:R13) -- Transmit a string
; INPUT:
;  R14:R13 - Pointer to string
;  R0[2:0] - pin to write to
;
; Destroys:
;   A, R[1..3, 13, 14]
;
	LDM				; A = ROM[R[14],R[13]], R14,R13 += 1
	JZ SENDSTRDONE ; If it's not NUL send it, otherwise return	
	ST 1			; R[1] == char to send
	JMP TXCHAR
:SENDSTRDONE
	RET


:HELLOTXTPTR		; pointer to HELLOTXT
.DB >HELLOTXT		; low byte
.DB <HELLOTXT		; high byte

.ORG 200
; DATA
; ----
:HELLOTXT
.DB 48 ; H
.DB 45 ; E
.DB 4C ; L
.DB 4C ; L
.DB 4F ; O
.DB 20 ; SP
.DB 57 ; W
.DB 4F ; O
.DB 52 ; R
.DB 4C ; L
.DB 44 ; D
.DB 21 ; !
.DB 0D ; CR
.DB 0A ; LF
.DB 00 ; NUL
