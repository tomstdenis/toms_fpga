TARGET=echo
TOP=top

OBJS+=echo.v uart.v tx_uart.v rx_uart.v pll.v

#TRELLIS=/usr/local/share/trellis

all: ${TARGET}.bit

$(TARGET).json: $(OBJS)
		yosys -p "synth_ecp5 -json $@" $(OBJS)

$(TARGET)_out.config: $(TARGET).json
		nextpnr-ecp5 --45k --package CABGA381 --speed 6 --json $< --textcfg $@ --lpf $(TARGET).lpf

$(TARGET).bit: $(TARGET)_out.config
		ecppack --compress --svf ${TARGET}.svf $< $@

${TARGET}.svf : ${TARGET}.bit

prog: ${TARGET}.svf
		dapprog ${TARGET}.svf

pll.v:
	ecppll -i 25 -o 100 -f pll.v

clean:
		rm -f *.svf *.bit *.config *.ys pll.v

.PHONY: prog clean
