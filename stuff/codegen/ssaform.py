#!/usr/bin/python3
# 
# #  LLVM SSA IR => Data Structures
#
# At the top we have a ssaModule class that organizes everything inside a module.
# Inside a ssaModule we have (among other things) a list of ssaFunction's
# Inside a ssaFunction are a list of ssaBlocks
# Inside a ssaBlock are a list of ssaInstructions
import re

# read a file, split into lines, split into space delimited tokens
# provides iterable that returns a prepped line of text at time
class tokener:
    def __init__(self, fname: str):
        with open(fname, "r") as f:
            self.file = f.read()
        self.lines = self.file.split("\n")
        for i in range(len(self.lines)):
            self.lines[i] = re.sub(r'([^\w\s])', r' \1 ', self.lines[i])
        self.linenum = 0

    def __iter__(self):
        # Return the iterator object itself
        return self

    def __next__(self) -> str:
        # Check if we have more lines to read
        if self.linenum < len(self.lines):
            current_line = self.lines[self.linenum]
            self.linenum += 1  # Increment for next time
            return current_line
        else:
            # Raise StopIteration when done
            raise StopIteration

    def rewind(self, tgt: int = 0):
        if (tgt):
            self.linenum -= tgt
        else:
            self.linenum = 0

# Container of a module
class ssaModule:
    def __init__(self, tok: tokener):
        self.tok = tok
        self.functions = []
        self.parse()

    # Parse the module fully
    def parse(self):
        pass

# Container of a function inside a module
class ssaFunction:
    def __init__(self, tok: tokener):
        self.tok          = tok
        self.blocks       = []
        self.parse()

    def parse(self):
        pass

# Container of a block inside a function
class ssaBlock:
    def __init__(self, tok: tokener):
        self.tok          = tok
        self.instructions = []          # list of instructions in this block
        self.toblocks     = []          # list of blocks we jump to from this block
        self.fromblocks   = []          # list of blocks we jump from to this block
        self.parse()

    def parse(self):
        pass

# Container of an instruction in a block
class ssaInstruction:
    def __init__(self, line: str):
        self.line         = line
        self.dest_reg     = []          # list containing info about the destination register
        self.operand_regs = []          # list containing lists containing info about operands
        self.dead_regs    = []          # list containing dead registers at this point
        self.inst         = []          # list containing info about the instruction itself
        self.parse()

    def parse(self):
        pass

if __name__ == "__main__":
    t = tokener("ssaform.py")
    for l in t:
        print(f"line: [{l}]")
    
