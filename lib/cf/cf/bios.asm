	ORG $F000
topofbios EQU *
	LD #$F900
	TAS				* Set stack to top of memory
	CALL main
?halt EQU *
	SJMP ?halt
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
gets EQU *
		LDI 2,S				* INDEX = s
?gets_top EQU *
		CALL getc
		STB I				* store character
		CMPB #8				* compare to BS
		SJNZ ?gets_bs
		LDB I
		CMPB #10			* newline
		SJNZ ?gets_end
		LEAI 1,I			* increment I
		SJMP ?gets_top
?gets_bs EQU *
		LDB #$20			* echo a space
		OUT 0
		LDB #8				* and then move back
		OUT 0
		SJMP ?gets_top
?gets_end
		LEAI 1,I
		CLR
		STB I				* store NUL
 RET
putc EQU *
		LD 2,S
		OUT 0
 RET
puts EQU *
		LD 2,S
		TAI
?puts_top EQU *
		LDB I
		SJZ ?puts_end
		OUT 0
		LEAI 1,I
		SJMP ?puts_top
?puts_end EQU *
 RET
hexstr FCB 48,49,50,51,52,53,54,55,56,57,65
 FCB 66,67,68,69,70,0
print_hex_byte EQU *
		LDI #hexstr
		LD 2,S
		SHR #4
		ADAI
		LDB I
		OUT 0

		LDI #hexstr
		LD 2,S
		ANDB #15
		ADAI
		LDB I
		OUT 0
 RET
print_hex_word EQU *
		LD 2,S
		SHR #8
		PUSHA
		CALL print_hex_byte
		FREE 2
		LD 2,S
		ANDB #255
		PUSHA
		CALL print_hex_byte
 LDI S+
 RET
read_hex ALLOC 8
 LD 10,S
 ST 2,S
 CLR
 ST 0,S
?3 EQU *
 LD 2,S
 DEC
 ST 2,S
 INC
 JZ ?4
 CALL getc
 ST 4,S
 LD 0,S
 SHL #4
 ST 0,S
 CLR
 ST 6,S
?5 EQU *
 LD 6,S
 LDI #hexstr
 ADAI
 LDB I
 SJNZ ?7
 JMP ?6
?8 EQU *
 LD 6,S
 INC
 ST 6,S
 SJMP ?5
?7 EQU *
 LD 6,S
 LDI #hexstr
 ADAI
 LDB I
 CMP 4,S
 JZ ?9
 LD 0,S
 OR 6,S
 ST 0,S
 JMP ?6
?9 EQU *
 JMP ?8
?6 EQU *
 JMP ?3
?4 EQU *
 LD 0,S
?10 EQU *
 FREE 8
 RET
sd_spi_setup EQU *
		LDB #$0D					* CS | SCK | MOSI as outputs
		OUT (0+5)
		LDB #$0A					* make CS and MISO high
		OUT (0+1)
 RET
sd_spi_set_cs EQU *
		LD 2,S
		SHL #3
		OR #$F700
		OUT (0+1)
 RET
sd_spi_transfer EQU *
		LD 2,S
		FCB $EF				* R0 = out (what to send)
		LDB #8
		FCB $F0				* R1 = 8
		
?sd_spi_transfer_top EQU *
		FCB $F1				* A = R0
		FCB $F7				* R0 = R0 << 1
		SHR #5					* we want bit 7 of out to be in bit 2 (mosi) location
		ANDB #4					* mask mosi bit
		OR #$FA00				* enable SCK and MOSI output (also write SCK=0)
		OUT (0+1)			* write to PMOD0
		
		LD #$0100				* enable toggle of SCK pin
		IN (0+1)			* read PMOD0 and toggle SCK
		ANDB #2					* mask MISO bit
		SHR #1					* shift left
		FCB $F7				* add MISO bit to R0 (out)
		
		FCB $F6				* DEC R1 and store copy in ACC
		SJNZ ?sd_spi_transfer_top
		
		LD #$FE00				* SCK bit enable, write 0
		OUT (0+1)			* write to PMOD0
		
		FCB $F1				* A = R0 (which now has MISO shifted in and MOSI in the upper 8 bits)
		ANDB #255				* only keep bottom bits 
 RET
