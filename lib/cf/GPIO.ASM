c_clrscr EQU *
 LD #-2048
 PUSHA
 CLR
 PUSHA
 LD #2048
 PUSHA
 CALL memset
 FREE 6
 RET
c_scroll EQU *
 LD #-2048
 PUSHA
 LD #-1968
 PUSHA
 LD #1920
 PUSHA
 CALL memcpy
 FREE 6
 LD #-128
 PUSHA
 LDB #32
 PUSHA
 LDB #80
 PUSHA
 CALL memset
 FREE 6
 RET
c_rewind EQU *
 LDI #-2
 LD I
 CMPB #0
 JZ ?1
 LDI #-4
 LD I
 CMPB #0
 JNZ ?2
 LDI #-4
 LD I
 DEC
 ST I
 LDI #-2
 LDB #79
 ST I
?2 EQU *
 JMP ?3
?1 EQU *
 LDI #-2
 LD I
 DEC
 ST I
?3 EQU *
 RET
c_gotoxy EQU *
 LDI #-2
 LD 4,S
 ST I
 LDI #-4
 LD 2,S
 ST I
 RET
c_putc EQU *
 LDB 2,S
 CMPB #10
 JZ ?4
 LDI #-2
 CLR
 ST I
 JMP ?5
?4 EQU *
 LDI #-4
 LD I
 MULB #80
 LDI #-2
 ADD I
 LDI #-2048
 ADAI
 LDB 2,S
 STB I
 LDI #-2
 LD I
 INC
 ST I
 LDI #-2
 LD I
 CMPB #80
 JZ ?6
 LDI #-2
 CLR
 ST I
?5 EQU *
 LDI #-4
 LD I
 INC
 ST I
 LDI #-4
 LD I
 CMPB #25
 JZ ?7
 CALL c_scroll
 LDI #-4
 LDB #24
 ST I
?7 EQU *
?6 EQU *
 RET
c_puts EQU *
?8 EQU *
 LDI 2,S
 LDB I
 JZ ?9
 LD 2,S
 TAI ;
 INC
 ST 2,S
 LDB I
 PUSHA
 CALL c_putc
 FREE 2
 JMP ?8
?9 EQU *
 RET
c_serin EQU *
		IN $00
 RET
c_getc ALLOC 2
?10 EQU *
 CALL c_serin
 ST 0,S
?11 EQU *
 LD 0,S
 CMP #-1
 JNZ ?10
?12 EQU *
 LD 0,S
?13 EQU *
 LDI S+
 RET
c_gets ALLOC 6
 LD 10,S
 ST 0,S
 LD 10,S
 ADD 8,S
 SUBB #1
 ST 2,S
?14 EQU *
 CALL c_getc
 ST 4,S
 CMPB #8
 JZ ?16
 LD 10,S
 CMP 0,S
 JNZ ?17
 LD 10,S
 DEC
 ST 10,S
 CALL c_rewind
 LDB #32
 PUSHA
 CALL c_putc
 FREE 2
 CALL c_rewind
?17 EQU *
 JMP ?18
?16 EQU *
 LD 4,S
 CMPB #10
 SJNZ ?20
 LD 4,S
 CMPB #13
?20 EQU *
 JZ ?19
 LDI 10,S
 CLR
 STB I
 JMP ?21
?19 EQU *
 LD 10,S
 CMP 2,S
 JNZ ?23
 LD 10,S
 TAI ;
 INC
 ST 10,S
 LD 4,S
 STB I
 LD 4,S
 PUSHA
 CALL c_putc
 FREE 2
?23 EQU *
?22 EQU *
?18 EQU *
 JMP ?14
?15 EQU *
?21 EQU *
 FREE 6
 RET
c_box ALLOC 4
 LDI #-6
 PUSHI
 LDI #-2
 LD I
 ST [S+]
 LDI #-8
 PUSHI
 LDI #-4
 LD I
 ST [S+]
 LD 12,S
 ST 0,S
