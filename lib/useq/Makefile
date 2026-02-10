all: test_useq.pass useq_as

useq_as: useq_as.c
	${CC} -Wall -O2 -g3 $^ -o $@

test_useq.pass: useq.v useq_tb.v
	verilator --lint-only $^
	iverilog -Wall -o sim.vvp $^
	(vvp sim.vvp -fst > $@.log && touch $@) || cat $@.log

clean:
	rm -f *.vvp *.vcd *.pass *.log useq_as *.hex