sd_spi_recv EQU *
 LDB #255
 PUSHA
 CALL sd_spi_transfer
 FREE 2
?11 EQU *
 RET
sd_init EQU *
 LDI #-46
 PUSHI
 LDI #-47
 CLR
 STB I
 STB [S+]
 JMP sd_spi_setup
sd_cmd ALLOC 4
 CALL sd_spi_recv
 CALL sd_spi_recv
 LD 12,S
 ADDB #64
 PUSHA
 CALL sd_spi_transfer
 FREE 2
 LD 10,S
 SHR #8
 PUSHA
 CALL sd_spi_transfer
 FREE 2
 LD 10,S
 ANDB #255
 PUSHA
 CALL sd_spi_transfer
 FREE 2
 LD 8,S
 SHR #8
 PUSHA
 CALL sd_spi_transfer
 FREE 2
 LD 8,S
 ANDB #255
 PUSHA
 CALL sd_spi_transfer
 FREE 2
 LD 6,S
 PUSHA
 CALL sd_spi_transfer
 FREE 2
 LD #256
 ST 0,S
?12 EQU *
 LD 0,S
 DEC
 ST 0,S
 INC
 JZ ?13
 CALL sd_spi_recv
 ST 2,S
 ANDB #128
 JNZ ?14
 LD 2,S
 JMP ?15
?14 EQU *
 JMP ?12
?13 EQU *
 LD #-1
?15 EQU *
 FREE 4
 RET
sd_read_block ALLOC 4
 LD #8192
 ST 0,S
?16 EQU *
 LD 0,S
 DEC
 ST 0,S
 INC
 JZ ?17
 CALL sd_spi_recv
 ST 2,S
 CMPB #254
 JZ ?18
 LD 6,S
 ST 0,S
?19 EQU *
 LD 0,S
 DEC
 ST 0,S
 INC
 JZ ?20
 LD 8,S
 TAI ;
 INC
 ST 8,S
 PUSHI
 CALL sd_spi_recv
 STB [S+]
 JMP ?19
?20 EQU *
 CALL sd_spi_recv
 CALL sd_spi_recv
 CLR
 JMP ?21
?18 EQU *
 JMP ?16
?17 EQU *
 LD #-1
?21 EQU *
 FREE 4
 RET
sd_reset ALLOC 22
 CLR
 ST 2,S
?22 EQU *
 LDI #-46
 PUSHI
 LDI #-47
 CLR
 STB I
 STB [S+]
 LD 2,S
 INC
 ST 2,S
 CMPB #16
 JZ ?23
 LD #-1
 JMP ?24
?23 EQU *
 LDB #1
 PUSHA
 CALL sd_spi_set_cs
 FREE 2
 LDB #10
 ST 0,S
?25 EQU *
 LD 0,S
 DEC
 ST 0,S
 INC
 JZ ?26
 CALL sd_spi_recv
 JMP ?25
?26 EQU *
 CLR
 PUSHA
 CALL sd_spi_set_cs
 FREE 2
 CLR
 PUSHA
 CLR
 PUSHA
 CLR
 PUSHA
 LDB #149
 PUSHA
 CALL sd_cmd
 FREE 8
 CMPB #1
 JZ ?22
?27 EQU *
 LDB #8
 PUSHA
 CLR
 PUSHA
 LD #426
 PUSHA
 LDB #135
 PUSHA
 CALL sd_cmd
 FREE 8
 CMPB #1
 JZ ?22
?28 EQU *
 CALL sd_spi_recv
 PUSHA
 CALL sd_spi_recv
 ADD S+
 PUSHA
 CALL sd_spi_recv
 ADD S+
 PUSHA
 CALL sd_spi_recv
 ADD S+
 CMPB #171
 JZ ?22
