all: blink.s.hex test_useq.pass

useq_as: useq_as.c
	${CC} -Wall -O2 -g3 $^ -o $@

test_useq.pass: useq.v useq_tb.v blink.s.hex test1.s.hex test2.s.hex test3.s.hex exec1_top.v exec2_top.v
	grep -v "^#" blink.s.hex > blink_clean.hex
	grep -v "^#" test1.s.hex > test1_clean.hex
	grep -v "^#" test2.s.hex > test2_clean.hex
	grep -v "^#" test3.s.hex > test3_clean.hex
	verilator --lint-only useq.v useq_tb.v
	iverilog -Wall -o sim.vvp useq.v useq_tb.v
	(vvp sim.vvp -fst > $@.log && touch $@) || cat $@.log

test1.s.hex: test1.s useq_as
	./useq_as ./test1.s

test2.s.hex: test2.s useq_as
	./useq_as ./test2.s

test3.s.hex: test3.s useq_as
	./useq_as ./test3.s

blink.s.hex: blink.s useq_as
	./useq_as ./blink.s

clean:
	rm -f *.vvp *.vcd *.pass *.log useq_as *.hex
