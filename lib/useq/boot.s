; Simple boot loader, it reads 4096 - 80 bytes and then jumps to 0x50 
.ORG 00

.EQU BIT_COUNTER E2		; This is the freewheeling delay after sending a pulse
.EQU INNER_COUNTER CA   ; This is the same delay but accounting for the overhead in the BITS loop
.EQU RX_BITCOUNTER 97   ; Half of a 1.5 length pulse

:BOOT
	LDIR11 >APP
	LDIR12 <APP			; set pointer to start of app
:BOOTLOOP
	CALL RXCHAR
	STM					; receive char and store it
	LDI 2E				; ascii period
	CALL TXCHAR
	LD B				; is R11:R12 zero?
	OR C				;
	JNZ BOOTLOOP
	JMP APP

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
	WAITA					; we wait 1.5X into the first bit
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
;   R1 - Char to send
;   R0[2:0] - pin to write to
;
; Destroys:
;	 A
;    R[1] -> 0
;    R[2] -> 0 number of bits left
; CHAR to send is in A, R0[2:0] is set to the bit of o_port TX is on
:TXCHAR
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

.ORG 50
:APP