?24 EQU *
 LD 0,S
 CMP 8,S
 ULT
 SJNZ ?26
 JMP ?25
?27 EQU *
 LD 0,S
 INC
 ST 0,S
 SJMP ?24
?26 EQU *
 LD 10,S
 ST 2,S
?28 EQU *
 LD 2,S
 CMP 6,S
 ULT
 SJNZ ?30
 JMP ?29
?31 EQU *
 LD 2,S
 INC
 ST 2,S
 SJMP ?28
?30 EQU *
 LD 0,S
 PUSHA
 LD 4,S
 PUSHA
 CALL c_gotoxy
 FREE 4
 LDB #32
 PUSHA
 CALL c_putc
 FREE 2
 JMP ?31
?29 EQU *
 JMP ?27
?25 EQU *
 LD 12,S
 PUSHA ;
 LD 12,S
 PUSHA
 CALL c_gotoxy
 FREE 4
 LDB #201
 PUSHA
 CALL c_putc
 FREE 2
 LD 12,S
 PUSHA
 LD 8,S
 PUSHA
 CALL c_gotoxy
 FREE 4
 LDB #200
 PUSHA
 CALL c_putc
 FREE 2
 LD 8,S
 PUSHA
 LD 12,S
 PUSHA
 CALL c_gotoxy
 FREE 4
 LDB #187
 PUSHA
 CALL c_putc
 FREE 2
 LD 8,S
 PUSHA ;
 LD 8,S
 PUSHA
 CALL c_gotoxy
 FREE 4
 LDB #188
 PUSHA
 CALL c_putc
 FREE 2
 LD 12,S
 ADDB #1
 ST 0,S
?32 EQU *
 LD 0,S
 CMP 8,S
 ULT
 SJNZ ?34
 JMP ?33
?35 EQU *
 LD 0,S
 INC
 ST 0,S
 SJMP ?32
?34 EQU *
 LD 0,S
 PUSHA
 LD 12,S
 PUSHA
 CALL c_gotoxy
 FREE 4
 LDB #205
 PUSHA
 CALL c_putc
 FREE 2
 LD 0,S
 PUSHA
 LD 8,S
 PUSHA
 CALL c_gotoxy
 FREE 4
 LDB #205
 PUSHA
 CALL c_putc
 FREE 2
 JMP ?35
?33 EQU *
 LD 10,S
 ADDB #1
 ST 2,S
?36 EQU *
 LD 2,S
 CMP 6,S
 ULT
 SJNZ ?38
 JMP ?37
?39 EQU *
 LD 2,S
 INC
 ST 2,S
 SJMP ?36
?38 EQU *
 LD 12,S
 PUSHA
 LD 4,S
 PUSHA
 CALL c_gotoxy
 FREE 4
 LDB #186
 PUSHA
 CALL c_putc
 FREE 2
 LD 8,S
 PUSHA
 LD 4,S
 PUSHA
 CALL c_gotoxy
 FREE 4
 LDB #186
 PUSHA
 CALL c_putc
 FREE 2
 JMP ?39
?37 EQU *
 LDI #-2
 PUSHI
 LDI #-6
 LD I
 ST [S+]
 LDI #-4
 PUSHI
 LDI #-8
 LD I
 ST [S+]
 FREE 4
 RET
c_boxmsg ALLOC 2
 LD 4,S
 PUSHA
 CALL strlen
 FREE 2
 ADDB #3
 ST 0,S
 LD 8,S
 PUSHA ;
 LD 8,S
 PUSHA
 LD 12,S
 ADD 4,S
 PUSHA
 LD 12,S
 ADDB #2
 PUSHA
 CALL c_box
 FREE 8
 LD 8,S
 ADDB #2
 PUSHA
 LD 8,S
 ADDB #1
 PUSHA
 CALL c_gotoxy
 FREE 4
 LD 4,S
 PUSHA
 CALL c_puts
 FREE 2
 LDI #-2
 PUSHI
 LDI #-6
 LD I
 ST [S+]
 LDI #-4
 PUSHI
 LDI #-8
 LD I
 ST [S+]
 LDI S+
 RET
