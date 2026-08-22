all: trace.hex test_nanocache.pass

test_nanocache.pass: ../nanosram/nanosram.v nanocache.v nanocache_tb.v
	#verilator --lint-only $^
	iverilog -D MODEL_SIM -o sim.vvp $^
	(vvp sim.vvp -fst > $@.log && touch $@) || cat $@.log

trace.hex: gen
	@./gen
	
gen: gen.c
	@gcc -g3 -Wall gen.c -o gen

.PHONY: clean
clean:
	@rm -f gen trace.hex *.log *.pass *.vvp *.vcd
