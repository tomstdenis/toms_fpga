all: test_cf.pass

test_cf.pass: cf.v cf_tb.v ../math/serial_divide.v
	verilator --lint-only cf.v cf_tb.v ../math/serial_divide.v
	iverilog -Wall -o sim.vvp cf.v cf_tb.v ../math/serial_divide.v
	(vvp sim.vvp -fst > $@.log && touch $@) || cat $@.log
	
lds: lds.c
	gcc lds.c -o lds

boot_hex_to_rom: boot_hex_to_rom.c
	gcc boot_hex_to_rom.c -o boot_hex_to_rom
	
mon_p25.hex.mi: boot_hex_to_rom
	./boot_hex_to_rom < MON_P25.HEX > mon_p25.hex.mi

boot_sim.hex: boot_hex_to_rom
	./boot_hex_to_rom < boot_rom_test.hex > boot_test.hex

clean:
	rm -rf *.vvp *.vcd *.pass *.log lds lds.hex boot_hex_to_rom boot_test_sim.hex *.mi