?29 EQU *
 LD #256
 ST 0,S
?30 EQU *
 LD 0,S
 DEC
 ST 0,S
 INC
 JZ ?31
 LDB #55
 PUSHA
 CLR
 PUSHA
 CLR
 PUSHA
 CLR
 PUSHA
 CALL sd_cmd
 FREE 8
 CMPB #1
 JZ ?22
?32 EQU *
 LDB #41
 PUSHA
 LD #16384
 PUSHA
 CLR
 PUSHA
 CLR
 PUSHA
 CALL sd_cmd
 FREE 8
 CMPB #0
 JNZ ?31
?33 EQU *
 JMP ?30
?31 EQU *
 LD 0,S
 JZ ?22
?34 EQU *
 LD #256
 ST 0,S
?35 EQU *
 LD 0,S
 DEC
 ST 0,S
 INC
 JZ ?36
 LDB #58
 PUSHA
 CLR
 PUSHA
 CLR
 PUSHA
 CLR
 PUSHA
 CALL sd_cmd
 FREE 8
 CMPB #0
 JZ ?22
?37 EQU *
 CALL sd_spi_recv
 ST 4,S
 CALL sd_spi_recv
 CALL sd_spi_recv
 CALL sd_spi_recv
 LD 4,S
 ANDB #128
 JZ ?38
 LDI #-46
 LD 4,S
 ANDB #64
 PUSHI
 SJZ ?40
 LDB #1
 SJMP ?39
?40 EQU *
 CLR
?39 EQU *
 STB [S+]
 JMP ?36
?38 EQU *
 JMP ?35
?36 EQU *
 LD 0,S
 JZ ?22
?41 EQU *
 LDI #-46
 LDB I
 JNZ ?42
 LDB #16
 PUSHA
 CLR
 PUSHA
 LD #512
 PUSHA
 CLR
 PUSHA
 CALL sd_cmd
 FREE 8
 CMPB #0
 JZ ?22
?43 EQU *
?42 EQU *
 LDB #9
 PUSHA
 CLR
 PUSHA
 CLR
 PUSHA
 CLR
 PUSHA
 CALL sd_cmd
 FREE 8
 CMPB #0
 JZ ?22
?44 EQU *
 LEAI 6,S
 PUSHI
 LDB #16
 PUSHA
 CALL sd_read_block
 FREE 4
 CMPB #0
 JZ ?22
?45 EQU *
 LDB #1
 PUSHA
 CALL sd_spi_set_cs
 FREE 2
 LDI #-45+0
 PUSHI
 LEAI 8+9,S
 LDB I
 SHL #10
 ST [S+]
 LDI #-45+2
 PUSHI
 LEAI 8+9,S
 LDB I
 SHR #6
 PUSHA
 LEAI 10+8,S
 LDB I
 SHL #2
 ORB S+
 PUSHA
 LEAI 10+7,S
 LDB I
 ANDB #63
 SHL #10
 OR S+
 ST [S+]
 LDI #-47
 LDB #1
 STB I
 CLR
?24 EQU *
 FREE 22
 RET
sd_sector_op ALLOC 6
 LD #-1
 ST 0,S
 CLR
 ST 2,S
?46 EQU *
 CLR
 PUSHA
 CALL sd_spi_set_cs
 FREE 2
 LDB #17
 PUSHA
 LDI 14,S
 LEAI 2,I
 LD I
 PUSHA
 LDI 16,S
 LEAI I
 LD I
 PUSHA
 CLR
 PUSHA
 CALL sd_cmd
 FREE 8
 CMPB #0
 JZ ?48
?47 EQU *
 LD 10,S
 PUSHA
 LD #512
 PUSHA
 CALL sd_read_block
 FREE 4
 CMPB #0
 JZ ?48
?49 EQU *
 CLR
 ST 0,S
