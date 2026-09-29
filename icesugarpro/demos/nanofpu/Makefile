TARGET=nanofpu
TOP=top
FREQ=100
NUMTESTS=16

OBJS+=${TARGET}.v pll.v ../../../lib/nanofpu/nanofpu.v \
../../../lib/uart/blocks/tx_uart.v ../../../lib/uart/blocks/rx_uart.v ../../../lib/uart/blocks/uart.v

all: ${TARGET}.bit

fpu.hex:
	make -C ../../../lib/nanofpu clean
	make -C ../../../lib/nanofpu vecgen NUMTESTS=${NUMTESTS}
	../../../lib/nanofpu/vecgen any

$(TARGET).json: fpu.hex $(OBJS)
		yosys -D NUMTESTS="${NUMTESTS}" -D FREQ="${FREQ}" -p "synth_ecp5 -json $@" $(OBJS)

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

clean:
		rm -f *.svf *.bit *.config *.ys pll.v *.asc *.json *.hex

.PHONY: prog clean
