import sys
import re
import argparse

class Sim:
    def __init__(self, hexname: str):
        self.mem = bytearray(256)
        self.R = [0, 0, 0, 0]
        self.PC = 32
        self.ZF = 0
        self.HALT = 0
        self.trace = 0
        self.opcodes = 0

        with open(hexname, "r") as f:
            hexlines = f.read().split("\n")
            x = 0
            while (x < 256):
                self.mem[x] = int(hexlines[x], base=16)
                x = x + 1
    
    def runTillHalt(self):
        while (self.HALT == 0):
            self.step()

    def step(self):
        self.opcodes = self.opcodes + 1
        opcode = self.mem[self.PC]
        if self.trace == 1:
            print(f"PC={self.PC:02X} R=[{self.R[0]:02X}, {self.R[1]:02X}, {self.R[2]:02X}, {self.R[3]:02X}], ZF={self.ZF:02X}")
        self.PC = self.PC + 1
        insn = opcode >> 5
        rs = (opcode >> 2) & 3
        rd = opcode & 3
        simm5 = opcode & 0x1F
        if (simm5 & 0x10):
            simm5 = simm5 | 0xF0 # sign extend
        uimm5 = opcode & 0x1F
        if (insn == 0): # add
            self.R[rs] = (self.R[rs] + self.R[rd]) & 0xFF
            self.ZF = 1 if self.R[rs] == 0 else 0
        elif (insn == 1): # sub
            self.R[rs] = (self.R[rs] - self.R[rd]) & 0xFF
            self.ZF = 1 if self.R[rs] == 0 else 0
        elif (insn == 2): # LDi
            self.R[0] = uimm5
            self.ZF = 1 if self.R[0] == 0 else 0
        elif (insn == 3): # LD
            self.R[rs] = self.mem[self.R[rd]]
            self.ZF = 1 if self.R[rs] == 0 else 0
        elif (insn == 4): # ST
            self.mem[self.R[rd]] = self.R[rs]
        elif (insn == 5): # JMP
            self.PC = (self.PC - 1 + simm5) & 0xFF
        elif (insn == 6): # JZ
            if self.ZF:
                self.PC = (self.PC - 1 + simm5) & 0xFF
        elif (insn == 7): # halt
            self.HALT = 1
        
    def emitstate(self, sfname: str):
        with open(sfname, "w") as f:
            # write mem
            x = 0
            while (x < 256):
                f.write(f"{self.mem[x]:02X}\n")
                x = x + 1
            # now write PC, R 0..3, ZF
            f.write(f"{self.PC:02X}\n")
            f.write(f"{self.R[0]:02X}\n")
            f.write(f"{self.R[1]:02X}\n")
            f.write(f"{self.R[2]:02X}\n")
            f.write(f"{self.R[3]:02X}\n")
            f.write(f"{self.ZF:02X}\n")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Simulate Toy ISA from Hex format"
    )
    parser.add_argument(
        'filename', 
        type=str, 
        help="assembly file to sim (assumes matching hex generated)"
    )

    args = parser.parse_args()

    hexname = args.filename + ".hex"
    sname   = args.filename + ".state"

    sim = Sim(hexname)
#    sim.trace = 1
    sim.runTillHalt()
    sim.emitstate(sname)
    print(f"Simulation of {hexname} done in {sim.opcodes} instructions.")
