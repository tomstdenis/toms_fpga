* SIMPLE BOOT ROM DEMO
   ORG $F000

   LDI #$F800
loop EQU *
   IN $00
   JZ loop
   OUT $00
*   LDB #$40
   LDB #$5A
   OUT $10
   TIA
   STB I
   INC
   TAI
   SJMP loop
   
