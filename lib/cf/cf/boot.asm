	ORG $E200		* code starts after first sector
	LD #$FA00       * 512 bytes of stack
	TAS				* Set stack to top of memory
	CALL main
	JMP $F000
wait_us EQU *
		OUT 17	 * clear timer
?wait_us_top EQU *
		IN 17	 * read timer
		CMP 2,S			 * compare to us
		ULT				 * unsigned less than 
		SJNZ ?wait_us_top * wait till us passes
 RET
since_us EQU *
		IN 17			* read uS timer
		OUT 17			* clear the uS timer
 RET
wait_ms EQU *
?1 EQU *
 LD 2,S
 DEC
 ST 2,S
 INC
 JZ ?2
 LD #1000
 PUSHA
 CALL wait_us
 FREE 2
 JMP ?1
?2 EQU *
 RET
memset EQU *
?3 EQU *
 LD 2,S
 DEC
 ST 2,S
 INC
 JZ ?4
 LD 6,S
 TAI ;
 INC
 ST 6,S
 LD 4,S
 STB I
 JMP ?3
?4 EQU *
 RET
memcmp EQU *
?5 EQU *
 LD 2,S
 DEC
 ST 2,S
 INC
 JZ ?6
 LD 6,S
 TAI ;
 INC
 ST 6,S
 LD 4,S
 PUSHI
 TAI
 INC
 ST 4+2,S
 LDB [S+]
 CMPB I
 JNZ ?7
 LDB #1
 JMP ?8
?7 EQU *
 JMP ?5
?6 EQU *
 CLR
?8 EQU *
 RET
memcpy EQU *
?9 EQU *
 LD 2,S
 DEC
 ST 2,S
 INC
 JZ ?10
 LD 6,S
 TAI ;
 INC
 ST 6,S
 LD 4,S
 PUSHI
 TAI
 INC
 ST 4+2,S
 LDB I
 STB [S+]
 JMP ?9
?10 EQU *
 RET
putc EQU *
		JMP $F064
 RET
puts EQU *
		JMP $F069
 RET
sd_spi_setup EQU *
		JMP $F105
 RET
sd_spi_set_cs EQU *
		JMP $F10E
 RET
sd_spi_transfer EQU *
		JMP $F118
 RET
sd_spi_recv EQU *
		JMP $F13F
 RET
sd_init EQU *
		JMP $F148
 RET
sd_cmd EQU *
		JMP $F155
 RET
sd_read_block EQU *
		JMP $F1BD
 RET
sd_reset EQU *
		JMP $F205
 RET
sd_sector_op EQU *
		JMP $F38A
 RET
fat16_sc2dc EQU *
 LDI 4,S
 LEAI 22,I
 LD I
 ADD 2,S
 SUBB #2
?11 EQU *
 RET
fat16_c_to_s EQU *
 LDI 2,S
 LEAI 2,I
 PUSHI
 LDI 4,S
 LEAI 2,I
 PUSHI
 LDI 8,S
 LEAI 7,I
 LD [S+]
 SHL I
 PUSHA
 LDI 6,S
 LEAI I
 PUSHI
 LDI 10,S
 LEAI 9,I
 LD [S+]
 SHR I
 OR S+
 ST [S+]
 LDI 2,S
 LEAI I
 PUSHI
 LDI 4,S
 LEAI I
 PUSHI
 LDI 8,S
 LEAI 7,I
 LD [S+]
 SHL I
 ST [S+]
 RET
fat16_s_to_b EQU *
 LDI 2,S
 LEAI 2,I
 PUSHI
 LDI 4,S
 LEAI 2,I
 LD I
 SHL #9
 PUSHA
 LDI 6,S
 LEAI I
 LD I
 SHR #7
 OR S+
 ST [S+]
 LDI 2,S
 LEAI I
 PUSHI
 LDI 4,S
 LEAI I
 LD I
 SHL #9
 ST [S+]
 RET
