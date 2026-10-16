all: useq_as upload test_useq.pass boot.s.hex

useq_as: useq_as.c
	${CC} -Wall -O2 -g3 $^ -o $@

upload: upload.c
	${CC} -Wall -O2 -g3 $^ -o $@

test_useq.pass: useq.v useq_tb.v exec1_top.v  uart.s.hex
	grep -v "^#" uart.s.hex > uart_clean.hex
	verilator --lint-only useq.v useq_tb.v
	iverilog -Wall -o sim.vvp useq.v useq_tb.v
	(vvp sim.vvp -fst > $@.log && touch $@) || cat $@.log

uart.s.hex: uart.s useq_as
	./useq_as ./uart.s

boot.s.hex: boot.s useq_as
	./useq_as ./boot.s

clean:
	rm -f *.vvp *.vcd *.pass *.log useq_as *.hex *.lst *.bin upload
