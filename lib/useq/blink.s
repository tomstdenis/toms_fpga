.ORG 00
    LDIB F
	ST F	   ; Store A=0x0F in fifo
    LDIT F     ; load A with 0xFF
    ST F	   ; Store A=0xFF in fifo
    LD F       ; A should be equal to 0x0F now
    LD F       ; A should be equal to 0xFF now
:LOOP
    TGLBIT     ; toggle bit R1[2:0] of the output port, which on reset R1[2:0] == 0 so bit zero
    WAITA      ; A counts down to 0, then restores to 0xFF
    JNZ LOOP   ; A is 0xFF, so we jump back 1 to 16 bytes
