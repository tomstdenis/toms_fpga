apple2_hello.h: apple2_hello.bin
	xxd -i apple2_hello.bin > apple2_hello.h

apple2_hello.bin: apple2_hello.c
	../cc65/bin/cl65 --target none --start-addr 0x0800 -l apple2_hello.lst -m apple2_hello.map -vm apple2_hello.c -o apple2_hello.bin
	
.PHONY: clean
clean:
	rm -f *.map *.lst apple2_hello.bin
