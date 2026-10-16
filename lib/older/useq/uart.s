; UART demo for 27MHz using 115.2K baud meaning each bit lasts 234.4 cycles 
; We use a variety of LDI/CLR/SETB/LSR/LD/ST to set the output bit
; to make sure we're covering more of the opcodes

; boot loadable apps start at 0x50 and we only want from 0x50..0xFFF in the bin file
.ORG 50
.BIN_START 50

.EQU BIT_COUNTER E2		; This is the freewheeling delay after sending a pulse
.EQU INNER_COUNTER CA   ; This is the same delay but accounting for the overhead in the BITS loop
.EQU RX_BITCOUNTER A9   ; Half of a 1.5 length pulse

	LDI FF
	OUT					; Make all pins inputs
	LDIR0 08			; R0 = 001_000 so we output on pin 0, and RX on pin 1
:MAIN
	; figure out which message to print
	LDIR13 >TXTSEL
	LDIR14 <TXTSEL
	LDM
	PUSHA				; save it
	EORI 1				; flip bit for next pass
	LDIR11 >TXTSEL
	LDIR12 <TXTSEL
	STM					; store it
	
	; now figure out which pointer to use
	LDIR13 >TXTPTRS		; load R14:R13 with pointer pointer table
	LDIR14 <TXTPTRS
	POPA				; load TXTSEL
	LDMIND				; now follow pointer table	
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

:RXCHAR
; Receive a char into A
; INPUT:
;   R0[5:3] - pin to read from
; OUTPUT:
;	A - Received byte
; Destroys:
;   R1, R2 - Temps
	CLR						; clear received bit
	ST 2					; save to R2
	LDIR1 8					; we will process 8 bits
	LDI RX_BITCOUNTER
	WAIT0					; wait for a START pulse
	WAITA
	WAITA					; we wait 1.5X into the first bit since 1.5X BIT_COUNTER > 256 we split it into two waits
:RXBITS
	LD 2					; load receive byte
	INBIT					; read a bit
	ROR						; rotate right so we can save the next bit
	ST 2
	LDI INNER_COUNTER
	WAITA					; wait till the next pulse
	LD 1					; load and decrement counter
	DEC
	ST 1					; save counter
	JNZ RXBITS
	LDI INNER_COUNTER		; wait for STOP pulse
	WAITA
	LD 2
	RET

; Transmit a char (internal subroutine...)
; INPUT:
;   A - Char to send
;   R0[2:0] - pin to write to
;
; Destroys:
;	 A
;    R[1] -> 0
;    R[2] -> 0 number of bits left
; CHAR to send is in A, R0[2:0] is set to the bit of o_port TX is on
:TXCHAR
	ST 1
	LDI 8
	ST 2   			; R[2] = bits to send
	CLR
	OUTBIT 			; Output A[0] which is 0, START bit (low)
	LDI BIT_COUNTER ; // 224 cycles to account for the 10 taken in the loop
	WAITA 			; Wait out the START bit

; bits (10 cycles + WAITA...)
:TXBITS
	LD 1  			; reload char to send
	OUTBIT 			; output bit A[0] to pin R[0][2:0]
	LSR   			; shift low
	ST 1  			; R[1] = shifted char to send
	LDI INNER_COUNTER ; delay for 115.2k baud
	WAITA 			; wait
	LD 2  			; bit count
	DEC   			; decrement
	ST 2  			; R[2] = bits left
	JNZ TXBITS

; STOP bit
	SETB 0,1		; Set bit 0 of A to 1 (STOP bit is a high)
	OUTBIT
	LDI BIT_COUNTER ; delay for 115.2k baud
	WAITA
	RET

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
	CALL TXCHAR
	JMP SENDSTR
:SENDSTRDONE
	RET


;TXT selector
:TXTSEL
.DB 01

:TXTPTRS			; pointer to text strings
.DB >HELLOTXT		; low byte
.DB <HELLOTXT		; high byte
.DB >WELCOMETXT
.DB <WELCOMETXT

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
:WELCOMETXT
.DB 57 ; W
.DB 65 ; e
.DB 6C ; l
.DB 63 ; c
.DB 6F ; o
.DB 6D ; m
.DB 65 ; e
.DB 2E ; .
.DB 0D ; CR
.DB 0A ; LF
.DB 00 ; NUL
