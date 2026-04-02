all: test_ib16_v2.pass uart_demo.s.bin upload

test_ib16_v2.pass: ib16_v2.v ib16_v2_tb.v tb_test.s.bin uart_demo.s.bin
	verilator -DSIM --lint-only ib16_v2.v ib16_v2_tb.v
	iverilog -DSIM -Wall -o sim.vvp ib16_v2.v ib16_v2_tb.v
	(vvp sim.vvp -fst > $@.log && touch $@) || cat $@.log

test_ib16.pass: ib16.v ib16_tb.v tb_test.s.bin uart_demo.s.bin aluloop.s.bin
	verilator --lint-only ib16.v ib16_tb.v
	iverilog -Wall -o sim.vvp ib16.v ib16_tb.v
	(vvp sim.vvp -fst > $@.log && touch $@) || cat $@.log

uart_demo.s.bin: uart_demo.s ib16_as
	./ib16_as uart_demo.s

aluloop.s.bin: aluloop.s ib16_as
	./ib16_as aluloop.s

tb_test.s.bin: tb_test.s ib16_as
	./ib16_as tb_test.s

ib16_as: ib16_as.c
	gcc -O0 -Wall -g3 ib16_as.c -o ib16_as

upload: upload.c
	gcc -O0 -Wall upload.c -o upload

clean:
	rm -f *.vvp *.vcd *.pass *.log ib16_as *.hex *.bin upload
