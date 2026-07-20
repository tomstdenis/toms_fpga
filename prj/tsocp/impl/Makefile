TARGET=toy_cpu
TOP=top

OBJS+=${TARGET}.v pll.v ${CPU}

all: ${TARGET}.bit

$(TARGET).json: $(OBJS)
		yosys -p "synth_ecp5 -json $@" $(OBJS)

$(TARGET)_out.config: $(TARGET).json
		nextpnr-ecp5 --tmg-ripup -r --45k --package CABGA381 --speed 6 --json $< --textcfg $@ --lpf $(TARGET).lpf

$(TARGET).bit: $(TARGET)_out.config
		ecppack --compress --svf ${TARGET}.svf $< $@
pll.v:
	ecppll -i 25 -o ${FREQ} -f pll.v

clean:
	@rm -f *.svf *.bit *.config *.ys pll.v *.asc *.json
