all: test_cf.pass

test_cf.pass: cf.v cf_tb.v ../math/serial_divide.v lds.hex
	verilator --lint-only cf.v cf_tb.v ../math/serial_divide.v
	iverilog -Wall -o sim.vvp cf.v cf_tb.v ../math/serial_divide.v
	(vvp sim.vvp -fst > $@.log && touch $@) || cat $@.log

lds.hex: lds
	./lds > lds.hex
	
lds: lds.c
	gcc lds.c -o lds

clean:
	rm -rf *.vvp *.vcd *.pass *.log lds lds.hex
