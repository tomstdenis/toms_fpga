; Weird uart demo, note we kinda merge app/isr contexts because
; we want to read from the uart in app space.  In a "real" application
; you would either ignore the ISR completely or you'd only access the uart
; in ISR context and buffer it for the app context
.EQU GPIO0_ADDR 0xFFFB
.EQU GPIO1_ADDR 0xFFFA
.EQU INT_ADDR 0xFFFC
.EQU INTEN_ADDR 0xFFFD
.PROG_SIZE DEMO_PROG_SIZE
.INC lib/tty/tty.s
.INC lib/uart/uart.s

.ORG IRQ_VECTOR		; IRQ vector
.INC ecp5_demo_isr.s

.ORG 0

; switch to LRG mode and fill screen with colour
.EQU VMEM 0xE800
.EQU VSZ 0x800

	SRES 4

:TOP
	LDI 1,1					; set LRG mode
	LCALL lrgSetMode
	
	LDI 2,0
	LDI 15,<VMEM
	LDI 14,>VMEM
	LDI 13,<VSZ
	LDI 12,>VSZ
	LDI 11,0x30
:TL
	STM 2,15,14
    INC 2,2
	INC 14,14
	ADC 15,15,0
	DEC 12,12
	JNZ TL
	DEC 13,13
	JNZ TL
		
	; now draw a white diagonal line
	LDI 1,>VMEM
	LDI 2,<VMEM
	LDI 3,0xFF
	LDI 4,0x28
	LDI 5,0x31
:DL
	STM 3,2,1
	ADD 1,1,5
	ADC 2,2,0
	DEC 4,4
	JNZ DL
	
	SRES 10 ; jump to boot loader
	
	; wait 5 seconds, switch to text mode, wait 5 seconds
	LDI 1,5
	LCALL timerWait
	LDI 1,0
	LCALL lrgSetMode
	LDI 1,5
	LCALL timerWait

; we boot with r0==0 guaranteed so keep it that way for this app

; Setup ISR context
	SRES 4						; switch to IRQ context
; Load R15:R14 with UART address
	LDI 14,>UART_ADDR
	LDI 15,<UART_ADDR
; 	
; load R12:R13 pointing to INT PENDING
	LDI 12,>INT_ADDR
	LDI 13,<INT_ADDR
	LDI 2,0x1B					; ESC key
	SRES 0						; switch back to APP context

; Setup App context
	LDI 14,>UART_ADDR			; we want to use the UART in app context too
	LDI 15,<UART_ADDR
	
; load R12:R13 pointing to GPIO
	LDI 12,>GPIO0_ADDR
	LDI 13,<GPIO0_ADDR

; load R10:R11 pointing to GPIO1
	LDI 10,>GPIO1_ADDR
	LDI 11,<GPIO1_ADDR

; Enable UART RX READY IRQ
	LDI 1,1				; enable RX ready int
	LCALL intEnable
	
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
	; wait 250ms
	LDI 1,0xFA			; 250
	LCALL timerDelay	; wait 250ms

	INC 7,7				; increment tick (every 10ms)
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


