; adc_demo.s - 6502 ADC & Clear Decimal Mode Demo
.setcpu "6502"

.export _start

; Apple II Soft Switches
SOFTSWITCH_TEXTOFF   = $C050
SOFTSWITCH_MIXEDOFF  = $C052
SOFTSWITCH_PAGE1     = $C054
SOFTSWITCH_LORES     = $C056

LGR_SCREEN_BASE      = $0400

screen_ptr = $FB     ; Uses $FB (low byte) and $FC (high byte)


.segment "CODE"

_start:
    cld                  ; CRITICAL: Ensure decimal mode is cleared for true binary ADC

    ; 1. Initialize Display Modes via Soft Switches
    sta SOFTSWITCH_TEXTOFF
    sta SOFTSWITCH_MIXEDOFF
    sta SOFTSWITCH_PAGE1
    sta SOFTSWITCH_LORES

    lda #0               ; Initialize accumulator / base color
    tax                  ; X will serve as our X-coordinate / index
    sta x_coord
    sta y_coord

main_loop:
    clc                  ; Always clear carry before addition if not chaining multi-byte
    adc y_coord          ; Add accumulator (tests ADC with carry propagation)
    
    ; Pack the lower 4 bits of accumulator into both nibbles for a valid Lo-Res color (0-15)
    pha                  ; Save accumulator value
    and #$0F             ; Mask to 4-bit color
    sta color_val
    asl a                ; shift colour into top nibble
    asl a
    asl a
    asl a
    ora color_val        ; Duplicate into upper and lower nibbles (C * 16 + C)
    sta color_val
    
    ; Draw pixel at column X across row 24 (middle of screen)
    ldy y_coord
    jsr set_pixel_fast

    pla                  ; Restore accumulator

    ldx x_coord
    inx                  ; Next column
    stx x_coord
    cpx #40              ; Reached end of 40 columns?
    bne main_loop

    ; increment Y
    ldy y_coord
    iny 
    tya
    cpy #48
    bne cont_main
    lda #0
cont_main:
    sta y_coord

    ldx #0               ; Reset X if you want it to loop continuously
    jmp main_loop

; Simple classic 6502 pixel plotter for row 24 ($0580 base address)
; Input: A = 4-bit color value (0-15), X = column (0-39)
set_pixel_fast:
    stx x_coord          ; Save X column safely to zero-page variable
    sty y_coord

    ; look up row offset
    lda _row_lo,y
    sta screen_ptr
    lda _row_hi,y
    sta screen_ptr+1
    tya                  ; a == y coord
    ldy x_coord
    ; now (screen_ptr),y points to the pixel but we need to know if we
    ; are modifying the top or bottom

    ; 2. Determine even or odd column using saved X coordinate
    lsr a                ; Shifts lowest bit into Carry (Carry = 1 if odd, 0 if even)
    bcs draw_odd_nibble

draw_even_nibble:
    ; Even X: update lower nibble (bits 0-3), preserve upper nibble
    lda (screen_ptr), y
    and #$F0             ; Clear lower nibble
    sta temp_val
    
    lda color_val        ; Get our 4-bit color
    and #$0F             ; Ensure 4 bits
    ora temp_val
    sta (screen_ptr), y
    jmp plot_done

draw_odd_nibble:
    ; Odd X: update upper nibble (bits 4-7), preserve lower nibble
    lda (screen_ptr), y
    and #$0F             ; Clear upper nibble
    sta temp_val
    
    lda color_val        ; Get our 4-bit color
    and #$0F
    asl a                ; Shift color into upper nibble (bits 4-7)
    asl a
    asl a
    asl a
    ora temp_val
    sta (screen_ptr), y

plot_done:
    ldx x_coord          ; Restore original X register
    rts

x_coord:
    .byte 0, 0
y_coord:
    .byte 0
temp_val:
    .byte 0
color_val:
    .byte 0

_row_lo:
    ; y = 0..7 (Text rows 0..3)
    .byte <$0400, <$0400, <$0480, <$0480, <$0500, <$0500, <$0580, <$0580
    ; y = 8..15 (Text rows 4..7)
    .byte <$0600, <$0600, <$0680, <$0680, <$0700, <$0700, <$0780, <$0780
    ; y = 16..23 (Text rows 8..11)
    .byte <$0428, <$0428, <$04A8, <$04A8, <$0528, <$0528, <$05A8, <$05A8
    ; y = 24..31 (Text rows 12..15)
    .byte <$0628, <$0628, <$06A8, <$06A8, <$0728, <$0728, <$07A8, <$07A8
    ; y = 32..39 (Text rows 16..19)
    .byte <$0450, <$0450, <$04D0, <$04D0, <$0550, <$0550, <$05D0, <$05D0
    ; y = 40..47 (Text rows 20..23)
    .byte <$0650, <$0650, <$06D0, <$06D0, <$0750, <$0750, <$07D0, <$07D0

_row_hi:
    ; y = 0..7 (Text rows 0..3)
    .byte >$0400, >$0400, >$0480, >$0480, >$0500, >$0500, >$0580, >$0580
    ; y = 8..15 (Text rows 4..7)
    .byte >$0600, >$0600, >$0680, >$0680, >$0700, >$0700, >$0780, >$0780
    ; y = 16..23 (Text rows 8..11)
    .byte >$0428, >$0428, >$04A8, >$04A8, >$0528, >$0528, >$05A8, >$05A8
    ; y = 24..31 (Text rows 12..15)
    .byte >$0628, >$0628, >$06A8, >$06A8, >$0728, >$0728, >$07A8, >$07A8
    ; y = 32..39 (Text rows 16..19)
    .byte >$0450, >$0450, >$04D0, >$04D0, >$0550, >$0550, >$05D0, >$05D0
    ; y = 40..47 (Text rows 20..23)
    .byte >$0650, >$0650, >$06D0, >$06D0, >$0750, >$0750, >$07D0, >$07D0