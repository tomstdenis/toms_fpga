BOARD = --board-options clock=20internal --board-options chip=3226
FQBN = --fqbn megaTinyCore:megaavr:atxy6
BUILDFLAGS = -I./ ${CFLAGS}

pcdemo: cc65/bin/cl65 /tmp/pcdemo.src.c
	make -C roms
	gcc ${CFLAGS} -I. -DHOSTPC -O3 /tmp/pcdemo.src.c -o pcdemo -lncurses

avrapp: cc65/bin/cl65 8bit.ino
	arduino-cli compile -v ${FQBN} ${BOARD} --build-property build.extra_flags="${BUILDFLAGS}"

cc65/bin/cl65:
	git clone https://github.com/cc65/cc65.git
	make -C cc65 -j8

/tmp/pcdemo.src.c: pcdemo.c *ino
	cat *.ino pcdemo.c > /tmp/pcdemo.src.c

.PHONY: 8bit.ino
8bit.ino: 0*.ino
	rm -f 8bit.ino
	cat *.ino > 8bit.ino

.PHONY: clean
clean:
	rm -f pcdemo emuflash.bin riscv/test riscv/test_c 8bit.ino
	make -C roms clean
