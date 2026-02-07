test: blocks/test_timer.pass test_timermem.pass

blocks/test_timer.pass:
	make -C blocks all

test_timermem.pass: timer_mem.v blocks/timer.v timer_mem_tb.v
	verilator --lint-only $^
	iverilog -o sim.vvp $^
	(vvp sim.vvp -fst > $@.log && touch $@) || cat $@.log

clean:
	rm -f *.vvp *.vcd *.pass *.log
	make -C blocks clean