fat16_b_to_s EQU *
 LDI 2,S
 LEAI I
 PUSHI
 LDI 4,S
 LEAI I
 LD I
 SHR #9
 PUSHA
 LDI 6,S
 LEAI 2,I
 LD I
 SHL #7
 OR S+
 ST [S+]
 LDI 2,S
 LEAI 2,I
 PUSHI
 LDI 4,S
 LEAI 2,I
 LD I
 SHR #9
 ST [S+]
 RET
fat16_add_16 EQU *
 LDI 4,S
 LEAI I
 LD I
 ADD 2,S
 ST I
 LDI 4,S
 LEAI 2,I
 PUSHI
 LDI 6,S
 LEAI I
 LD I
 CMP 4,S
 ULT
 ADD [S]
 ST [S+]
 RET
fat16_add_32 EQU *
 LDI 4,S
 LEAI I
 PUSHI
 LDI 4,S
 LEAI I
 LD [S]
 ADD I
 ST [S+]
 LDI 4,S
 LEAI 2,I
 PUSHI
 LDI 4,S
 LEAI 2,I
 PUSHI
 LDI 8,S
 LEAI I
 PUSHI
 LDI 8,S
 LEAI I
 LD [S+]
 CMP I
 ULT
 ADD [S+]
 ADD [S]
 ST [S+]
 RET
fat16_cmp_32 EQU *
 LDI 4,S
 LEAI 2,I
 PUSHI
 LDI 4,S
 LEAI 2,I
 LD [S+]
 CMP I
 UGT
 JZ ?12
 LDB #1
 JMP ?13
?12 EQU *
 LDI 4,S
 LEAI 2,I
 PUSHI
 LDI 4,S
 LEAI 2,I
 LD [S+]
 CMP I
 ULT
 JZ ?14
 LD #-1
 JMP ?13
?14 EQU *
 LDI 4,S
 LEAI I
 PUSHI
 LDI 4,S
 LEAI I
 LD [S+]
 CMP I
 UGT
 JZ ?15
 LDB #1
 JMP ?13
?15 EQU *
 LDI 4,S
 LEAI I
 PUSHI
 LDI 4,S
 LEAI I
 LD [S+]
 CMP I
 ULT
 JZ ?16
 LD #-1
 JMP ?13
?16 EQU *
 CLR
?13 EQU *
 RET
fat16_initvol ALLOC 4
 LD 8,S
 PUSHA
 CLR
 PUSHA
 LDB #42
 PUSHA
 CALL memset
 FREE 6
 LDI 8,S
 LEAI 24,I
 LD 6,S
 ST I
 LEAI 0+0,S
 PUSHI
 LEAI 2+2,S
 CLR
 ST I
 ST [S+]
 LEAI 0,S
 PUSHI
 LD 8,S
 PUSHA
 CLR
 PUSHA
 CALL sector_op
 FREE 6
 JZ ?17
 LDB #255
 JMP ?18
?17 EQU *
 LDI 8,S
 PUSHI
 LDI 8,S
 LEAI 13,I
 LDB I
 STB [S+]
 LDI 8,S
 LEAI 1,I
 PUSHI
 LDI 10,S
 LDB I
 SHL #9
 ST [S+]
 LDI 8,S
 LEAI 3,I
 CLR
 ST I
 LDI 8,S
 LEAI 11,I
 PUSHI
 LDI 8,S
 LEAI 16,I
 LDB I
 STB [S+]
 LDI 8,S
 LEAI 12,I
 PUSHI
 LDI 8,S
 LEAI 18,I
 LDB I
 SHL #8
 PUSHA
 LDI 10,S
 LEAI 17,I
 LD S+
 ORB I
 ST [S+]
 LDI 8,S
 LEAI 14,I
 PUSHI
 LDI 8,S
 LEAI 23,I
 LDB I
 SHL #8
 PUSHA
 LDI 10,S
 LEAI 22,I
 LD S+
 ORB I
 ST [S+]
 LDI 8,S
 LEAI 16,I
 PUSHI
 LDI 8,S
 LEAI 15,I
 LDB I
 SHL #8
 PUSHA
 LDI 10,S
 LEAI 14,I
 LD S+
 ORB I
 ST [S+]
 LDI 8,S
 LEAI 18,I
 PUSHI
 LDI 10,S
 LEAI 16,I
 PUSHI
 LDI 12,S
 LD [S+]
 DIVB I
 ST [S+]
 LDI 8,S
 LEAI 20,I
 PUSHI
 LDI 10,S
 LEAI 18,I
 PUSHI
 LDI 12,S
 LEAI 11,I
 PUSHI
 LDI 14,S
 LEAI 14,I
 PUSHI
 LDI 16,S
 LD [S+]
 DIVB I
 MULB [S+]
 ADD [S+]
 ST [S+]
 LDI 8,S
 LEAI 22,I
 PUSHI
 LDI 10,S
 LEAI 20,I
 PUSHI
 LDI 12,S
 LEAI 12,I
 LD I
 MULB #32
 DIV #512
 LDI 12,S
 DIVB I
 ADD [S+]
 ST [S+]
 LEAI 0+0,S
 PUSHI
 LDI 10,S
 LEAI 1,I
 LD I
 ST [S+]
