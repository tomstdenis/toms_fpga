; uint16_t lrgGetOfs(uint8_t x, uint8_t y);
;

.ALIGN 0x10
:lrgGetOfs
.IREG x_pos
.IREG y_pos
.REG ytab_hi
.REG ytab_lo
.REG ret_hi
.REG ret_lo
.PUSHREGS
	
	LDI ytab_hi,<lrgYTAB			; load address of YTAB which basically does y*48 => 16-bit
	LDI ytab_lo,>lrgYTAB
	ADD ret_hi,y_pos,y_pos			; double y
	ADD ytab_lo,ytab_lo,ret_hi		; add y to the YTAB index
	ADC ytab_hi,ytab_hi,0			; carry
	LDM ret_lo,ytab_hi,ytab_lo		; load low byte  
	INC ytab_lo,ytab_lo				; advance to next byte
	ADC ytab_hi,ytab_hi,0			; increment byte
	LDM ret_hi,ytab_hi,ytab_lo		; now ret_hi:ret_lo == vid_mem + y * 48
	ADD ret_lo,ret_lo,x_pos			; add x_pos in
	ADC ret_hi,ret_hi,0				; carry
	
	MOV x_pos,ret_hi
	MOV y_pos,ret_lo
	
.POPREGS
	RET
	
; table of 0xE800 + y * 48
:lrgYTAB
	.DW 0xE800
	.DW 0xE830
	.DW 0xE860
	.DW 0xE890
	.DW 0xE8C0
	.DW 0xE8F0
	.DW 0xE920
	.DW 0xE950
	.DW 0xE980
	.DW 0xE9B0
	.DW 0xE9E0
	.DW 0xEA10
	.DW 0xEA40
	.DW 0xEA70
	.DW 0xEAA0
	.DW 0xEAD0
	.DW 0xEB00
	.DW 0xEB30
	.DW 0xEB60
	.DW 0xEB90
	.DW 0xEBC0
	.DW 0xEBF0
	.DW 0xEC20
	.DW 0xEC50
	.DW 0xEC80
	.DW 0xECB0
	.DW 0xECE0
	.DW 0xED10
	.DW 0xED40
	.DW 0xED70
	.DW 0xEDA0
	.DW 0xEDD0
	.DW 0xEE00
	.DW 0xEE30
	.DW 0xEE60
	.DW 0xEE90
	.DW 0xEEC0
	.DW 0xEEF0
	.DW 0xEF20
	.DW 0xEF50
