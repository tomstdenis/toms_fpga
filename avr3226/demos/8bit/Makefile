BOARD = --board-options clock=20internal --board-options chip=3226
FQBN = --fqbn megaTinyCore:megaavr:atxy6
BUILDFLAGS = -I./ ${CFLAGS}
PORT = /dev/ttyUSB0

pcdemo: ../cc65/bin/cl65 /tmp/pcdemo.src.c
	make -C roms
	gcc ${CFLAGS} -I. -DHOSTPC -Os /tmp/pcdemo.src.c -o pcdemo -lncurses

avrapp: ../cc65/bin/cl65 8bit.ino
	arduino-cli compile -v ${FQBN} ${BOARD} --build-property build.extra_flags="${BUILDFLAGS}" -e

avrupload:
	arduino-cli upload ${FQBN} ${BOARD} -p ${PORT} -P serialupdi57k

# TODO
# TODO: make for flasher app
# TODO: make for programming flash for a given config like apple2plus, etc...

../cc65/bin/cl65:
	(cd .. ; git clone https://github.com/cc65/cc65.git )
	make -C ../cc65 -j8

/tmp/pcdemo.src.c: pcdemo.pc *.src
	cat *.src pcdemo.pc > /tmp/pcdemo.src.c

.PHONY: 8bit.ino
8bit.ino: *.src
	rm -f 8bit.ino
	cat *.src > 8bit.ino

.PHONY: clean
clean:
	rm -rf build pcdemo emuflash.bin riscv/test riscv/test_c 8bit.ino*
	make -C roms clean
