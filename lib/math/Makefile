all: test_serial_divide.pass

test_serial_divide.pass: serial_divide.v serial_divide_tb.v
	verilator --lint-only $^
	iverilog -Wall -o sim.vvp $^
	(vvp sim.vvp -fst > $@.log && touch $@) || cat $@.log

clean:
	rm -rf *.vvp *.vcd *.pass *.log 
