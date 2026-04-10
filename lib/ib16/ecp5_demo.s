; Weird uart demo, note we kinda merge app/isr contexts because
; we want to read from the uart in app space.  In a "real" application
; you would either ignore the ISR completely or you'd only access the uart
; in ISR context and buffer it for the app context

.EQU GPIO0_ADDR 0xFFFB
.EQU GPIO1_ADDR 0xFFFA
.EQU TIMER_ADDR 0xFFF9
.PROG_SIZE DEMO_PROG_SIZE
.INC lib/tty/tty.s
.INC lib/uart/uart.s

.ORG IRQ_VECTOR		; IRQ vector
.INC ecp5_demo_isr.s

.ORG 0

; we boot with r0==0 guaranteed so keep it that way for this app

; Setup ISR context
	SRES 4						; switch to IRQ context
; Load R15:R14 with UART address
	LDI 14,>UART_ADDR
	LDI 15,<UART_ADDR
; load R12:R13 pointing to GPIO
	LDI 12,>GPIO0_ADDR
	LDI 13,<GPIO0_ADDR
	LDI 2,0x1B					; ESC key

; Setup App context
	SRES 0						; switch back to APP context
	LDI 14,>UART_ADDR			; we want to use the UART in app context too
	LDI 15,<UART_ADDR
	
; load R12:R13 pointing to GPIO
	LDI 12,>GPIO0_ADDR
	LDI 13,<GPIO0_ADDR

; load R10:R11 pointing to GPIO1
	LDI 10,>GPIO1_ADDR
	LDI 11,<GPIO1_ADDR

; R11:R11 pointing to the timer
	LDI 8,>TIMER_ADDR
	LDI 9,<TIMER_ADDR

; output counters
	LDI 6,0x00
	LDI 7,0x00			; our tick counter
	LDI 2,0x00
	
	LCALL ttyClear		; clear screen

; print welcome message
	PUSH 15
	PUSH 14
	LDI	14,>StrName
	LDI 15,<StrName
	LCALL ttyPuts			; print string
	POP 14
	POP 15

; read name into namestr buffer
	SRES 4				; mask the IRQ so we can read the UART here
	PUSH 13
	PUSH 12
	LDI	12,>NameStr
	LDI 13,<NameStr
	LCALL ttyGets			; Read a string into NameStr
	POP 12
	POP 13
	SRES 0
	
; print Hello
	LCALL ttyPrintCRNL		; print a newline first
	PUSH 15
	PUSH 14
	LDI	14,>StrNameHello
	LDI 15,<StrNameHello
	LCALL ttyPuts			; print string
	POP 14
	POP 15

; print string we read
	PUSH 15
	PUSH 14
	LDI	14,>NameStr
	LDI 15,<NameStr
	LCALL ttyPuts
	POP 14
	POP 15

; print rest of prompt
	PUSH 15
	PUSH 14
	LDI	14,>StrHello
	LDI 15,<StrHello
	LCALL ttyPuts
	POP 14
	POP 15

; let's read r7 from the UART
	SRES 4				; mask IRQ
	LCALL ReadHexByte
	LCALL PrintNewline
	PUSH 1				; save the read byte 
	SRES 0				; unask IRQs
	POP  7				; transfer r1 from IRQ context into app context r7

; main loop body
:LOOP
	; read timer to get the MSB and compare against the stored bit, we increment our tick only when it changes
	LDM 1,9,8			; read timer at r9:r8
	ADD 1,1,1			; get msb into carry
	ADC 1,0,0			; set r1 == carry + r0(0) + r0
	CMPEQ 1,2			; compare to stored value (we only move on if the MSB changed)
	JC LOOP				; loop if they're equal
	MOV 2,1				; r2 = r1
	INC 7,7				; increment tick (this changes every 2^23 cycles (about every 131.072ms at 64MHz)
	NOT 7,7				; invert it since the LEDs are inverted
	STM 7,11,10			; output to GPIO1
	NOT 7,7				; revert counter for next loop

	; print Counter message
	PUSH 15
	PUSH 14
	LDI	14,>StrCounter	; lower pointer
	LDI 15,<StrCounter  ; upper pointer
	LCALL ttyPuts
	POP 14
	POP 15

	; print counter and newline
	PUSH 1				; save r1
	MOV 1,7				; r1 = r7
	LCALL ttyPrintHex  ; print it in hex to the terminal
	LCALL ttyPrintCRNL
	POP 1				; restore r1

	JMP LOOP

; Strings
:StrName
.DS 'Please enter your name: '
:StrNameHello
.DS 'Hello '
:StrHello
.DS ', please enter a starting hex byte: '
:StrCounter
.DS 'Current counter value == '

; Buffers
:NameStr
.DUP 0x100