?48 EQU *
 LDB #1
 PUSHA
 CALL sd_spi_set_cs
 FREE 2
 CALL sd_spi_recv
 CALL sd_spi_recv
 LD 0,S
 CMPB #0
 NOT
 SJZ ?51
 LD 2,S
 INC
 ST 2,S
 DEC
 CMPB #32
 ULT
?51 EQU *
 JZ ?50
 LDB #250
 PUSHA
 CALL wait_ms
 FREE 2
 JMP ?46
?50 EQU *
 LD 0,S
?52 EQU *
 FREE 6
 RET
inspect_mem ALLOC 6
 LDB #4
 PUSHA
 CALL read_hex
 FREE 2
 AND #-16
 ST 0,S
 ADD #256
 ST 2,S
 CALL getc
 CMPB #46
 JZ ?53
 LDB #4
 PUSHA
 CALL read_hex
 FREE 2
 ADD 0,S
 ST 2,S
?53 EQU *
 LD 2,S
 SUB 0,S
 ST 4,S
?54 EQU *
 LD 4,S
 DEC
 ST 4,S
 INC
 JZ ?55
 LD 0,S
 ANDB #15
 JNZ ?56
 LD #?0+0
 PUSHA
 CALL puts
 FREE 2
 LD 0,S
 PUSHA
 CALL print_hex_word
 FREE 2
 LD #?0+3
 PUSHA
 CALL puts
 FREE 2
?56 EQU *
 LD 0,S
 TAI ;
 INC
 ST 0,S
 LDB I
 PUSHA
 CALL print_hex_byte
 FREE 2
 LD #?0+4
 PUSHA
 CALL puts
 FREE 2
 JMP ?54
?55 EQU *
 FREE 6
 RET
enter_mem ALLOC 4
 LDB #4
 PUSHA
 CALL read_hex
 FREE 2
 ST 0,S
?57 EQU *
 CALL getc
 CMPB #32
 JZ ?58
 LDB #2
 PUSHA
 CALL read_hex
 FREE 2
 ST 2,S
 LD 0,S
 TAI ;
 INC
 ST 0,S
 LD 2,S
 STB I
 JMP ?57
?58 EQU *
 FREE 4
 RET
serial_upload ALLOC 10
 LDI #-48
 CLR
 STB I
?59 EQU *
 CALL getc
 ST 2,S
 CMPB #83
 JZ ?61
 CALL getc
 ST 0,S
 LDB #2
 PUSHA
 CALL read_hex
 FREE 2
 SUBB #3
 ST 6,S
 ST 8,S
 LDB #4
 PUSHA
 CALL read_hex
 FREE 2
 ST 4,S
?62 EQU *
 LD 6,S
 DEC
 ST 6,S
 INC
 JZ ?63
 LDB #2
 PUSHA
 CALL read_hex
 FREE 2
 ST 2,S
 LD 4,S
 TAI ;
 INC
 ST 4,S
 LD 2,S
 STB I
 JMP ?62
?63 EQU *
 CALL getc
 CALL getc
 LD 0,S
 CMPB #57
 SJZ ?65
 LD 8,S
 NOT
?65 EQU *
 JZ ?64
 LDB #100
 PUSHA
 CALL wait_ms
 FREE 2
?66 EQU *
 CALL getch
 ST 2,S
?67 EQU *
 LD 2,S
 CMPB #13
 SJNZ ?69
 LD 2,S
 CMPB #10
?69 EQU *
 JNZ ?66
?68 EQU *
 JMP ?70
?64 EQU *
?61 EQU *
 JMP ?59
?60 EQU *
?70 EQU *
 FREE 10
 RET
jump EQU *
		LD 2,S
		IJMP
 RET
main ALLOC 10
?71 EQU *
 CALL sd_init
 LD #?0+6
 PUSHA
 CALL puts
 FREE 2
 CALL sd_reset
 JNZ ?72
 LEAI 0+2,S
 CLR
 ST I
 LEAI 0+0,S
 CLR
 ST I
?73 EQU *
 LEAI 0+0,S
 LD I
 CMPB #8
 ULT
 SJNZ ?75
 JMP ?74
