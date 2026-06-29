all: test_serial_divide.pass test_sqrt_bin.pass

test_serial_divide.pass: serial_divide.v serial_divide_tb.v
#	verilator --lint-only $^
#	iverilog -Wall -o sim.vvp $^
#	(vvp sim.vvp -fst > $@.log && touch $@) || cat $@.log
	verilator --no-sched-zero-delay --binary $^
	(obj_dir/Vserial_divide > $@.log && touch $@) || cat $@.log

test_sqrt_bin.pass: sqrt_bin.v sqrt_bin_tb.v
#	verilator --lint-only $^
#	iverilog -Wall -o sim.vvp $^
#	(vvp sim.vvp -fst > $@.log && touch $@) || cat $@.log
	verilator --no-sched-zero-delay --binary $^
	(obj_dir/Vsqrt_bin > $@.log && touch $@) || cat $@.log

clean:
	rm -rf *.vvp *.vcd *.pass *.log obj_dir
