; compute pixel offset into r15:r114, using x=r1,y=r2
.ALIGN 0x10
:lrgGetOfs ; r15:r14 == y(r2) * 48 + x(r1) + 0xE800
	PUSH 13
	PUSH 12
	
	LDI 13,<lrgYTAB
	LDI 12,>lrgYTAB
	ADD 15,2,2				; double y
	ADD 12,12,15			; add y to the YTAB index
	ADC 13,13,0				; carry
	LDM 14,13,12			; load low byte  
	INC 12,12
	ADC 13,13,0				; increment byte
	LDM 15,13,12			; now r15:r14 == vid_mem + y * 48
	ADD 14,14,1				; add r1=x in
	ADC 15,15,0				; carry
	
	POP 12
	POP 13
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