?19 EQU *
 LEAI 0+0,S
 LD I
 CMPB #1
 JNZ ?20
 LDI 8,S
 LEAI 3,I
 LD I
 INC
 ST I
 LEAI 0+0,S
 LD I
 SHR #1
 ST I
 JMP ?19
?20 EQU *
 LDI 8,S
 LEAI 5,I
 PUSHI
 LDI 10,S
 LEAI 3,I
 LDB #16
 SUB I
 ST [S+]
 LDI 8,S
 LEAI 7,I
 PUSHI
 LDI 10,S
 LEAI 3,I
 LD I
 SUBB #9
 ST [S+]
 LDI 8,S
 LEAI 9,I
 PUSHI
 LDI 10,S
 LEAI 7,I
 LDB #16
 SUB I
 ST [S+]
 CLR
?18 EQU *
 FREE 4
 RET
fat16_n_c ALLOC 6
 LEAI 0+2,S
 CLR
 ST I
 LEAI 0+0,S
 PUSHI
 LDI 12,S
 LEAI 18,I
 LD I
 ST [S+]
 LD 10,S
 PUSHA
 LEAI 2,S
 PUSHI
 CALL fat16_c_to_s
 FREE 4
 LEAI 0,S
 PUSHI
 CALL fat16_s_to_b
 FREE 2
 LEAI 0,S
 PUSHI
 LD 10,S
 PUSHA
 CALL fat16_add_16
 FREE 4
 LEAI 0,S
 PUSHI
 LD 10,S
 PUSHA
 CALL fat16_add_16
 FREE 4
 LEAI 0+0,S
 LD I
 SHR #1
 ANDB #255
 ST 4,S
 LEAI 0,S
 PUSHI
 CALL fat16_b_to_s
 FREE 2
 LEAI 0,S
 PUSHI
 LDI 12,S
 LEAI 24,I
 LD I
 PUSHA
 CLR
 PUSHA
 CALL sector_op
 FREE 6
 LDI 10,S
 LEAI 24,I
 LD 4,S
 MULB #2
 LDI I
 ADAI
 LD I
?21 EQU *
 FREE 6
 RET
fat16_opendir ALLOC 4
 LD 6,S
 SJZ ?23
 LD 6,S
 SJMP ?22
?23 EQU *
 LDI 8,S
 LEAI 20,I
 LD I
?22 EQU *
 ST 6,S
 LDI 8,S
 LEAI 28,I
 LD 6,S
 ST I
 LDI 8,S
 LEAI 31,I
 CLR
 STB I
 LDI 8,S
 LEAI 30,I
 CLR
 STB I
 LEAI 0+2,S
 CLR
 ST I
 LEAI 0+0,S
 LD 6,S
 ST I
 LD 8,S
 PUSHA
 LEAI 2,S
 PUSHI
 CALL fat16_c_to_s
 FREE 4
 LEAI 0,S
 PUSHI
 LDI 10,S
 LEAI 24,I
 LD I
 PUSHA
 CLR
 PUSHA
 CALL sector_op
 FREE 6+4
 RET