c_boxquery ALLOC 2
 LD 8,S
 PUSHA
 CALL strlen
 FREE 2
 ADDB #3
 ADD 4,S
 ST 0,S
 LD 12,S
 PUSHA ;
 LD 12,S
 PUSHA
 LD 16,S
 ADD 4,S
 PUSHA
 LD 16,S
 ADDB #2
 PUSHA
 CALL c_box
 FREE 8
 LD 12,S
 ADDB #2
 PUSHA
 LD 12,S
 ADDB #1
 PUSHA
 CALL c_gotoxy
 FREE 4
 LD 8,S
 PUSHA
 CALL c_puts
 FREE 2
 LD 6,S
 PUSHA ;
 LD 6,S
 PUSHA
 CALL c_gets
 FREE 4
 LDI #-2
 PUSHI
 LDI #-6
 LD I
 ST [S+]
 LDI #-4
 PUSHI
 LDI #-8
 LD I
 ST [S+]
 LDI S+
 RET
wait_us EQU *
		OUT $11			 * clear timer
wait_us_top
		IN $11			 * read timer
		CMP 2,S			 * compare to us
		ULT				 * unsigned less than 
		SJNZ wait_us_top * wait till us passes
 RET
since_us EQU *
		IN $11			* read uS timer
		OUT $11			* clear the uS timer
 RET
wait_ms EQU *
?40 EQU *
 LD 2,S
 DEC
 ST 2,S
 INC
 JZ ?41
 LD #1000
 PUSHA
 CALL wait_us
 FREE 2
 JMP ?40
?41 EQU *
 RET
delay_loops EQU *
		OUT $11					* clear 1us timer
		LD 2,S					* load x
delay_loops_top EQU *
		DEC
		SJNZ delay_loops_top	* decrement and loop
		IN $11					* read 1us timer and return value
 RET
delay_calibrate ALLOC 8
 CLR
 ST 6,S
 LD #-1
 ST 4,S
?42 EQU *
 LD 4,S
 ADD 6,S
 SHR #1
 ST 0,S
 PUSHA
 CALL delay_loops
 FREE 2
 ST 2,S
 CMP #1000
 UGT
 JZ ?45
 LD 0,S
 ST 4,S
 JMP ?46
?45 EQU *
 LD 0,S
 ST 6,S
?46 EQU *
?43 EQU *
 LD 4,S
 CMP 6,S
 JZ ?42
?44 EQU *
 LD 0,S
?47 EQU *
 FREE 8
 RET
outport EQU *
 LD 4,S
 LDI #?49
 SWITCH
?50 EQU *
				LD 2,S
				OUT $01
 JMP ?48
?51 EQU *
				LD 2,S
				OUT $02
 JMP ?48
?52 EQU *
				LD 2,S
				OUT $03
 JMP ?48
?53 EQU *
				LD 2,S
				OUT $04
 JMP ?48
?49 EQU *
 FDB ?53,3,?52,2,?51,1,?50,0,0,?48
?48 EQU *
 RET
dirport EQU *
 LD 4,S
 LDI #?55
 SWITCH
?56 EQU *
				LD 2,S
				OUT $05
 JMP ?54
?57 EQU *
				LD 2,S
				OUT $06
 JMP ?54
?58 EQU *
				LD 2,S
				OUT $07
 JMP ?54
?59 EQU *
				LD 2,S
				OUT $08
 JMP ?54
?55 EQU *
 FDB ?59,3,?58,2,?57,1,?56,0,0,?54
?54 EQU *
 RET
inport EQU *
 LD 4,S
 LDI #?61
 SWITCH
?62 EQU *
				LD 2,S
				IN $01
				RET
 JMP ?60
?63 EQU *
				LD 2,S
				IN $02
				RET
 JMP ?60
?64 EQU *
				LD 2,S
				IN $03
				RET
 JMP ?60
