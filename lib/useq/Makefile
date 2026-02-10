all: blink.s.hex test_useq.pass

useq_as: useq_as.c
	${CC} -Wall -O2 -g3 $^ -o $@

test_useq.pass: useq.v useq_tb.v
	grep -v "^#" blink.s.hex > blink_clean.hex
	verilator --lint-only $^
	iverilog -Wall -o sim.vvp $^
	(vvp sim.vvp -fst > $@.log && touch $@) || cat $@.log

blink.s.hex: blink.s useq_as
	./useq_as ./blink.s

clean:
	rm -f *.vvp *.vcd *.pass *.log useq_as *.hex