fat16_nextdir ALLOC 4
?24 EQU *
 LDI 6,S
 LEAI 31,I
 LDB I
 CMPB #16
 ULT
 JZ ?25
 LDI 6,S
 LEAI 26,I
 PUSHI
 LDI 8,S
 LEAI 24,I
 PUSHI
 LDI 10,S
 LEAI 31,I
 LDB I
 INC
 STB I
 DEC
 MULB #32
 LDI [S+]
 ADAI
 TIA
 ST [S+]
 LDI 6,S
 LEAI 26,I
 LDI I
 LEAI I
 PUSHI
 LDI S+
 LEAI I
 LDB I
 CMPB #0
 JZ ?26
 LD #-1
 JMP ?27
?26 EQU *
 LDI 6,S
 LEAI 26,I
 LDI I
 LEAI I
 PUSHI
 LDI S+
 LEAI I
 LDB I
 CMPB #229
 JNZ ?24
?29 EQU *
?28 EQU *
 CLR
 JMP ?27
?25 EQU *
 LDI 6,S
 LEAI 30,I
 PUSHI
 LDI 8,S
 LDB I
 SUBB #1
 CMPB [S+]
 JZ ?30
 LDI 6,S
 LEAI 28,I
 PUSHI
 LD 8,S
 PUSHA
 LDI 10,S
 LEAI 28,I
 LD I
 PUSHA
 CALL fat16_n_c
 FREE 4
 ST [S+]
 LDI 6,S
 LEAI 28,I
 LD I
 CMP #-8
 UGE
 JZ ?31
 LD #-1
 JMP ?27
?31 EQU *
 LDI 6,S
 LEAI 30,I
 CLR
 STB I
 JMP ?32
?30 EQU *
 LDI 6,S
 LEAI 30,I
 LDB I
 INC
 STB I
?32 EQU *
 LEAI 0+2,S
 CLR
 ST I
 LEAI 0+0,S
 PUSHI
 LDI 8,S
 LEAI 28,I
 LD I
 ST [S+]
 LD 6,S
 PUSHA
 LEAI 2,S
 PUSHI
 CALL fat16_c_to_s
 FREE 4
 LEAI 0+0,S
 PUSHI
 LDI 8,S
 LEAI 30,I
 LD [S]
 ADDB I
 ST [S+]
 LEAI 0+0,S
 PUSHI
 LDI 8,S
 LEAI 30,I
 LD [S+]
 CMPB I
 ULT
 JZ ?33
 LEAI 0+2,S
 LD I
 INC
 ST I
?33 EQU *
 LEAI 0,S
 PUSHI
 LDI 8,S
 LEAI 24,I
 LD I
 PUSHA
 CLR
 PUSHA
 CALL sector_op
 FREE 6
 JMP ?24
?27 EQU *
 FREE 4
 RET
fat16_wpath ALLOC 30
 CLR
 ST 28,S
?34 EQU *
 LD 32,S
 TAI ;
 INC
 ST 32,S
 LDB I
 CMPB #47
 JNZ ?35
 LD #-1
 JMP ?36
?35 EQU *
 CLR
 ST 24,S
 LEAI 0,S
 PUSHI
 CLR
 PUSHA
 LDB #13
 PUSHA
 CALL memset
 FREE 6
?37 EQU *
 LDI 32,S
 LDB I
 CMPB #47
 NOT
 SJZ ?39
 LDI 32,S
 LDB I
 SJZ ?40
 LD 24,S
 CMPB #12
 ULT
?40 EQU *
?39 EQU *
 JZ ?38
 LD 24,S
 INC
 ST 24,S
 DEC
 LEAI 0,S
 ADAI
 LD 32,S
 PUSHI
 TAI
 INC
 ST 32+2,S
 LDB I
 STB [S+]
 JMP ?37
?38 EQU *
 LD 24,S
 CMPB #12
 SJZ ?42
 LDI 32,S
 LDB I
 SJZ ?43
 LDI 32,S
 LDB I
 CMPB #47
 NOT
?43 EQU *
?42 EQU *
 JZ ?41
 LD #-1
 JMP ?36
