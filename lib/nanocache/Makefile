#use empty F for nanocache.v and nanocache_comb.v
#use F with NATIVE_32BIT for nanocache_comb_32bit.v

#F=
#MOD=nanocache.v
#MOD=nanocache_comb.v

# OR ---

F=-D NATIVE_32BIT
MOD=nanocache_comb_32bit.v

all: trace.hex test_nanocache.pass stream

test_nanocache.pass: ../nanosram/nanosram.v ${MOD} refmem.v nanocache_tb.v
	#verilator --lint-only $^
	iverilog ${F} -D MODEL_SIM -o sim.vvp $^
	(vvp sim.vvp -fst > $@.log && touch $@) || cat $@.log

trace.hex: gen
	@./gen
	
gen: gen.c
	@gcc -g3 -Wall ${F} gen.c -o gen

stream: stream.c
	@gcc -O2 -Wall ${F} stream.c -o stream

.PHONY: clean
clean:
	@rm -f gen trace.hex *.log *.pass *.vvp *.vcd stream
