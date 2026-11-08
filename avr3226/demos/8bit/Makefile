pcdemo: /tmp/pcdemo.src.c
	gcc ${CFLAGS} -I. -DHOSTPC -O3 /tmp/pcdemo.src.c -o pcdemo -lncurses

/tmp/pcdemo.src.c: pcdemo.c *ino
	cat *.ino pcdemo.c > /tmp/pcdemo.src.c

.PHONY: clean
clean:
	rm -f pcdemo emuflash.bin