?41 EQU *
 LEAI 13,S
 PUSHI
 LDB #32
 PUSHA
 LDB #8
 PUSHA
 CALL memset
 FREE 6
 LEAI 21,S
 PUSHI
 LDB #32
 PUSHA
 LDB #3
 PUSHA
 CALL memset
 FREE 6
 CLR
 ST 26,S
 ST 24,S
?44 EQU *
 LD 24,S
 CMPB #8
 ULT
 SJZ ?46
 LD 26,S
 LEAI 0,S
 ADAI
 LDB I
 CMPB #46
 NOT
 SJZ ?47
 LD 26,S
 LEAI 0,S
 ADAI
 LDB I
?47 EQU *
?46 EQU *
 JZ ?45
 LD 24,S
 INC
 ST 24,S
 DEC
 LEAI 13,S
 ADAI
 PUSHI
 LD 28,S
 INC
 ST 28,S
 DEC
 LEAI 2,S
 ADAI
 LDB I
 STB [S+]
 JMP ?44
?45 EQU *
 LD 26,S
 LEAI 0,S
 ADAI
 LDB I
 CMPB #46
 JZ ?48
 CLR
 ST 24,S
 LD 26,S
 INC
 ST 26,S
?49 EQU *
 LD 24,S
 CMPB #3
 ULT
 SJZ ?51
 LD 26,S
 LEAI 0,S
 ADAI
 LDB I
?51 EQU *
 JZ ?50
 LD 24,S
 INC
 ST 24,S
 DEC
 LEAI 21,S
 ADAI
 PUSHI
 LD 28,S
 INC
 ST 28,S
 DEC
 LEAI 2,S
 ADAI
 LDB I
 STB [S+]
 JMP ?49
?50 EQU *
?48 EQU *
 LD 34,S
 PUSHA
 LD 30,S
 PUSHA
 CALL fat16_opendir
 FREE 4
?52 EQU *
 LD 34,S
 PUSHA
 CALL fat16_nextdir
 FREE 2
 JNZ ?53
 LEAI 13,S
 PUSHI
 LDI 36,S
 LEAI 26,I
 LDI I
 LEAI I
 PUSHI
 LDB #8
 PUSHA
 CALL memcmp
 FREE 6
 NOT
 SJZ ?55
 LEAI 21,S
 PUSHI
 LDI 36,S
 LEAI 26,I
 LDI I
 LEAI 8,I
 PUSHI
 LDB #3
 PUSHA
 CALL memcmp
 FREE 6
 NOT
?55 EQU *
 JZ ?54
 LDI 32,S
 LDB I
 CMPB #47
 JZ ?56
 LDI 34,S
 LEAI 26,I
 LDI I
 LEAI 11,I
 LDB I
 ANDB #16
 JZ ?57
 LD 34,S
 PUSHA
 LDI 36,S
 LEAI 26,I
 LDI I
 LEAI 27,I
 LDB I
 SHL #8
 LDI 36,S
 PUSHA
 LEAI 26,I
 LDI I
 LEAI 26,I
 LD S+
 ORB I
 PUSHA
 CALL fat16_sc2dc
 FREE 4
 ST 28,S
 JMP ?34
?57 EQU *
 LD #-1
 JMP ?36
?58 EQU *
 JMP ?59
?56 EQU *
 CLR
 JMP ?36
?59 EQU *
?54 EQU *
 JMP ?52
?53 EQU *
 LD #-1
?36 EQU *
 FREE 30
 RET
