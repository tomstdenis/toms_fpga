* SIMPLE BOOT ROM DEMO
   ORG $F000

   LDI #$F800
loop EQU *
   LDB #$40
   STB I
   TIA
   OUT $10
   INC
   TAI
   SJMP loop
   
