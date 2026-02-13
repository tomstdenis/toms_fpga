; UART demo for 27MHz using 115.2K baud meaning each bit lasts 234.4 cycles 
.ORG 00

.EQU BIT_COUNTER E0				; 224 + loop(10) cycles per bit send

:MAIN
	LDIR0 0				; R0 = 0 so we output on pin 0
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
;    R[3] -> 224, bit counter
; CHAR to send is in A, R0[2:0] is set to the bit of o_port TX is on
	LDI 7
	ST 2   			; R[2] = bits to send
	LDI BIT_COUNTER ; // 224 cycles to account for the 10 taken in the loop
	ST 3   			; R[3] = counter
	OUTBIT 			; Output A[0] which is 0, START bit (low)
	LD 3
	WAITA 			; Wait out the START bit

; bits (10 cycles + WAITA...)
:BITS
	LD 1  			; reload char to send
	OUTBIT 			; output bit A[0] to pin R[0][2:0]
	LSR   			; shift low
	ST 1  			; R[1] = shifted char to send
	LD 3  			; load counter
	WAITA 			; wait
	LD 2  			; bit count
	DEC   			; decrement
	ST 2  			; R[2] = bits left
	JNZ BITS

; STOP bit
	SBIT 0,1      	; A[0] = 1;
	OUTBIT
	LD 3 			; counter
	WAITA

:SENDSTR
; Function SENDSTR(R14) -- Transmit a string
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
