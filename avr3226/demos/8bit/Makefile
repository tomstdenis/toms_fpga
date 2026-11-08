pcdemo: cc65/bin/cl65 /tmp/pcdemo.src.c
	make -C roms
	gcc ${CFLAGS} -I. -DHOSTPC -O3 /tmp/pcdemo.src.c -o pcdemo -lncurses

cc65/bin/cl65:
	git clone https://github.com/cc65/cc65.git
	make -C cc65 -j8

/tmp/pcdemo.src.c: pcdemo.c *ino
	cat *.ino pcdemo.c > /tmp/pcdemo.src.c

.PHONY: clean
clean:
	rm -f pcdemo emuflash.bin riscv/test riscv/test_c
	make -C roms clean
