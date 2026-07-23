import sys
import re
import argparse

class Sim:
    def __init__(self, hexname: str):
        self.mem = bytearray(256)
        self.R = [0, 0, 0, 0]
        self.PC = 0
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
        insn = opcode >> 4
        rs = (opcode >> 2) & 3
        rd = opcode & 3

        if (insn == 0): # add
            self.R[rs] = (self.R[rs] + self.R[rd]) & 0xFF
            self.ZF = 1 if self.R[rs] == 0 else 0
        elif (insn == 1): # sub
            self.R[rs] = (self.R[rs] - self.R[rd]) & 0xFF
            self.ZF = 1 if self.R[rs] == 0 else 0
        elif (insn == 2): # xor
            self.R[rs] = (self.R[rs] ^ self.R[rd]) & 0xFF
            self.ZF = 1 if self.R[rs] == 0 else 0
        elif (insn == 3): # or
            self.R[rs] = (self.R[rs] | self.R[rd]) & 0xFF
            self.ZF = 1 if self.R[rs] == 0 else 0
        elif (insn == 4): # and
            self.R[rs] = (self.R[rs] & self.R[rd]) & 0xFF
            self.ZF = 1 if self.R[rs] == 0 else 0
        elif (insn == 5): # LDi
            if (rd == 0):
                self.R[rs] = self.mem[self.PC]
            elif (rd == 1): # ADDi
                self.R[rs] = (self.R[rs] + self.mem[self.PC]) & 0xFF
            elif (rd == 2): # SUBi
                self.R[rs] = (self.R[rs] - self.mem[self.PC]) & 0xFF
            elif (rd == 3): # ANDi
                self.R[rs] = (self.R[rs] & self.mem[self.PC]) & 0xFF
            self.ZF = 1 if self.R[rs] == 0 else 0
            self.PC = self.PC + 1
        elif (insn == 6): # LD
            self.R[rs] = self.mem[self.R[rd]]
            self.ZF = 1 if self.R[rs] == 0 else 0
        elif (insn == 7): # ST
            self.mem[self.R[rd]] = self.R[rs]
        elif (insn == 8): # JMP
            if (rd == 0):
                self.PC = self.mem[self.PC]
            elif (rd == 1): # JZ
                if self.ZF == 1:
                    self.PC = self.mem[self.PC]
                else:
                    self.PC = self.PC + 1
            elif (rd == 2): # JNZ
                if self.ZF == 0:
                    self.PC = self.mem[self.PC]
                else:
                    self.PC = self.PC + 1
            elif (rd == 3): # JALR
                self.R[3] = self.PC + 1
                self.PC   = self.mem[self.PC]
		elif (insn == 9): # inc/dec/shr
			if (rd == 0): #inc
				self.R[rs] = (self.R[rs] + 1) & 0xFF
			elif (rd == 1): #dec
				self.R[rs] = (self.R[rs] - 1) & 0xFF
			elif (rd == 2): #shr
				self.R[rs] = (self.R[rs] >> 1) & 0xFF
			self.ZF = 1 if self.R[rs] == 0 else 0
#todo: opcode group 10
        elif (insn == 11): # ret
            if (rd == 0): # ret
                self.PC   = self.R[3]
            elif (rd == 1): #not
                self.R[rs] = (~self.R[rs]) & 0xFF
                self.ZF = 1 if self.R[rs] == 0 else 0
            elif (rd == 2): #neg
                self.R[rs] = (-self.R[rs]) & 0xFF
                self.ZF = 1 if self.R[rs] == 0 else 0
            elif (rd == 3): #swap
                self.R[rs] = ((self.R[rs] << 4) | (self.R[rs] >> 4)) & 0xFF
                self.ZF = 1 if self.R[rs] == 0 else 0
        elif (insn == 12): # SILT
			self.ZF = 1 if (self.R[rs] < self.R[rd]) else 0
        elif (insn == 13): # SIEQ
			self.ZF = 1 if (self.R[rs] == self.R[rd]) else 0
        elif (insn == 14): # SIGT
			self.ZF = 1 if (self.R[rs] > self.R[rd]) else 0
        elif (insn == 15): # halt
            if (rd == 0): # halt
                self.HALT = 1
            elif (rd == 1): # msb
                self.ZF = 1 ^ ((self.R[rs] >> 7) & 1)
            elif (rd == 2): # lsb
                self.ZF = 1 ^ (self.R[rs] & 1)
        self.PC = self.PC & 0xFF
        
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
