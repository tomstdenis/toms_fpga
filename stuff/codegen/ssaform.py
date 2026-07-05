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
        self.olines = []
        for i in range(len(self.lines)):
            self.olines.append(self.lines[i])
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

    def find_function(self, name: str) -> ssaFunction:
        for f in self.functions:
            if f.funcname == name:
                return f
        return None

    # Parse the module fully
    def parse(self):
        for line in self.tok:
            toks = line.split()
            if toks and toks[0] != ";":
                # not a comment
                if (toks[0] == 'define'):
                    self.tok.rewind(1)
                    self.functions.append(ssaFunction(self.tok))
                #else:
                #    print(f"Module: [{line}]")

    def render(self):
        for f in self.functions:
            f.render()

# Container of a function inside a module
class ssaFunction:
    def __init__(self, tok: tokener):
        self.tok          = tok
        self.blocks       = []
        self.cur_block    = 0
        self.funcname     = ""
        self.funcdef      = ""
        self.funcargs     = []
        self.scope        = []
        self.addr         = []
        self.parse()

    def find_block(self, blockno: int) -> ssaBlock:
        for b in self.blocks:
            if b.blockno == blockno:
                return b
        return None

    def parse(self):
        # parse define line starts with define and ends with a { but can span multiple lines
        funcdef = []
        done = False
        toks = None
        x = 0
        while not done:
            if (toks == None or x == len(toks)):
                toks = self.tok.__next__().split()
                x = 0
            if (toks[x] == '{'):
                done = True
            else:
                funcdef.append(toks[x])
            x += 1

        # parse from define to @
        x = 0
        while (x < len(funcdef) and funcdef[x] != '@'):
            self.scope.append(funcdef[x])
            x += 1
        if (funcdef[x] == '@'):
            x += 1

        # next token is funcname
        self.funcname = funcdef[x]
        x += 1

        # expect a '('
        if (funcdef[x] != '('):
            raise Exception("Expect (")
        x += 1

        # now we either have a ) or parameters
        if (x < len(funcdef) and funcdef[x] == ')'):
            x += 1
        else:
            param = []
            seenreg = False
            while (x < len(funcdef) and not (seenreg and funcdef[x] == ')')):
                if (funcdef[x] == '%'):
                    seenreg = True
                if (funcdef[x] == ','):
                    self.funcargs.append(param)
                    param = []
                    seenreg = False
                else:
                    param.append(funcdef[x])
                x += 1
            if (x < len(funcdef) and funcdef[x] == ')'):
                x += 1
            if len(param):
                self.funcargs.append(param)

            for p in self.funcargs:
                y = 0
                while (y < len(p)-1):
                    if p[y] == '%':
                        self.cur_block = str(int(p[y+1]) + 1)
                        break
                    y += 1
        
        # capture any scoping that comes after params
        while (x < len(funcdef) and funcdef[x] != '{'):
            self.addr.append(funcdef[x])
            x += 1

        # parse blocks 
        self.blocks.append(ssaBlock(self.tok, self.cur_block))
        for line in self.tok:
            toks = line.split()
            if (toks):
                if (toks[0] == '}'):
                    #print(f"Function: {line}")
                    break
                else:
                    #are we parsing a new block?
                    if (re.match(r"[0-9]+", toks[0]) and toks[1] == ':'):
                        self.cur_block = int(toks[0])
                    self.blocks.append(ssaBlock(self.tok, self.cur_block))

        changed = True
        while changed:
            changed = False
            for b in self.blocks:           # over all blocks
                for t in b.toblocks:        # over all blocks it jumps to
                    bb = self.find_block(int(t))
                    if bb and int(b.blockno) not in bb.fromblocks:
                        bb.fromblocks.append(int(b.blockno))
                        changed = True

    def render(self):
        print(f"{self.scope} {self.funcname}({self.funcargs}) {self.addr} " + "{")
        for b in self.blocks:
            b.render()
        print("}")

# Container of a block inside a function
class ssaBlock:
    def __init__(self, tok: tokener, blockno: int = 0):
        self.tok          = tok
        self.blockno      = blockno
        self.instructions = []          # list of instructions in this block
        self.toblocks     = []          # list of blocks we jump to from this block
        self.fromblocks   = []          # list of blocks that jump to this block
        self.parse()

    def oper_slots(self, reg: int) -> []:
        insts = []
        for i in range(len(self.instructions)):
            if reg in self.instructions[i].oper:
                insts.append(i)
        return insts

    def parse(self):
        # append instructions until we hit a } or num:
        #print(f"\n\n\nParsing new block %{self.blockno}:\n") 
        for line in self.tok:
            toks = line.split()
            if (toks):
                if ((re.match(r"[0-9]+", toks[0]) and toks[1] == ':') or toks[0] == "}"):
                    self.tok.rewind(1)
                    break
                else:
                    self.instructions.append(ssaInstruction(line))
        # merge all the blocks this block jumps to
        for i in self.instructions:
            for t in i.toblocks:
                if not t in self.toblocks and self.blockno != int(t[1]):
                    self.toblocks.append(int(t[1]))

    def render(self):
        print(f"%{self.blockno}: ; (toblocks={self.toblocks}, fromblocks={self.fromblocks})")
        for i in self.instructions:
            i.render()

