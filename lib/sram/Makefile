all: blocks/test_sram_fifo.pass blocks/test_sram_flat.pass blocks/test_sram_flat_wide.pass blocks/test_sram_flat_zc.pass blocks/test_sram_flat_wide_zc.pass test_spi_sram_mem.pass

blocks/test_sram_fifo.pass blocks/test_sram_flat.pass blocks/test_sram_flat_wide.pass blocks/test_sram_flat_zc.pass blocks/test_sram_flat_wide_zc.pass:
	make -C blocks

test_spi_sram_mem.pass: spi_sram_mem.v spi_sram_mem_tb.v blocks/sram.v
	verilator --lint-only $^
	iverilog -D SIM_MODEL -o sim.vvp $^
	(vvp sim.vvp -fst > $@.log && touch $@) || cat $@.log

clean:
	make -C blocks clean
	rm -f *.vvp *.vcd *.pass *.log

