# Project setup
PROJ = blinky
DEVICE = up5k
FOOTPRINT = sg48

all: $(PROJ).bin

# 1. Synthesis: Convert Verilog to JSON netlist
$(PROJ).json: $(PROJ).v
	yosys -p "synth_ice40 -top top -json $@" $<

# 2. Place & Route: Map netlist to FPGA hardware
$(PROJ).asc: $(PROJ).json pins.pcf
	nextpnr-ice40 --$(DEVICE) --package $(FOOTPRINT) --pcf pins.pcf --json $< --asc $@

# 3. Pack: Create the final bitstream
$(PROJ).bin: $(PROJ).asc
	icepack $< $@

# 4. Program SRAM (The fast "Brother from another mother" way)
prog_sram: $(PROJ).bin
	icesprog -S $<

# 5. Program Flash (Permanent)
prog_flash: $(PROJ).bin
	icesprog -o 0 $<

clean:
	rm -f $(PROJ).json $(PROJ).asc $(PROJ).bin

.PHONY: all prog_sram prog_flash clean