# Container of an instruction in a block
class ssaInstruction:
    def __init__(self, line: str):
        self.line         = line
        self.dest_reg     = []          # list containing info about the destination register
        self.operand_regs = []          # list containing lists containing info about operands
        self.dead_regs    = []          # list containing dead registers at this point
        self.inst         = []          # list containing info about the instruction itself
        self.toblocks     = []          # branch targets for this instruction
        self.parse()

    def expect(self, tok: str, expect: str):
        if (tok != expect):
            print(f"Expected {expect}, got {tok}")

    def parse(self):
        toks = self.line.split()
        x = 0
        if (toks):
            # capture destination reg is any
            if (toks[0] == '%' and re.match("[0-9]+", toks[1])):
                self.dest_reg.append(int(toks[1]))
                self.expect(toks[2], "=")
                x = 3
            else:
                x = 0
            # start parsing line at token x
            self.inst.append(toks[x])
            x += 1
            # parse rest of instruction
            # [ "phi", ["regtype"], [[value], [block]], ...
            if (self.inst[0] == "phi"):
                # handle phi
                # parse phi storage type
                phitype = []
                while (toks[x] != '['):
                    phitype.append(toks[x])
                    x += 1
                self.inst.append(phitype)

                # parse source pairs [ value, block ], ...
                while (x < len(toks) and toks[x] == '['):
                    x += 1
                    value = []
                    block = []
                    while (toks[x] != ','):
                        value.append(toks[x])
                        x += 1
                    x += 1
                    # is the value an operand
                    y = 0
                    while (y < (len(value) - 1)):
                        if (value[y] == '%'):
                            self.operand_regs.append(int(value[y + 1]))
                            break
                        y += 1
                    while (toks[x] != ']'):
                        block.append(toks[x])
                        x += 1
                    x +=1
                    if (x < len(toks) and toks[x] == ','):
                        x += 1
                    self.inst.append([value, block])
            # [ "br", [muxsel], [label], ... ]
            # [ "br", [label] ]
            elif (self.inst[0] == "br"):
                # read muxsel into inst[1]
                muxsel = []
                if (toks[x] != 'label'):
                    while (toks[x] != ','):
                        muxsel.append(toks[x])
                        x += 1
                    x += 1
                    self.inst.append(muxsel)
                    y = 0
                    while (y < len(muxsel) - 1):
                        if (muxsel[y] == '%'):
                            self.operand_regs.append(int(muxsel[y+1]))
                            break
                        y += 1
                # labels 
                while (x < len(toks) and toks[x] == 'label'):
                    label = []
                    while (x < len(toks) and toks[x] != ','):
                        label.append(toks[x])
                        x += 1
                    self.inst.append(label)
                    self.toblocks.append(label[1:])
                    if (x < len(toks) and toks[x] == ','):
                        x += 1
            elif (self.inst[0] == "select"):
                # read muxsel into inst[1]
                muxsel = []
                while (toks[x] != ','):
                    muxsel.append(toks[x])
                    x += 1
                x += 1
                self.inst.append(muxsel)
                y = 0
                while (y < len(muxsel) - 1):
                    if (muxsel[y] == '%'):
                        self.operand_regs.append(int(muxsel[y+1]))
                        break
                    y += 1

                # operands
                while (x < len(toks)):
                    oper = []
                    while (x < len(toks) and toks[x] != ','):
                        oper.append(toks[x])
                        x += 1
                    self.inst.append(oper)
                    y = 0
                    while (y < (len(oper) - 1)):
                        if (oper[y] == '%'):
                            self.operand_regs.append(int(oper[y+1]))
                        y += 1
                    if (x < len(toks) and toks[x] == ','):
                        x += 1
            else: # default is multi operand instructions
                # operands
                while (x < len(toks)):
                    oper = []
                    while (x < len(toks) and toks[x] != ','):
                        oper.append(toks[x])
                        x += 1
                    self.inst.append(oper)
                    y = 0
                    while (y < (len(oper) - 1)):
                        if (oper[y] == '%'):
                            self.operand_regs.append(int(oper[y+1]))
                        y += 1
                    if (x < len(toks) and toks[x] == ','):
                        x += 1
                
    def render(self):
        #print(f"\t{self.line} | ", end='')
        print(f"(inst={self.inst}, dest={self.dest_reg}, oper={self.operand_regs}, toblocks={self.toblocks})")

if __name__ == "__main__":
    mod = ssaModule(tokener("ssa/shiftadd.ll"))    
    print("mod.render():")
    mod.render()