KBD_DAT = $0000
KBD_STAT = $0001
SCR_DAT = $0002
SCR_STAT = $0003
BSAV  = $0100 ; Used to see if hex value is given
MODE  = $0101 ; $00=XAM, $7F=STOR, $B8=BLOCK XAM

.org $8000
RESET:
    STSP $01FF                    ; Initialize stack pointer.
    iMOV FIRSTESC > PC            ; Begin with escape.

NOTCR:
    CMP $0008,A                   ; Backspace key?
    (Z) iMOV BACKSPACE > PC       ; Yes.
    CMP $001B,A                   ; ESC?
    (Z) iMOV ESCAPE > PC          ; Yes.
    INC B > B                     ; Advance text index.
    BCHK B,7                      ; Auto ESC if line longer than 127.
    (!C) iMOV NEXTCHAR > PC

ESCAPE:
    MOV $000D > A                 ; CR.
    JSR ECHO                      ; Output it.

FIRSTESC:
    MOV $00DC > A                 ; "\".
    JSR ECHO                      ; Output it.

GETLINE:
    MOV $000D > A                 ; Send CR.
    JSR ECHO
    MOV 0401 > B                 ; Initialize text index.

BACKSPACE:
    DEC B > B                     ; Back up text index.
    BCHK B,9                      ; Correct text index if it goes beyond start of line.
    (C) INC B > B

NEXTCHAR:
    BCHK (KBD_STAT),0             ; Check keyboard status.
    (!C) iMOV NEXTCHAR > PC       ; Loop until ready.
    MOV $00FF,A > A               ; Add character to text buffer.
    SHR B > B                     ; If B is impair, place char in the upper 16 bits.
    (C) AND (B),A > A
    SWA A > A
    OR (KBD_DAT),A > A
    (C) SWA A > A
    MOV A > (B)
    SLC B > B
    JSR GETCHAR                   ; Load character, Z is set if char = CR (000A)
    (!Z) JSR ECHO                 ; Display character.
    (!Z) iMOV NOTCR > PC          ; Return if not CR.
    MOV $03FF > B                 ; Reset text index.
    XOR A,A > A                   ; For XAM mode.
    MOV A > C                     ; C=0.

SETMODE:
    MOV A > (MODE)                ; $00 = XAM, $3A = STOR, $2E = BLOK XAM.

BLSKIP:
    INC B > B                     ; Advance text index.

NEXTITEM:
    MOV NEXTITEM2 > S1            ; Push return value.

GETCHAR:
    SHR B > B                     ; TODO: this was "SHR B" ... 
    MOV $00FF > A                 ; Load mask.
    (C) NOT A > A                 ; If text index is impair, invert mask.
    AND (B),A > A                 ; Mask off character.
    (C) SWA A > A                 ; Place character into lower 8 bits if needed.
    SLC B > B                     ; Restore text index.
    CMP $000A,A                   ; Enter (CR)?
    iMOV S1 > PC                  ; Return.	

NEXTITEM2:
    (Z) JSR ECHO                  ; Yes, output it.
    (Z) iMOV GETLINE > PC         ; Yes, done this line.
    CMP $002E,A                   ; "."?
    (Z) iMOV SETMODE > PC         ; Set BLOCK XAM mode.
    (!C) iMOV BLSKIP > PC         ; Skip delimiter.
    CMP $003A,A                   ; ":"?
    (Z) iMOV SETMODE > PC         ; Yes, set STOR mode.
    CMP $0052,A                   ; "R"?
    (Z) iMOV D > PC               ; Yes, run user program.
    CMP $0072,A                   ; "r"?
    (Z) iMOV D > PC               ; Yes, run user program.
    MOV C > F                     ; $00 -> HL
    MOV B > (BSAV)                ; Save Y for comparison.

NEXTHEX:
    JSR GETCHAR                   ; Get character for hex test.
    XOR $0030,A > A               ; Map digits to $0-9.
    CMP $0009,A                   ; Digit?
    (!C) iMOV DIG > PC            ; Yes.
    ADD $FF89,A > A               ; Map letter "A"-"F" to $FFFA-FFFF.
    CMP $FFF9,A                   ; Hex letter?
    (C) iMOV DIG > PC             ; Yes.
    ADD $0020,A > A               ; Map letter "a"-"f" to $FFFA-FFFF.
    CMP $FFF9,A                   ; Hex letter?
    (!C) iMOV NOTHEX > PC         ; No, character not hex.