?65 EQU *
				LD 2,S
				IN $04
				RET
 JMP ?60
?61 EQU *
 FDB ?65,3,?64,2,?63,1,?62,0,0,?60
?60 EQU *
 RET
spi_setup EQU *
 LD 10,S
 STB spi_port
 LDB #1
 SHL 8,S
 ST spi_cs_mask
 LDB #1
 SHL 6,S
 ST spi_sck_mask
 LDB #1
 SHL 4,S
 ST spi_miso_mask
 LDB #1
 SHL 2,S
 ST spi_mosi_mask
 LD spi_cs_mask
 COM
 SHL #8
 ST spi_cs_mask_ds
 LD spi_sck_mask
 COM
 SHL #8
 ST spi_sck_mask_ds
 LD spi_miso_mask
 COM
 SHL #8
 ST spi_miso_mask_d
 LD spi_mosi_mask
 COM
 SHL #8
 ST spi_mosi_mask_d
 LD 10,S
 PUSHA
 LD spi_cs_mask
 OR spi_sck_mask
 OR spi_mosi_mask
 PUSHA
 CALL dirport
 FREE 4
 LD 10,S
 PUSHA
 LD spi_cs_mask_ds
 OR spi_mosi_mask_d
 OR spi_sck_mask_ds
 OR spi_miso_mask_d
 OR spi_cs_mask
 PUSHA
 CALL outport
 FREE 4
 RET
spi_set_cs EQU *
 LDB spi_port
 PUSHA
 LD 4,S
 SJZ ?67
 LD spi_cs_mask
 SJMP ?66
?67 EQU *
 CLR
?66 EQU *
 OR spi_cs_mask_ds
 PUSHA
 CALL outport
 FREE 4
 RET
spi_set_sck EQU *
 LDB spi_port
 PUSHA
 LD 4,S
 SJZ ?69
 LD spi_sck_mask
 SJMP ?68
?69 EQU *
 CLR
?68 EQU *
 OR spi_sck_mask_ds
 PUSHA
 CALL outport
 FREE 4
 RET
spi_transfer ALLOC 4
 CLR
 ST 2,S
 CLR
 ST 0,S
?70 EQU *
 LD 0,S
 CMPB #8
 ULT
 SJNZ ?72
 JMP ?71
?73 EQU *
 LD 0,S
 INC
 ST 0,S
 SJMP ?70
?72 EQU *
 LDB spi_port
 PUSHA
 LD 8,S
 ANDB #128
 SJZ ?75
 LD spi_mosi_mask
 SJMP ?74
?75 EQU *
 CLR
?74 EQU *
 OR spi_mosi_mask_d
 PUSHA
 CALL outport
 FREE 4
 LD 6,S
 SHL #1
 ST 6,S
 LD 2,S
 SHL #1
 ST 2,S
 LDB spi_port
 PUSHA
 CLR
 PUSHA
 CALL inport
 FREE 4
 AND spi_miso_mask
 NOT
 NOT
 OR 2,S
 ST 2,S
 LDB #1
 PUSHA
 CALL spi_set_sck
 FREE 2
 CLR
 PUSHA
 CALL spi_set_sck
 FREE 2
 JMP ?73
?71 EQU *
 LD 2,S
?76 EQU *
 FREE 4
 RET
sd_init EQU *
 LD 10,S
 STB sd_port
 LD 8,S
 STB sd_cs_pin
 LD 6,S
 STB sd_sck_pin
 LD 4,S
 STB sd_miso_pin
 LD 2,S
 STB sd_mosi_pin
 CLR
 STB sd_is_hc
 CLR
 STB sd_is_init
 RET
