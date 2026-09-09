test_lt1000soc.pass: lt1000soc_tb.v
	iverilog -D MODEL_SIM -I ../ -I ../../vga/blocks -o sim.vvp $^
	(vvp sim.vvp -fst > $@.log && touch $@) || cat $@.log

clean:
	rm -f *.vvp *.vcd *.pass *.log