?76 EQU *
 LEAI 0+0,S
 LD I
 INC
 ST I
 SJMP ?73
?75 EQU *
 LEAI 0,S
 PUSHI
 LEAI 2+0,S
 LD I
 MUL #512
 ADD #-8192
 PUSHA
 CLR
 PUSHA
 CALL sd_sector_op
 FREE 6
 CMPB #0
 JZ ?78
?77 EQU *
 JMP ?76
?74 EQU *
 CLR
 ST 6,S
 ST 4,S
?79 EQU *
 LD 4,S
 CMP #4096
 ULT
 SJNZ ?81
 JMP ?80
?82 EQU *
 LD 4,S
 INC
 ST 4,S
 SJMP ?79
?81 EQU *
 LD 4,S
 LDI #-8192
 ADAI
 LD 6,S
 ADDB I
 ST 6,S
 JMP ?82
?80 EQU *
 LD 6,S
 ANDB #255
 JZ ?83
 LD #?0+26
 PUSHA
 CALL puts
 FREE 2
 JMP ?78
?83 EQU *
 LD #?0+45
 PUSHA
 CALL puts
 FREE 2
			JMP $E000
?72 EQU *
 LD #?0+80
 PUSHA
 CALL puts
 FREE 2
?78 EQU *
 LD #?0+104
 PUSHA
 CALL puts
 FREE 2
?84 EQU *
 LDI #-48
 LDB #255
 STB I
 LD #?0+135
 PUSHA
 CALL puts
 FREE 2
 CALL getc
 ST 8,S
 LDI #?87
 SWITCH
?88 EQU *
 LD #?0+138
 PUSHA
 CALL puts
 FREE 2
 JMP ?86
?89 EQU *
 JMP ?71
?90 EQU *
 CALL inspect_mem
 JMP ?86
?91 EQU *
 CALL enter_mem
 JMP ?86
?92 EQU *
 CALL serial_upload
 JMP ?86
?93 EQU *
 LDB #4
 PUSHA
 CALL read_hex
 FREE 2
 ST 8,S
 LD #?0+0
 PUSHA
 CALL puts
 FREE 2
 LD 8,S
 PUSHA
 CALL jump
 FREE 2
 JMP ?86
?94 EQU *
 LD #?0+219
 PUSHA
 CALL puts
 FREE 2
 JMP ?86
?87 EQU *
 FDB ?93,71,?92,83,?91,69,?90,77,?89,66,?88,72,0
 FDB ?94
?86 EQU *
 LD #?0+0
 PUSHA
 CALL puts
 FREE 2
 JMP ?84
?85 EQU *
 FREE 10
 RET
endofbios EQU *
?0 FCB 13,10,0,58,32,0,10,13,82,101,97,100,105,110,103,32
 FCB 83,68,32,99,97,114,100,10,13,0,73,110,118,97,108,105
 FCB 100,32,99,104,101,99,107,115,117,109,10,13,0,74,117,109
 FCB 112,105,110,103,32,116,111,32,98,111,111,116,32,108,111,97
 FCB 100,101,114,32,97,116,32,48,120,69,48,48,48,13,10,0
 FCB 70,97,105,108,101,100,32,116,111,32,105,110,105,116,32,83
 FCB 68,32,99,97,114,100,46,0,10,13,77,111,110,105,116,111
 FCB 114,58,32,32,80,114,101,115,115,32,72,32,102,111,114,32
 FCB 104,101,108,112,10,13,0,42,32,0,10,13,66,58,32,66
 FCB 111,111,116,32,83,68,10,13,77,58,32,73,110,115,112,101
 FCB 99,116,32,109,101,109,111,114,121,10,13,69,58,32,69,110
 FCB 116,101,114,32,109,101,109,111,114,121,10,13,83,58,32,83
 FCB 101,114,105,97,108,32,117,112,108,111,97,100,10,13,71,58
 FCB 32,71,111,32,65,100,100,114,13,10,0,63,0
