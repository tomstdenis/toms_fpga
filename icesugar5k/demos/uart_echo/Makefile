# Project setup
PROJ = echo
DEVICE = up5k
FOOTPRINT = sg48
PLLFREQ = 31.875

all: $(PROJ).bin

# 1. Synthesis: Convert Verilog to JSON netlist
$(PROJ).json: $(PROJ).v uart.v rx_uart.v tx_uart.v pll.v
	yosys -p "synth_ice40 -top top -json $@" $^

# 2. Place & Route: Map netlist to FPGA hardware
$(PROJ).asc: $(PROJ).json pins.pcf
	nextpnr-ice40 --freq ${PLLFREQ}  -r --$(DEVICE) --package $(FOOTPRINT) --pcf pins.pcf --json $< --asc $@

# 3. Pack: Create the final bitstream
$(PROJ).bin: $(PROJ).asc
	icepack $< $@

# 4. Program SRAM (The fast "Brother from another mother" way)
prog_sram: $(PROJ).bin
	icesprog -S $<

# 5. Program Flash (Permanent)
prog_flash: $(PROJ).bin
	icesprog -o 0 $<

pll.v:
	icepll -p -o ${PLLFREQ} -m -f pll.v

clean:
	rm -f $(PROJ).json $(PROJ).asc $(PROJ).bin pll.v

.PHONY: all prog_sram prog_flash clean

