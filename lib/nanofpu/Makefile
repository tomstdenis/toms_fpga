NUMTESTS=100000

all: fpu.hex test_faddsub.pass

test_faddsub.pass: faddsub_tb.v
	#verilator --lint-only $^
	iverilog ${F} -D MODEL_SIM -D NUM_OF_TESTS=${NUMTESTS} -o sim.vvp $^
	(vvp sim.vvp -fst > $@.log && touch $@) || cat $@.log

fpu.hex: vecgen
	@./vecgen addsub
	
vecgen: vecgen.c
	@gcc -g3 -Wall ${F} -DNUM_OF_TESTS=${NUMTESTS} vecgen.c -o vecgen -lm

.PHONY: clean
clean:
	@rm -f vecgen fpu.hex *.log *.pass *.vvp *.vcd