fat16_fopen EQU *
 LD 4,S
 PUSHA ;
 LD 4,S
 PUSHA
 CALL fat16_wpath
 FREE 4
 JNZ ?60
 LDI 4,S
 LEAI 32,I
 PUSHI
 LDI 6,S
 LEAI 26,I
 LDI I
 LEAI 27,I
 LDB I
 SHL #8
 LDI 6,S
 PUSHA
 LEAI 26,I
 LDI I
 LEAI 26,I
 LD S+
 ORB I
 ST [S+]
 LDI 4,S
 LEAI 34,I
 LEAI I
 PUSHI
 LDI 6,S
 LEAI 26,I
 LDI I
 LEAI 29,I
 LDB I
 SHL #8
 LDI 6,S
 PUSHA
 LEAI 26,I
 LDI I
 LEAI 28,I
 LD S+
 ORB I
 ST [S+]
 LDI 4,S
 LEAI 34,I
 LEAI 2,I
 PUSHI
 LDI 6,S
 LEAI 26,I
 LDI I
 LEAI 31,I
 LDB I
 SHL #8
 LDI 6,S
 PUSHA
 LEAI 26,I
 LDI I
 LEAI 30,I
 LD S+
 ORB I
 ST [S+]
 LDI 4,S
 LEAI 38,I
 LEAI I
 CLR
 ST I
 LDI 4,S
 LEAI 38,I
 LEAI 2,I
 CLR
 ST I
 CLR
 JMP ?61
?60 EQU *
 LD #-1
?61 EQU *
 RET
fat16_fread ALLOC 14
 CLR
 ST 0,S
 LEAI 2+0,S
 PUSHI
 LDI 22,S
 LEAI 38,I
 LEAI I
 LD I
 ST [S+]
 LEAI 2+2,S
 PUSHI
 LDI 22,S
 LEAI 38,I
 LEAI 2,I
 LD I
 ST [S+]
 LEAI 2,S
 PUSHI
 LD 18,S
 PUSHA
 CALL fat16_add_16
 FREE 4
 LDI 20,S
 LEAI 34,I
 PUSHI
 LEAI 4,S
 PUSHI
 CALL fat16_cmp_32
 FREE 4
 CMP #-1
 JZ ?62
 LDI 20,S
 LEAI 34,I
 LEAI I
 PUSHI
 LDI 22,S
 LEAI 38,I
 LEAI I
 LD [S+]
 SUB I
 ST 16,S
?62 EQU *
?63 EQU *
 LD 16,S
 JZ ?64
 LDI 20,S
 LEAI 38,I
 LEAI I
 LD I
 AND #511
 ST 8,S
 LD 16,S
 ADD 8,S
 CMP #512
 UGT
 JZ ?65
 LD #512
 SUB 8,S
 ST 6,S
 JMP ?66
?65 EQU *
 LD 16,S
 ST 6,S
?66 EQU *
 LDI 20,S
 LEAI 38,I
 LEAI I
 PUSHI
 LDI 22,S
 LEAI 3,I
 LD [S+]
 SHR I
 LDI 20,S
 PUSHA
 LEAI 38,I
 LEAI 2,I
 PUSHI
 LDI 24,S
 LEAI 5,I
 LD [S+]
 SHL I
 OR S+
 ST 10,S
 LDI 20,S
 LEAI 32,I
 LD I
 ST 12,S
?67 EQU *
 LD 10,S
 DEC
 ST 10,S
 INC
 JZ ?68
 LD 20,S
 PUSHA
 LD 14,S
 PUSHA
 CALL fat16_n_c
 FREE 4
 ST 12,S
 CMP #-8
 UGE
 JZ ?69
 LD 0,S
 JMP ?70
?69 EQU *
 JMP ?67
?68 EQU *
 LEAI 2+2,S
 CLR
 ST I
 LEAI 2+0,S
 PUSHI
 LD 22,S
 PUSHA
 LD 16,S
 PUSHA
 CALL fat16_sc2dc
 FREE 4
 ST [S+]
 LD 20,S
 PUSHA
 LEAI 4,S
 PUSHI
 CALL fat16_c_to_s
 FREE 4
 LEAI 2,S
 PUSHI
 LDI 22,S
 LEAI 38,I
 LEAI I
 LD I
 SHR #9
 LDI 22,S
 PUSHA
 LDB I
 SUBB #1
 AND S+
 PUSHA
 CALL fat16_add_16
 FREE 4
 LEAI 2,S
 PUSHI
 LDI 22,S
 LEAI 24,I
 LD I
 PUSHA
 CLR
 PUSHA
 CALL sector_op
 FREE 6
 LD 18,S
 PUSHA
 LDI 22,S
 LEAI 24,I
 LD I
 ADD 10,S
 PUSHA
 LD 10,S
 PUSHA
 CALL memcpy
 FREE 6
 LD 18,S
 ADD 6,S
 ST 18,S
 LD 16,S
 SUB 6,S
 ST 16,S
 LD 0,S
 ADD 6,S
 ST 0,S
 LDI 20,S
 LEAI 38,I
 PUSHI
 LD 8,S
 PUSHA
 CALL fat16_add_16
 FREE 4
 JMP ?63
