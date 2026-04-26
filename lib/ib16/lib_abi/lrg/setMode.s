; void lrgSetMode(uint8_t mode);
;

.EQU VIDEO_FLAG_ADDR 0xFFF8

.ALIGN 0x10
:lrgSetMode
.IREG mode
.REG vf_hi
.reg vf_lo
.PUSHREGS

	LDI vf_hi,<VIDEO_FLAG_ADDR
	LDI vf_lo,>VIDEO_FLAG_ADDR
	STM mode,vf_hi,vf_lo

.POPREGS
	RET
