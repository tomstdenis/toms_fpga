all: test_fifo.pass

verify: fifo.v fifo.sby
	sby -f fifo.sby

test_fifo.pass: fifo.v fifo_tb.v
	verilator --lint-only $^
	iverilog -Wall -o sim.vvp $^
	(vvp sim.vvp -fst > $@.log && touch $@) || cat $@.log

clean:
	rm -rf fifo *.vvp *.vcd *.pass *.log 
