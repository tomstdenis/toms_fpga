* BOOT ROM for C-FLEA on Primer 25K
* Parses basic S records (S1 and S9) as well as Gxxxx command to run programs

* we have 2KB of ROM starting at F000
   ORG $F000

* some variables to keep state, let's hide them at the end of video mem
temp EQU $FFFF    * temp variables
temp2 EQU $FFFE
addr EQU $FFFC    * we can 16-bit load the addr from here
addrhi EQU $FFFD  * and write to the top half here
stack EQU $F900   * stack inside the video so we have something to see

   LD #stack
   TAS          * SP = stack (F900)
top
   IN $00       * read from UART
   SJZ top      * loop while no char
   CMPB #'S'    * compare to S
   JNZ is_S     * it's an 'S' so jump to that handler
   CMPB #'G'
   JNZ is_G     * it's an 'G' jump there
   SJMP top     * ignore and jump to top

* S records we need 
* 1. Read command '1' or '9'
* 2. Read 1 hex byte, n =  # of data + 3
* 3. Read 2 hex bytes (addr)
* 4. Read n - 3 hex bytes (data)
* 5. Read 1 hex byte (checksum)
is_S
   IN $00
   SJZ is_S       * wait for a char (the command)
   CALL read_hex  * read the # of bytes 'n'
   SUBB #3		  * sub addr/checksum
   STB temp2      * temp2 == n
   CALL read_hex  * read addrhi
   STB addrhi
   CALL read_hex  * read bottom
   STB addr
   LDI addr       * INDEX = address to store to
is_S_loop
   CALL read_hex
   STB I		  * store via index
   TIA			  * increment index
   INC
   TAI
   LDB temp2      * load n
   DEC
   STB temp2
   SJNZ is_S_loop
   CALL read_hex  * skip checksum
   JMP top
   
is_G
   CALL read_hex  * read address
   STB addrhi
   CALL read_hex
   STB addr
   LD addr        * jump to address
   IJMP

* read hex byte into ACC
read_hex EQU *
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
   SJZ read_hex_loop
   CMPB #'9'
   UGT
   SJNZ read_hex_af
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
   SUBB #'A'        * subtract 'A'
   ADDB #10         * then normalize to 10..15
   SJMP read_hex_store_nibble
read_hex_end
   LDB temp         * we're done
   RET

