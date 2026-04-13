# Project setup
PROJ = echo
DEVICE = lp1k
FOOTPRINT = cm36

all: $(PROJ).bin
OBJS=$(PROJ).v \
../../../lib/uart/blocks/rx_uart.v ../../../lib/uart/blocks/tx_uart.v ../../../lib/uart/blocks/uart.v

# 1. Synthesis: Convert Verilog to JSON netlist
$(PROJ).json: $(OBJS)
	yosys -p "synth_ice40 -top top -json $@" $(OBJS)

# 2. Place & Route: Map netlist to FPGA hardware
$(PROJ).asc: $(PROJ).json pins.pcf
	nextpnr-ice40 --freq 12 --$(DEVICE) --package $(FOOTPRINT) --pcf pins.pcf --json $< --asc $@

# 3. Pack: Create the final bitstream
$(PROJ).bin: $(PROJ).asc
	icepack $< $@

prog_icelink: ${PROJ}.bin
	cp ${PROJ}.bin /media/${USER}/iCELink/ -vf

prog_sram: $(PROJ).bin
	icesprog -S $<

prog_flash: $(PROJ).bin
	icesprog -o 0 $<

clean:
	rm -f $(PROJ).json $(PROJ).asc $(PROJ).bin

.PHONY: all prog_sram prog_flash clean

