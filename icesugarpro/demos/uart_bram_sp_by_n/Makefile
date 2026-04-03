TARGET=echo
TOP=top
FREQ=50
BLOCKS=2

OBJS+=${TARGET}.v pll.v \
../../../lib/uart/blocks/tx_uart.v ../../../lib/uart/blocks/rx_uart.v ../../../lib/uart/blocks/uart.v \
../../lib/bram/bram_sp_2048x8.v ../../lib/bram/bram_sp_nx2048x8.v

all: ${TARGET}.bit

$(TARGET).json: $(OBJS)
		yosys -DBLOCKS=${BLOCKS} -DFREQ=${FREQ} -p "synth_ecp5 -json $@" $(OBJS)

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
	
pll.v:
	ecppll -i 25 -o ${FREQ} -f pll.v
	
uart_test: uart_test.c
	gcc -O0 -Wall -DBLOCKS=${BLOCKS} uart_test.c -o uart_test

clean:
		rm -f *.svf *.bit *.config *.ys pll.v *.asc *.json uart_test

.PHONY: prog clean
