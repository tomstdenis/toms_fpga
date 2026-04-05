TARGET=vga_comb
TOP=top
FREQ=25.175

OBJS+=${TARGET}.v pll1.v \
../../../lib/vga/blocks/vga_640x480_timing.v

all: ${TARGET}.bit

# Synthesize the source
$(TARGET).json: $(OBJS)
		yosys -p "synth_ecp5 -json $@" $(OBJS)

# Place and Route
$(TARGET)_out.config: $(TARGET).json
		nextpnr-ecp5 -r --45k --package CABGA381 --speed 6 --json $< --textcfg $@ --lpf $(TARGET).lpf

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

clean:
		rm -f *.svf *.bit *.config *.ys pll*.v *.asc *.json

.PHONY: sram flash clean
