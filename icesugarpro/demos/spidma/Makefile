TARGET=spidma
TOP=top
FREQ=125
SRAM_ADDR_WIDTH=24

OBJS+=${TARGET}.v pll1.v \
../../../lib/spidma/spidma.v \
../../../lib/uart/blocks/rx_uart.v ../../../lib/uart/blocks/tx_uart.v ../../../lib/uart/blocks/uart.v \
../../lib/bram/bram_dp_2048x8.v

all: ${TARGET}.bit

# Synthesize the source
$(TARGET).json: $(OBJS)
		yosys -DFREQ=${FREQ} -DSRAM_ADDR_WIDTH=${SRAM_ADDR_WIDTH} -DBITS=${BITS} -p "synth_ecp5 -json $@" $(OBJS)

# Place and Route
$(TARGET)_out.config: $(TARGET).json
		nextpnr-ecp5 --tmg-ripup -r --45k --package CABGA381 --speed 6 --json $< --textcfg $@ --lpf $(TARGET).lpf

# Create a bitfile and jtag stream
$(TARGET).bit: $(TARGET)_out.config
		ecppack --compress --svf ${TARGET}.svf $< $@

# jtag stream
${TARGET}.svf : ${TARGET}.bit

# Program the SRAM of the Colorlight-i9 which has an ECP5-LF5 on it.
sram: ${TARGET}.svf
	openFPGALoader -b colorlight-i9 ${TARGET}.svf

# Erase, Program, and Verify the bitfile to the Colorlight-i9
flash: ${TARGET}.bit
	openFPGALoader -b colorlight-i9 --unprotect-flash --bulk-erase
	openFPGALoader -b colorlight-i9 -f ${TARGET}.bit --verify

# Generate the four PLLs we need for this design
pll1.v:
	ecppll --highres -i 25 -o ${FREQ} -f pll1.v --module pll1

iter: iter.c
	gcc iter.c -o iter

clean:
		rm -f *.svf *.bit *.config *.ys pll*.v *.asc *.json iter

.PHONY: sram flash clean
