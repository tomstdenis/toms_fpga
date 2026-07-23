Tom's Sim Only CPU Project

This is a project to bench and test various CPU design choices.  To have something to write about I invented the 
Toy ISA (doc/isa.md) which is a fairly simple 8-bit RISC ISA where a baseline non-pipelined version in RTL is about 250
lines of Verilog long.

To facilitate working with this there is an assembler (tools/asm.py) that assembles a fairly modern looking syntax into
hex files you can read directly into a test bench.  To genenerate a golden reference mode there is a software simulator 
(tools/sym.py) that produces a hex file that includes the finished memory and register state.

To test a core evolution the simulator can be invoked directly, e.g.:

    make -C sim clean test_cpu CPU=../evos/0/cpu.v HEX=data/example.asm.hex STATE=data/example.asm.state

There's also a very basic top for an ECP5 board that can be used for benching.  To perform a simple PNR:

    make -C impl FREQ=100 CPU=../evos/0/cpu.v clean toy_cpu.bit

Finally to bench things you can run the run.sh script which will test every core against every demo in data/*.asm and
then binary search for the Fmax of each core.  The output will produce run.log and the console out will resemble

    - V e r i l a t i o n   R e p o r t: Verilator 5.049 devel rev v5.048-298-ge269b914b (mod)
    - Verilator: Built from 0.064 MB sources in 3 modules, into 0.048 MB in 3 C++ files needing 0.000 MB
    - Verilator: Walltime 0.018 s (elab=0.001, cvt=0.007, bld=0.000); cpu 0.013 s on 1 threads; allocated 23.043 MB
    make: Leaving directory '/home/tom/nas/toms_fpga/prj/tsocp/sim'
    Profiling core: ../evos/0/cpu.v
    Attempting Fmax 116...
    Attempting Fmax 158...
    Attempting Fmax 179...
    Attempting Fmax 169...
    Attempting Fmax 174...
    Attempting Fmax 172...
    Attempting Fmax 171...
    Attempting Fmax 170...



    core,copy.asm,example.asm,fill.asm,mult.asm,Fmax,FF,COMB (LUT4),RAMW
    evos/0/cpu.v,2246,451,1509,465,169 MHz,106,312,0

The output columns are the core name, the number of cycles per demo, the Fmax of the basic top, and finally resource
usages including the number of flip flops, LUT4s, and LUT-RAM (RAMW)s.  The goal of the project is to evaluate how various designs impact cycles per demo against Fmax.