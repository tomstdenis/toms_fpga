all: blink.s.hex test_useq.pass

useq_as: useq_as.c
	${CC} -Wall -O2 -g3 $^ -o $@

test_useq.pass: useq.v useq_tb.v exec1_top.v exec2_top.v simple.s.hex uart.s.hex
	grep -v "^#" uart.s.hex > uart_clean.hex
	grep -v "^#" simple.s.hex > simple_clean.hex
	verilator --lint-only useq.v useq_tb.v
	iverilog -Wall -o sim.vvp useq.v useq_tb.v
	(vvp sim.vvp -fst > $@.log && touch $@) || cat $@.log

simple.s.hex: simple.s useq_as
	./useq_as ./simple.s

uart.s.hex: uart.s useq_as
	./useq_as ./uart.s

clean:
	rm -f *.vvp *.vcd *.pass *.log useq_as *.hex
