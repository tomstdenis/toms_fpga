TARGET=debug
TOP=top

OBJS+=debug.v \
../../../lib/uart/blocks/uart.v ../../../lib/uart/blocks/tx_uart.v ../../../lib/uart/blocks/rx_uart.v \
../../../lib/debug/debug.v ../../../lib/debug/debug_uart.v \
pll1.v pll2.v pll3.v pll4.v 

all: ${TARGET}.bit

$(TARGET).json: $(OBJS)
		yosys -p "synth_ecp5 -json $@" $(OBJS)

$(TARGET)_out.config: $(TARGET).json
		nextpnr-ecp5 --tmg-ripup -r --45k --package CABGA381 --speed 6 --json $< --textcfg $@ --lpf $(TARGET).lpf

$(TARGET).bit: $(TARGET)_out.config
		ecppack --compress --svf ${TARGET}.svf $< $@

${TARGET}.svf : ${TARGET}.bit

sram: ${TARGET}.svf
	openFPGALoader -b colorlight-i9 ${TARGET}.svf
	
flash: ${TARGET}.bit
	openFPGALoader -b colorlight-i9 --unprotect-flash --bulk-erase
	openFPGALoader -b colorlight-i9 -f ${TARGET}.bit --verify
	
pll1.v:
	ecppll -i 25 -o 50 -f pll1.v --module pll1

pll2.v:
	ecppll -i 25 -o 75 -f pll2.v --module pll2

pll3.v:
	ecppll -i 25 -o 100 -f pll3.v --module pll3

pll4.v:
	ecppll -i 25 -o 83.3333 -f pll4.v --module pll4

debug_cli: debug_cli.c
	gcc -Wall -O2 $^ -o $@

clean:
		rm -f *.svf *.bit *.config *.ys pll*.v *.asc *.json debug_cli

.PHONY: prog clean