sd_cmd ALLOC 4
 LDB #255
 PUSHA
 CALL spi_transfer
 FREE 2
 LDB #255
 PUSHA
 CALL spi_transfer
 FREE 2
 LD 12,S
 ADDB #64
 PUSHA
 CALL spi_transfer
 FREE 2
 LD 10,S
 SHR #8
 PUSHA
 CALL spi_transfer
 FREE 2
 LD 10,S
 ANDB #255
 PUSHA
 CALL spi_transfer
 FREE 2
 LD 8,S
 SHR #8
 PUSHA
 CALL spi_transfer
 FREE 2
 LD 8,S
 ANDB #255
 PUSHA
 CALL spi_transfer
 FREE 2
 LD 6,S
 PUSHA
 CALL spi_transfer
 FREE 2
 CLR
 ST 0,S
?77 EQU *
 LD 0,S
 CMP #256
 ULT
 SJNZ ?79
 JMP ?78
?80 EQU *
 LD 0,S
 INC
 ST 0,S
 SJMP ?77
?79 EQU *
 LDB #255
 PUSHA
 CALL spi_transfer
 FREE 2
 ST 2,S
 ANDB #128
 JNZ ?81
 LD 2,S
 JMP ?82
?81 EQU *
 JMP ?80
?78 EQU *
 LD #-1
?82 EQU *
 FREE 4
 RET
sd_cmd13_status EQU *
 LDB #13
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
 JZ ?83
 LDB #255
 PUSHA
 CALL spi_transfer
 FREE 2
 JMP ?84
?83 EQU *
 LD #-1
?85 EQU *
?84 EQU *
 RET
sd_read_block ALLOC 4
 CLR
 ST 0,S
?86 EQU *
 LD 0,S
 CMP #256
 ULT
 SJNZ ?88
 JMP ?87
?89 EQU *
 LD 0,S
 INC
 ST 0,S
 SJMP ?86
?88 EQU *
 LDB #255
 PUSHA
 CALL spi_transfer
 FREE 2
 ST 2,S
 CMPB #254
 JNZ ?87
?90 EQU *
 LD 2,S
 ANDB #224
 JNZ ?91
 LD 2,S
 ANDB #31
 STB sd_read_error
 LD #-1
 JMP ?92
?91 EQU *
 JMP ?89
?87 EQU *
 LD 0,S
 CMP #256
 JZ ?93
 LD #-1
 JMP ?92
?93 EQU *
 CLR
 ST 0,S
?94 EQU *
 LD 0,S
 CMP 6,S
 ULT
 SJNZ ?96
 JMP ?95
?97 EQU *
 LD 0,S
 INC
 ST 0,S
 SJMP ?94
?96 EQU *
 LD 0,S
 LDI 8,S
 ADAI
 PUSHI
 LDB #255
 PUSHA
 CALL spi_transfer
 FREE 2
 STB [S+]
 JMP ?97
?95 EQU *
 LDB #255
 PUSHA
 CALL spi_transfer
 FREE 2
 LDB #255
 PUSHA
 CALL spi_transfer
 FREE 2
 CLR
?92 EQU *
 FREE 4
 RET
sd_reset ALLOC 6
 CLR
 ST 2,S
?98 EQU *
 LDB #5
 ST sd_clk
 CLR
 STB sd_is_hc
 CLR
 STB sd_is_init
 LD 2,S
 INC
 ST 2,S
 CMPB #16
 JZ ?99
 LD #-1
 JMP ?100
?99 EQU *
 LDB sd_port
 PUSHA
 LDB sd_cs_pin
 PUSHA
 LDB sd_sck_pin
 PUSHA
 LDB sd_miso_pin
 PUSHA
 LDB sd_mosi_pin
 PUSHA
 CALL spi_setup
 FREE 10
 LDB #1
 PUSHA
 CALL spi_set_cs
 FREE 2
 CLR
 ST 0,S
?101 EQU *
 LD 0,S
 CMPB #10
 ULT
 SJNZ ?103
 JMP ?102
?104 EQU *
 LD 0,S
 INC
 ST 0,S
 SJMP ?101
?103 EQU *
 LDB #255
 PUSHA
 CALL spi_transfer
 FREE 2
 JMP ?104
