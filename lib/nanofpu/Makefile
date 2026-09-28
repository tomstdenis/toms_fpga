NUMTESTS=100000

all: vecgen test_fsti.pass test_fldi.pass test_fdiv.pass test_fmul.pass test_faddsub.pass

test_faddsub.pass: faddsub_tb.v
	./vecgen addsub
	iverilog ${F} -D MODEL_SIM -D NUM_OF_TESTS=${NUMTESTS} -o sim.vvp $^
	(vvp sim.vvp -fst > $@.log && touch $@) || cat $@.log

test_fmul.pass: fmul_tb.v
	./vecgen mul
	iverilog ${F} -D MODEL_SIM -D NUM_OF_TESTS=${NUMTESTS} -o sim.vvp $^
	(vvp sim.vvp -fst > $@.log && touch $@) || cat $@.log

test_fldi.pass: fldi_tb.v
	./vecgen fldi
	iverilog ${F} -D MODEL_SIM -D NUM_OF_TESTS=${NUMTESTS} -o sim.vvp $^
	(vvp sim.vvp -fst > $@.log && touch $@) || cat $@.log

test_fsti.pass: fsti_tb.v
	./vecgen fsti
	iverilog ${F} -D MODEL_SIM -D NUM_OF_TESTS=${NUMTESTS} -o sim.vvp $^
	(vvp sim.vvp -fst > $@.log && touch $@) || cat $@.log

test_fdiv.pass: fdiv_tb.v
	./vecgen div
	iverilog ${F} -D MODEL_SIM -D NUM_OF_TESTS=${NUMTESTS} -o sim.vvp $^
	(vvp sim.vvp -fst > $@.log && touch $@) || cat $@.log

vecgen: vecgen.c
	@gcc -g3 -Wall ${F} -DNUM_OF_TESTS=${NUMTESTS} vecgen.c -o vecgen -lm

.PHONY: clean
clean:
	@rm -f vecgen fpu.hex *.log *.pass *.vvp *.vcd
