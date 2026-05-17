* BOOT ROM for C-FLEA on Primer 25K
* Parses basic S records as well as
* - Gxxxx command to run programs (jumps to xxxx)
* - Dxxxx to dump 16 bytes 
* - Bxxxx to dump 256 bytes

* we have 2KB of ROM starting at F000
* Note that the RTL is configured for only holding 512 bytes currently...
   ORG $F000

* some variables to keep state, let's hide them at the end of video mem
temp EQU $FFFF    * temp variables
temp2 EQU $FFFE
temp3 EQU $FFFD
temp4 EQU $FFFC   * n
addr EQU $FFFA    * we can 16-bit load the addr from here
addrhi EQU $FFFB  * and write to the top half here
stack EQU $F900   * stack inside the video so we have something to see

   LD #stack
   TAS          * SP = stack (F900)
   LEAI ?WELCOMSTR
   CALL putstr
top
   IN $00       	* read from UART
   INC
   SJZ top     * loop while no char
   DEC
   OUT $00
   TAI
   CMPB #'S'    * compare to S
   SJNZ is_S    * it's an 'S' so jump to that handler
   TIA
   CMPB #'G'
   SJNZ is_G    * it's an 'G' jump there
   TIA
   CMPB #'D'
   SJNZ is_D
   TIA
   CMPB #'B'
   SJNZ is_B
   SJMP top     * ignore and jump to top

* S records we need 
* 1. Read command '1' or '9'
* 2. Read 1 hex byte, n =  # of data + 3
* 3. Read 2 hex bytes (addr)
* 4. Read n - 3 hex bytes (data)
* 5. Read 1 hex byte (checksum)
is_S
   IN $00
   INC
   SJZ is_S       * wait for a char (the command)
   DEC
   OUT $00
   CALL read_hex  * read the # of bytes 'n'
   SUBB #3		  * sub addr/checksum
   SJZ top		  * no bytes to store so just exit out
   STB temp4      * temp4 == n
   CALL read_hex  * read addrhi
   STB addrhi
   CALL read_hex  * read bottom
   STB addr
   LDI addr       * INDEX = address to store to
is_S_loop
   CALL read_hex
   STB I		  * store via index
   LEAI 1,I		  * increment iindex
   LDB temp4      * load n
   DEC
   STB temp4
   SJNZ is_S_loop
   CALL read_hex  * skip checksum
   JMP top
   
is_G
   CALL read_addr
   IJMP

is_D
   CALL read_addr
   CALL puthexline
   JMP top
   
is_B
   CALL read_addr
   CALL puthexblock
   JMP top
   
* read address into addr
read_addr
   CALL read_hex
   STB addrhi
   CALL read_hex
   STB addr
   LD addr
   RET

* read hex byte into ACC
read_hex
   CLR
   STB temp         * zero the temp byte
   LDB #2
   STB temp2        * zero nibble count
read_hex_top
   LDB temp         * shift temp up 4 bits for next nibble
   SHL #4
   STB temp
read_hex_loop
   IN $00
   INC
   SJZ read_hex_loop * read from uart
   DEC
   OUT $00          * echo back
   STB temp3		* save the char being read
   CMPB #'9'        * assume it's 0-9A-F
   UGT              * check for >'9'
   SJNZ read_hex_af
   LDB temp3        * readload byte
   SUBB #'0'		* it's 0-9
read_hex_store_nibble
   ORB temp			* or with accumulated data
   STB temp         * store back
   LDB temp2
   DEC
   STB temp2
   SJNZ read_hex_top
   SJMP read_hex_end
read_hex_af
   LDB temp3        * reload byte
   SUBB #'A'        * subtract 'A'
   ADDB #10         * then normalize to 10..15
   SJMP read_hex_store_nibble
read_hex_end
   LDB temp         * we're done
   RET

* putstr in INDEX
putstr
	PUSHA
	PUSHI
putstrtop
	LDB I
	SJZ putstr_end
	OUT $00
    LEAI 1,I		  * increment iindex
	SJMP putstrtop
putstr_end
	LDI S+
	LDB #10
	OUT $00
	LDB #13
	OUT $00
	LD S+
	RET

* display 16 lines at ACC
puthexblock
	PUSHA				* 2,S == address
	LD #16
	PUSHA				* 0,S == number of lines 
puthexblock_top
	LD 2,S
	CALL puthexline
	ADD #16
	ST 2,S				* increment by 16
	LD 0,S
	DEC
	ST 0,S
	JNZ puthexblock_top
	FREE 2
	LDB #10				* print newline/cr
	OUT $00
	LDB #13
	OUT $00
	LD S+
	SUB #256			* subtract the 256 we added 
	RET

* display 16 bytes at ACC
puthexline
	PUSHI
	PUSHA				* 2,S == address
	LD #16
	PUSHA				* 0,S == number of bytes to print
* display newline
    LDB #10
    OUT $00
    LDB #13
    OUT $00
* display address and space
	LD 2,S
	SHR #8
    CALL puthex
	LD 2,S
    CALL puthex
    LDB #' '
    OUT $00
* display 16 bytes
	LDI 2,S				* address
puthexline_top
	LDB I				* read byte
	CALL puthex
	LDB #' '
	OUT $00
	LD 2,S
	INC
	ST 2,S
	LEAI 1,I            * advance index
	LD 0,S
	DEC
	ST 0,S
	JNZ puthexline_top
	FREE 2
	LD S+
    SUB #16				* subtract the 16 we added to it
	LDI S+
	RET
	
* put hex from ACC
puthex
	PUSHI
	PUSHA				* save what we are printing 2,S
	LD #2
	PUSHA				* 0,S == # of digits to print
puthex_ch
	LD 2,S
	SHR #4				* grab only 4 bits
	AND #$F
	TAI					* save it
	CMPB #9             * compare to 9
	UGT                 * greater than?
	SJNZ puthex_af
	TIA                 * restore masked copy
	ADDB #'0'           * it was 0-9 so map to '0'-'9'
	SJMP puthex_bot
puthex_af
    TIA
    SUBB #10
    ADDB #'A'           * restore and normalize to 'A'-'F'
puthex_bot
    out $00
    LD 2,S
    SHL #4
    ST 2,S              * shift right 4 bits
    LD 0,S
    DEC
    ST 0,S
    SJNZ puthex_ch
    FREE 2
    LD S+
    LDI S+
    RET
?WELCOMSTR STR "C-FLEA Primer25K monitor -- Tom St Denis"
ROM_END EQU *
