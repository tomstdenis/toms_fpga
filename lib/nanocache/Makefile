all: trace.hex test_nanocache.pass stream

test_nanocache.pass: ../nanosram/nanosram.v nanocache_comb_32bit.v refmem.v nanocache_tb.v
	#verilator --lint-only $^
	iverilog -D MODEL_SIM -o sim.vvp $^
	(vvp sim.vvp -fst > $@.log && touch $@) || cat $@.log

trace.hex: gen
	@./gen
	
gen: gen.c
	@gcc -g3 -Wall gen.c -o gen

stream: stream.c
	@gcc -O2 -Wall stream.c -o stream

.PHONY: clean
clean:
	@rm -f gen trace.hex *.log *.pass *.vvp *.vcd stream
