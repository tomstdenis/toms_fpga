TARGET=ib16
TOP=top
FREQ=64
BLOCKS=16

OBJS+=${TARGET}.v pll.v \
../../../lib/uart/blocks/tx_uart.v ../../../lib/uart/blocks/rx_uart.v ../../../lib/uart/blocks/uart.v \
../../../lib/ib16/ib16_v2.v ../../lib/bram/bram_sp_nx2048x8.v ../../lib/bram/bram_sp_2048x8.v

all: ${TARGET}.bit

$(TARGET).json: $(OBJS)
		yosys -DBLOCKS=${BLOCKS} -DFREQ=${FREQ} -p "synth_ecp5 -json $@" $(OBJS)

$(TARGET)_out.config: $(TARGET).json
		nextpnr-ecp5 -r --45k --package CABGA381 --speed 6 --json $< --textcfg $@ --lpf $(TARGET).lpf

$(TARGET).bit: $(TARGET)_out.config
		ecppack --compress --svf ${TARGET}.svf $< $@

${TARGET}.svf : ${TARGET}.bit

sram: ${TARGET}.svf
	openFPGALoader -b colorlight-i9 ${TARGET}.svf
	
flash: ${TARGET}.bit
	openFPGALoader -b colorlight-i9 --unprotect-flash --bulk-erase
	openFPGALoader -b colorlight-i9 -f ${TARGET}.bit --verify
	
pll.v:
	ecppll --highres -i 25 -o ${FREQ} -f pll.v

clean:
		rm -f *.svf *.bit *.config *.ys pll.v *.asc *.json

.PHONY: prog clean
