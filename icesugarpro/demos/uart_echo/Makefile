TARGET=echo
TOP=top
FREQ=200

OBJS+=echo.v uart.v tx_uart.v rx_uart.v pll.v

#TRELLIS=/usr/local/share/trellis

all: ${TARGET}.bit

$(TARGET).json: $(OBJS)
		yosys -p "synth_ecp5 -json $@" $(OBJS)

$(TARGET)_out.config: $(TARGET).json
		nextpnr-ecp5 -r --45k --package CABGA381 --speed 6 --json $< --textcfg $@ --lpf $(TARGET).lpf

$(TARGET).bit: $(TARGET)_out.config
		ecppack --compress --svf ${TARGET}.svf $< $@

${TARGET}.svf : ${TARGET}.bit

prog: ${TARGET}.svf
		ecpprog -S ${TARGET}.svf

pll.v:
	ecppll -i 25 -o ${FREQ} -f pll.v

clean:
		rm -f *.svf *.bit *.config *.ys pll.v *.asc *.json

.PHONY: prog clean
