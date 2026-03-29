all: test_ib16.pass

test_ib16.pass: ib16.v ib16_tb.v
	verilator --lint-only $^
	iverilog -Wall -o sim.vvp $^
	(vvp sim.vvp -fst > $@.log && touch $@) || cat $@.log

ib16_as: ib16_as.c
	gcc -O0 -Wall -g3 ib16_as.c -o ib16_as

clean:
	rm -f *.vvp *.vcd *.pass *.log ib16_as *.hex *.bin