?102 EQU *
 CLR
 PUSHA
 CALL spi_set_cs
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
 JZ ?98
?105 EQU *
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
 JZ ?98
?106 EQU *
 LDB #255
 PUSHA
 LD sd_clk
 PUSHA
 CALL spi_transfer
 FREE 4
 CMPB #0
 JZ ?98
?107 EQU *
 LDB #255
 PUSHA
 LD sd_clk
 PUSHA
 CALL spi_transfer
 FREE 4
 CMPB #0
 JZ ?98
?108 EQU *
 LDB #255
 PUSHA
 LD sd_clk
 PUSHA
 CALL spi_transfer
 FREE 4
 CMPB #1
 JZ ?98
?109 EQU *
 LDB #255
 PUSHA
 LD sd_clk
 PUSHA
 CALL spi_transfer
 FREE 4
 CMPB #170
 JZ ?98
?110 EQU *
 CLR
 ST 0,S
?111 EQU *
 LD 0,S
 CMP #256
 ULT
 SJNZ ?113
 JMP ?112
?114 EQU *
 LD 0,S
 INC
 ST 0,S
 SJMP ?111
?113 EQU *
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
 JZ ?98
?115 EQU *
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
 JNZ ?112
?116 EQU *
 JMP ?114
?112 EQU *
 LD 0,S
 CMP #256
 JNZ ?98
?117 EQU *
 CLR
 ST sd_clk
 CLR
 ST 0,S
?118 EQU *
 LD 0,S
 CMP #256
 ULT
 SJNZ ?120
 JMP ?119
?121 EQU *
 LD 0,S
 INC
 ST 0,S
 SJMP ?118
?120 EQU *
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
 JZ ?98
?122 EQU *
 LDB #255
 PUSHA
 CALL spi_transfer
 FREE 2
 ST 4,S
 LDB #255
 PUSHA
 CALL spi_transfer
 FREE 2
 LDB #255
 PUSHA
 CALL spi_transfer
 FREE 2
 LDB #255
 PUSHA
 CALL spi_transfer
 FREE 2
 LD 4,S
 ANDB #128
 JZ ?123
 LD 4,S
 ANDB #64
 SJZ ?125
 LDB #1
 SJMP ?124
?125 EQU *
 CLR
?124 EQU *
 STB sd_is_hc
 JMP ?119
?123 EQU *
 JMP ?121
?119 EQU *
 LD 0,S
 CMP #256
 JNZ ?98
?126 EQU *
 LDB sd_is_hc
 JNZ ?127
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
 JZ ?98
?128 EQU *
?127 EQU *
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
 JZ ?98
?129 EQU *
 LD #sd_csd
 PUSHA
 LDB #16
 PUSHA
 CALL sd_read_block
 FREE 4
 CMPB #0
 JZ ?98
?130 EQU *
 LDB #1
 PUSHA
 CALL spi_set_cs
 FREE 2
 LDI #sd_sectors+0
 PUSHI
 LDI #sd_csd+9
 LDB I
 SHL #10
 ST [S+]
 LDI #sd_sectors+2
 PUSHI
 LDI #sd_csd+9
 LDB I
 SHR #6
 PUSHA
 LDI #sd_csd+8
 LDB I
 SHL #2
 ORB S+
 PUSHA
 LDI #sd_csd+7
 LDB I
 ANDB #63
 SHL #10
 OR S+
 ST [S+]
 LDB #1
 STB sd_is_init
 CLR
?100 EQU *
 FREE 6
 RET
sd_tail EQU *
 LDB #1
 PUSHA
 CALL spi_set_cs
 FREE 2
 LDB #255
 PUSHA
 CALL spi_transfer
 FREE 2
 LDB #255
 PUSHA
 CALL spi_transfer
 LDI S+
 RET
