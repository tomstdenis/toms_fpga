del *.LST
del *.HEX
ccf bios.c -fopa
asmcf bios.asm -fs
ccf boot.c -fopa
asmcf boot.asm -fs
ccf gpio.c -fopl