DIG:
    MOV $0004 > C                 ; Shift count.

HEXSHIFT:
    SHL A > A                     ; Hex digit left.
    BCHK A,4                      ; B4 to carry.
    SLC F > F                     ; Rotate into HL.
    DEC C > C                     ; Done 4 shifts?
    (!Z) iMOV HEXSHIFT > PC       ; No, loop.
    INC B > B                     ; Advance text index.
    iMOV NEXTHEX > PC             ; Check next character for hex.

NOTHEX:
    MOV B > A                     ; Check if HL empty (no hex digits).
    CMP (BSAV),A
    (Z) iMOV ESCAPE > PC          ; Yes, generate ESC sequence.
    BCHK (MODE),4                 ; Test MODE byte.
    (!C) iMOV NOTSTOR > PC        ; B4=1 is STOR, 0 is XAM and BLOCK XAM.
    NDXD C                        ; Store at current 'store index'.
    MOV F > (NDX+E)               ; Hex data.
    INC E > E                     ; Increment store index.
    iMOV NEXTITEM > PC            ; Get next command item.

NOTSTOR:
    BCHK (MODE),2                 ; Test MODE byte.
    (C) iMOV XAMNEXT > PC         ; B2 = 0 for XAM, 1 for BLOCK XAM.
    MOV F > E                     ; Copy hex data to 'store index'.
    MOV F > D                     ; And to 'XAM index'.
    SETZ                          ; Set zero flag to print address.

NXTPRNT:
    (!Z) iMOV PRDATA > PC         ; Not zero means no address to print.
    MOV $000D > A                 ; CR.
    JSR ECHO                      ; Output it.
    MOV D > A                     ; 'Examine index'
    JSR PRWORD                    ; Output it in hex format.
    MOV $003A > A                 ; ":".
    JSR ECHO                      ; Output it.

PRDATA:
    MOV $0020 > A                 ; Blank.
    JSR ECHO                      ; Output it.
    NDXS C                        ; Get data byte at 'examine index'.
    MOV (NDX+D) > A
    JSR PRWORD                    ; Output it in hex format.

XAMNEXT:
    MOV C > (MODE)                ; 0 -> MODE (XAM mode).
    MOV D > A
    CMP F,A                       ; Compare 'examine index' to hex data.
    (Z OR C) iMOV NEXTITEM > PC   ; Not less, so no more data to output.
    INC D > D                     ; Increment 'examine index'.
    MOV D > A
    AND $0003,A > A               ; Check low-order 'examine index' byte, for MOD 4 = 0
    (!C) iMOV NXTPRNT > PC

PRWORD:
    MOV C > S1                    ; Save C.
    MOV $0004 > C                 ; Loop count.

PRLOOP:
    ROL A > A                     ; MSD to LSD position.
    ROL A > A
    ROL A > A
    ROL A > A
    MOV A > S1                    ; Save A.
    AND $000F,A > A               ; Mask LSD for hex print.
    OR $0030,A > A                ; Add "0".
    CMP $0039,A                   ; Digit?
    (C) ADD $0007 > A             ; No, Add offset for letter.
    JSR ECHO                      ; Output it.
    MOV S1 > A                    ; Restore A.
    DEC C > C                     ; Done 4 loops?
    (!Z) iMOV PRLOOP > PC         ; No, loop.
    MOV S1 > C                    ; Restore C.
    iMOV S1 > PC                  ; Return.

ECHO:
    BCHK (SCR_STAT),0             ; Is the display ready?
    (!C) iMOV ECHO > PC           ; No, wait until it is
    iMOV A > (SCR_DAT)            ;output character to display
    iMOV S1 > PC                  ; Return.

.org $80FC                        ;effectively the same as FFFC with 256 byte ROM
    RETI                          ;if an interrupt somehow happens, return from it
.word $80FC                   ; IRQ vector
.word $80FC                   ; NMI vector
.word RESET                   ; RESET vector