sd_read_sector ALLOC 4
 LD #-1
 ST 0,S
 CLR
 ST 2,S
 LDB sd_port
 PUSHA
 LDB sd_cs_pin
 PUSHA
 LDB sd_sck_pin
 PUSHA
 LDB sd_miso_pin
 PUSHA
 LDB sd_mosi_pin
 PUSHA
 CALL spi_setup
 FREE 10
 CLR
 PUSHA
 CALL spi_set_cs
 FREE 2
?131 EQU *
 LDB #17
 PUSHA
 LDI 10,S
 LEAI 2,I
 LD I
 PUSHA
 LDI 12,S
 LEAI I
 LD I
 PUSHA
 CLR
 PUSHA
 CALL sd_cmd
 FREE 8
 CMPB #0
 JZ ?133
?132 EQU *
 LD 6,S
 PUSHA
 LD #512
 PUSHA
 CALL sd_read_block
 FREE 4
 CMPB #0
 JZ ?133
?134 EQU *
 CLR
 ST 0,S
?133 EQU *
 LD 0,S
 CMPB #0
 NOT
 SJZ ?136
 LD 2,S
 INC
 ST 2,S
 DEC
 CMPB #10
 ULT
?136 EQU *
 JZ ?135
 LDB #10
 PUSHA
 CALL wait_ms
 FREE 2
 JMP ?131
?135 EQU *
 CALL sd_tail
 LD 0,S
?137 EQU *
 FREE 4
 RET
remap ALLOC 2
 CLR
 ST 0,S
 LD 4,S
 ANDB #1
 JZ ?138
 LD 0,S
 ORB #16
 ST 0,S
?138 EQU *
 LD 4,S
 ANDB #2
 JZ ?139
 LD 0,S
 ORB #1
 ST 0,S
?139 EQU *
 LD 4,S
 ANDB #4
 JZ ?140
 LD 0,S
 ORB #32
 ST 0,S
?140 EQU *
 LD 4,S
 ANDB #8
 JZ ?141
 LD 0,S
 ORB #2
 ST 0,S
?141 EQU *
 LD 4,S
 ANDB #16
 JZ ?142
 LD 0,S
 ORB #64
 ST 0,S
?142 EQU *
 LD 4,S
 ANDB #32
 JZ ?143
 LD 0,S
 ORB #4
 ST 0,S
?143 EQU *
 LD 4,S
 ANDB #64
 JZ ?144
 LD 0,S
 ORB #128
 ST 0,S
?144 EQU *
 LD 4,S
 ANDB #128
 JZ ?145
 LD 0,S
 ORB #8
 ST 0,S
?145 EQU *
 LD 0,S
 COM
 ANDB #255
?146 EQU *
 LDI S+
 RET
main ALLOC 8
 LD #sec
 PUSHA
 CLR
 PUSHA
 LD #512
 PUSHA
 CALL memset
 FREE 6
 LD #?0+0
 PUSHA
 LDB #1
 CALL printf
 FREE 2
 CLR
 PUSHA
 LDB #3
 PUSHA
 CLR
 PUSHA
 LDB #1
 PUSHA
 LDB #2
 PUSHA
 CALL sd_init
 FREE 10
 CALL sd_reset
 ST 0,S
 LD #?0+21
 PUSHA
 LD 2,S
 PUSHA
 LDB sd_is_init
 PUSHA
 LDB sd_is_hc
 PUSHA
 LD spi_sck_mask_ds
 PUSHA
 LD spi_miso_mask_d
 PUSHA
 LD spi_mosi_mask_d
 PUSHA
 LD spi_cs_mask_ds
 PUSHA
 LDB #8
 CALL printf
 FREE 16
 LD 0,S
 JNZ ?147
 LD #?0+71
 PUSHA
 LDB #1
 CALL printf
 FREE 2
 CLR
 ST 0,S
?148 EQU *
 LD 0,S
 CMPB #16
 ULT
 SJNZ ?150
 JMP ?149
?151 EQU *
 LD 0,S
 INC
 ST 0,S
 SJMP ?148
?150 EQU *
 LD #?0+79
 PUSHA
 LD 2,S
 LDI #sd_csd
 ADAI
 LDB I
 PUSHA
 LDB #2
 CALL printf
 FREE 4
 JMP ?151
