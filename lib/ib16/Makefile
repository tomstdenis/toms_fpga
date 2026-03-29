all: test_ib16.pass

test_ib16.pass: ib16.v ib16_tb.v tb_test.bin
	verilator --lint-only ib16.v ib16_tb.v
	iverilog -Wall -o sim.vvp ib16.v ib16_tb.v
	(vvp sim.vvp -fst > $@.log && touch $@) || cat $@.log

tb_test.bin: tb_test.s ib16_as
	./ib16_as tb_test.s

ib16_as: ib16_as.c
	gcc -O0 -Wall -g3 ib16_as.c -o ib16_as

clean:
	rm -f *.vvp *.vcd *.pass *.log ib16_as *.hex *.bin