?64 EQU *
 LD 0,S
?70 EQU *
 FREE 14
 RET
print_hex_byte EQU *
		JMP $F087
 RET
print_hex_word EQU *
		JMP $F09E
 RET
read_hex EQU *
		JMP $F0B2
 RET
getch EQU *
		IN 0
 RET
getc EQU *
?getc_top EQU *
		IN 0
		INC
		SJZ ?getc_top
		DEC
		TAI
		ANDB 65488
		SJZ ?getc_no_echo
		TIA
		OUT 0
?getc_no_echo EQU *
		TIA
 RET
sector_op EQU *
 LD 6,S
 PUSHA ;
 LD 6,S
 PUSHA
 CLR
 PUSHA
 CALL sd_sector_op
 FREE 6
 RET
main ALLOC 46
 LEAI 2,S
 TIA
 ST 0,S
 CALL sd_init
 CALL sd_reset
 JNZ ?71
 LD #?0+0
 PUSHA
 CALL puts
 FREE 2
 LD 0,S
 PUSHA
 LD #-1024
 PUSHA
 CALL fat16_initvol
 FREE 4
 JNZ ?72
 LD #?0+23
 PUSHA
 CALL puts
 FREE 2
 LD 0,S
 PUSHA
 LD #?0+49
 PUSHA
 CALL fat16_fopen
 FREE 4
 JNZ ?73
 LD #?0+61
 PUSHA
 CALL puts
 FREE 2
 LD 0,S
 PUSHA
 CLR
 PUSHA
 LD #-8192
 PUSHA
 CALL fat16_fread
 FREE 6
 ST 44,S
 LD #?0+84
 PUSHA
 CALL puts
 FREE 2
 LD 44,S
 PUSHA
 CALL print_hex_word
 FREE 2
 LD #?0+92
 PUSHA
 CALL puts
 FREE 2
				   LD $0			* load entry point
				   IJMP				* jump to it
 JMP ?74
?73 EQU *
 LD #?0+101
 PUSHA
 CALL puts
 FREE 2
 JMP ?75
?74 EQU *
 JMP ?76
?72 EQU *
 LD #?0+125
 PUSHA
 CALL puts
 FREE 2
 JMP ?75
?76 EQU *
 JMP ?77
?71 EQU *
 LD #?0+156
 PUSHA
 CALL puts
 FREE 2
?77 EQU *
?75 EQU *
 FREE 46
 RET
?0 FCB 66,76,58,32,73,110,105,116,105,110,103,32,70,65,84,49
 FCB 54,46,46,46,10,13,0,66,76,58,32,79,112,101,110,105
 FCB 110,103,32,47,67,79,77,77,65,78,68,46,67,70,13,10
 FCB 0,47,67,79,77,77,65,78,68,46,67,70,0,66,76,58
 FCB 32,82,101,97,100,105,110,103,32,99,111,110,116,101,110,116
 FCB 115,13,10,0,82,101,97,100,32,48,120,0,32,98,121,116
 FCB 101,115,13,10,0,67,79,77,77,65,78,68,46,67,70,32
 FCB 110,111,116,32,102,111,117,110,100,46,10,13,0,67,111,117
 FCB 108,100,32,110,111,116,32,105,110,105,116,32,70,65,84,49
 FCB 54,32,86,111,108,117,109,101,46,13,10,0,67,111,117,108
 FCB 100,32,110,111,116,32,105,110,105,116,32,83,68,32,99,97
 FCB 114,100,46,13,10,0