?149 EQU *
 LD #?0+85
 PUSHA
 LDI #sd_sectors+2
 LD I
 PUSHA
 LDI #sd_sectors+0
 LD I
 PUSHA
 LDB #3
 CALL printf
 FREE 6
 LEAI 4+0,S
 LDB #5
 ST I
 LEAI 4+2,S
 CLR
 ST I
 LEAI 4,S
 PUSHI
 LD #sec
 PUSHA
 CALL sd_read_sector
 FREE 4
 ST 0,S
 JNZ ?152
 LD #?0+118
 PUSHA
 LEAI 6+2,S
 LD I
 PUSHA
 LEAI 8+0,S
 LD I
 PUSHA
 LDB #3
 CALL printf
 FREE 6
 CLR
 ST 0,S
?153 EQU *
 LD 0,S
 CMP #512
 ULT
 SJNZ ?155
 JMP ?154
?156 EQU *
 LD 0,S
 INC
 ST 0,S
 SJMP ?153
?155 EQU *
 LD #?0+79
 PUSHA
 LD 2,S
 LDI #sec
 ADAI
 LDB I
 PUSHA
 LDB #2
 CALL printf
 FREE 4
 LD 0,S
 ADDB #1
 ANDB #15
 CMPB #0
 JZ ?157
 LD #?0+143
 PUSHA
 LDB #1
 CALL printf
 FREE 2
?157 EQU *
 JMP ?156
?154 EQU *
 LD #?0+19
 PUSHA
 LDB #1
 CALL printf
 FREE 2
 JMP ?158
?152 EQU *
 LD #?0+146
 PUSHA
 LEAI 6+2,S
 LD I
 PUSHA
 LEAI 8+0,S
 LD I
 PUSHA
 LDB sd_read_error
 PUSHA
 LDB #4
 CALL printf
 FREE 8
?158 EQU *
?147 EQU *
		LD #$F000
		IJMP
 FREE 8
 RET
?0 FCB 10,10,83,68,32,67,97,114,100,32,71,80,73,79,32,100
 FCB 101,109,111,10,0,115,100,95,114,101,115,101,116,40,41,32
 FCB 61,61,32,37,120,44,32,37,100,44,32,37,100,44,32,37
 FCB 48,52,120,44,32,37,48,52,120,44,32,37,48,52,120,44
 FCB 32,37,48,52,120,10,0,99,115,100,32,61,61,32,0,37
 FCB 48,50,120,32,0,10,115,100,95,115,101,99,116,111,114,115
 FCB 91,93,32,61,61,32,123,32,37,48,52,120,44,32,37,48
 FCB 52,120,32,125,10,0,82,101,97,100,32,115,101,99,116,111
 FCB 114,32,35,37,48,52,120,37,48,52,120,46,46,46,58,10
 FCB 9,0,69,114,114,111,114,32,114,101,97,100,105,110,103,32
 FCB 115,101,99,116,111,114,35,37,48,52,120,37,48,52,120,46
 FCB 46,46,37,120,10,0
$EX:printf
$EX:memset
$EX:memcpy
$EX:strlen
$DD:spi_cs_mask 2
$DD:spi_sck_mask 2
$DD:spi_miso_mask 2
$DD:spi_mosi_mask 2
$DD:spi_cs_mask_ds 2
$DD:spi_sck_mask_ds 2
$DD:spi_miso_mask_d 2
$DD:spi_mosi_mask_d 2
$DD:spi_port 1
$DD:sd_is_init 1
$DD:sd_is_hc 1
$DD:sd_port 1
$DD:sd_cs_pin 1
$DD:sd_sck_pin 1
$DD:sd_miso_pin 1
$DD:sd_mosi_pin 1
$DD:sd_clk 2
$DD:sd_sectors 4
$DD:sd_csd 16
$DD:sd_read_error 1
$DD:sec 512
