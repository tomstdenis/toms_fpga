all: test_ib16_v2.pass

test_ib16_v2.pass: ib16_v2.v ib16_v2_tb.v uart_demo.s.bin boot_rom.s.bin
	verilator -DSIM --lint-only ib16_v2.v ib16_v2_tb.v
	iverilog -DSIM -Wall -o sim.vvp ib16_v2.v ib16_v2_tb.v
	(vvp sim.vvp -fst > $@.log && touch $@) || cat $@.log

uart_demo.s.bin: uart_demo.s uart_demo_isr.s lib/uart.s lib/tty.s ib16_as
# 8KB version
	cpp -DIRQ_VECTOR=0x1E00 -DDEMO_PROG_SIZE=3968 uart_demo.s | grep -v \^# > /tmp/uart_demo.s 
# 32KB version
#	cpp -DIRQ_VECTOR=0x7E00 -DDEMO_PROG_SIZE=16256 uart_demo.s | grep -v \^# > /tmp/uart_demo.s 
# Generate uart_demo binary
	./ib16_as /tmp/uart_demo.s
	mv -vf /tmp/uart_demo.s.* .

boot_rom_ecp5.s.bin: boot_rom_ecp5.s ib16_as
	./ib16_as boot_rom_ecp5.s

boot_rom.s.bin: boot_rom.s ib16_as
	./ib16_as boot_rom.s

ib16_as: ib16_as.c
	gcc -O0 -Wall -g3 ib16_as.c -o ib16_as

upload: upload.c
	gcc -O0 -Wall upload.c -o upload

clean:
	rm -f *.vvp *.vcd *.pass *.log ib16_as *.hex *.bin upload
