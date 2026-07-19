This is Toms Sim Only CPU Project.

The point of this project is to explore CPU design with a really trivial ISA so we can
focus on architecture design.  The ISA is documented in isa.md.

The assembler is in tools/asm.py and you run it as:
    python3 tools/asm.py data/${program}.asm
And it outputs data/${program}.asm.hex as output.  To simulate it you run:
    python3 tools/sim.py data/${program}.asm
And it outputs data/${program}.asm.state as a reference model for the verilog simulations

The various evolutions of the core will be placed in subdirectories of evos and the top Makefile
will take an evolution number as a parameter so we can plug and play models.

The standard ports will be (TBD):
    - rst_n: reset active low
    - clk: posedge clock signals
    - is_halted: output to tell top if the cpu reached a halt opcode
    - then pairs of read/write bus channels:
        - bus_addr_[a|b]: 8 bit address
        - bus_data_in_[a|b]: 8 bit data to write to memory
        - bus_data_out_[a|b]: 8 bit data read from memory
        - bus_data_wr_en_[a|b]: 1 bit flag to enable writes
        - bus_data_valid_[a|b]: Signal bus request is valid
        - bus_data_ready_[a|b]: Signal bus request is ready (must lower valid for 1 cycle at least)


