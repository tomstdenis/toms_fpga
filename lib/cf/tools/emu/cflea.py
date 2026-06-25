import sys
import threading, queue

key_queue = queue.Queue()

def keyboard_thread():
    while True:
        try:
            if sys.platform == "win32":
                ch = msvcrt.getch().decode('ascii', errors='ignore')
            else:
                ch = sys.stdin.read(1)
            key_queue.put_nowait(ch)
        except Exception:
            break

class CFLEA:
    def __init__(self):
        self.mem = bytearray(65536)
        self.PC = 0
        self.SP = 0
        self.INDEX = 0
        self.ALT = 0
        self.ACC = 0
        self.R0 = 0
        self.R1 = 0
        self.flags = {'EQ': False, 'SLT': False, 'SGT': False, 'ULT': False, 'UGT': False}

    def load(self, fname: str, entry: int, base: int):
        with open(fname, 'rb') as f:
            code = f.read()
        
        if len(code) + base > 65536:
            raise OverflowError(f"Loading past the end of CFLEA memory: {len(code) + entry}...")
        
        self.mem[base: base + len(code)] = code
        self.PC = entry
    
    def fetch_operand(self, addr: int, word: int) -> int:
        p = addr & 0xFFFF
        np = (p + 1) & 0xFFFF
        if word:
            return self.mem[p] | (self.mem[np] << 8)
        else:
            return self.mem[p]

    def store_operand(self, addr: int, word: int, value: int) -> int:
        p = addr & 0xFFFF
        np = (p + 1) & 0xFFFF
        if word:
            self.mem[np] = (value >> 8) & 0xFF
        self.mem[p] = value & 0xFF

    def opcode_alu(self, opcode: int):
        mod = opcode & 7
        word = 0 if (opcode & 8) else 1

        # shift operands are always bytes
        if (opcode >= 0xB8 and opcode <= 0xC7):
            word = 0

        if mod == 0:
            # immediate (IIII)
            operand = self.fetch_operand(self.PC, word)
            self.PC += (1 + word)
        elif mod == 1:
            # memory load (aaaa)
            operand = self.fetch_operand(self.fetch_operand(self.PC, 1), word)
            self.PC += (2)
        elif mod == 2:
            # indirect I
            operand = self.fetch_operand(self.INDEX, word)
        elif mod == 3:
            # n,I
            operand = self.fetch_operand(self.INDEX + self.fetch_operand(self.PC, 0), word)
            self.PC += (1)
        elif mod == 4:
            # n,S
            operand = self.fetch_operand(self.SP + self.fetch_operand(self.PC, 0), word)
            self.PC += (1)
        elif mod == 5:
            # S+
            operand = self.fetch_operand(self.SP, 1)
            self.SP += 2
        elif mod == 6:
            # [S+]
            operand = self.fetch_operand(self.fetch_operand(self.SP, 1), word)
            self.SP += 2
        elif mod == 7:
            # [S]
            operand = self.fetch_operand(self.fetch_operand(self.SP, 1), word)

        # now deal with the instruction
        op = opcode & 0xF0
        if op == 0x00:
            # LD
            self.ACC = operand
        elif op == 0x10:
            # ADD
            self.ACC += operand
        elif op == 0x20:
            # SUB
            self.ACC -= operand
        elif op == 0x30:
            # MUL
            self.ACC *= operand
            self.ALT = self.ACC >> 16
            self.ACC = self.ACC & 0xFFFF
        elif op == 0x40:
            # DIV
            self.ALT = self.ACC % operand
            self.ACC = self.ACC // operand
        elif op == 0x50:
            # AND
            self.ACC &= operand
        elif op == 0x60:
            # OR
            self.ACC |= operand
        elif op == 0x70:
            # XOR
            self.ACC ^= operand
        elif op == 0x80:
            # CMP
            self.flags['EQ'] = True if self.ACC == operand else False
            self.flags['SLT'] = True if self.ACC < operand else False
            self.flags['SGT'] = True if self.ACC > operand else False
            self.flags['ULT'] = True if self.ACC > operand else False
            self.flags['UGT'] = True if self.ACC < operand else False
            self.ACC = 1 if self.ACC == operand else 0
        elif op == 0x90:
            # LDI
            self.INDEX = operand
        else:
            if (opcode & 0xF8) == 0xB8:
                self.ACC = self.ACC >> operand
            elif (opcode & 0xF8) == 0xC0:
                self.ACC = self.ACC << operand

    def opcode_mem(self, opcode: int):
        # LEAI, ST, STB, STI
        mod = opcode & 7

        if mod == 1:
            # memory store (aaaa)
            operand = self.fetch_operand(self.PC, 1)
            self.PC += (2)
        elif mod == 2:
            # indirect I
            operand = self.INDEX
        elif mod == 3:
            # n,I
            operand = self.INDEX + self.fetch_operand(self.PC, 0)
            self.PC += (1)
        elif mod == 4:
            # n,S
            operand = self.SP + self.fetch_operand(self.PC, 0)
            self.PC += (1)
        elif mod == 6:
            # [S+]
            operand = self.SP
            if not ((opcode & 0xF8) == 0x98):
                self.SP += 2
        elif mod == 7:
            # [S]
            operand = self.SP

        op = opcode & 0xF8
       
        if op == 0x98:
            # LEAI
            self.INDEX = operand
        elif op == 0xA0:
            # ST
            self.store_operand(operand, 1, self.ACC)
        elif op == 0xA8:
            # STB
            self.store_operand(operand, 0, self.ACC)
        elif op == 0xB0:
            # STI
            self.store_operand(operand, 1, self.INDEX)

    def opcode_compare(self, opcode: int):
        # ULT, UGT, ...
        if (opcode == 0xC8):
            self.ACC = 1 if self.flags['SLT'] else 0
        elif (opcode == 0xC9):
            self.ACC = 1 if self.flags['SLT'] or self.flags['EQ'] else 0
        elif (opcode == 0xCA):
            self.ACC = 1 if self.flags['SGT'] else 0
        elif (opcode == 0xCB):
            self.ACC = 1 if self.flags['SGE'] or self.flags['EQ'] else 0
        elif (opcode == 0xCC):
            self.ACC = 1 if self.flags['ULT'] else 0
        elif (opcode == 0xCD):
            self.ACC = 1 if self.flags['ULE'] or self.flags['EQ'] else 0
        elif (opcode == 0xCE):
            self.ACC = 1 if self.flags['UGT'] else 0
        elif (opcode == 0xCF):
            self.ACC = 1 if self.flags['UGE'] or self.flags['EQ'] else 0

    def opcode_jumps(self, opcode: int):
        if (opcode == 0xD0):
            # JMP
            self.PC = self.fetch_operand(self.PC, 1)
        elif (opcode == 0xD1):
            # JZ
            if (self.ACC == 0):
                self.PC = self.fetch_operand(self.PC, 1)
            else:
                self.PC += (2)
        elif (opcode == 0xD2):
            # JNZ
            if (self.ACC != 0):
                self.PC = self.fetch_operand(self.PC, 1)
            else:
                self.PC += (2)
        elif (opcode == 0xD3):
            # SJMP
            sPC = self.fetch_operand(self.PC, 0)
            if (sPC & 0x80):
                sPC |= 0xFF00
            self.PC += (sPC + 1)
        elif (opcode == 0xD4):
            # SJZ
            sPC = self.fetch_operand(self.PC, 0)
            if (sPC & 0x80):
                sPC |= 0xFF00
            if (self.ACC == 0):
                self.PC += (sPC + 1)
            else:
                self.PC += (1)                
        elif (opcode == 0xD5):
            # SJNZ
            sPC = self.fetch_operand(self.PC, 0)
            if (sPC & 0x80):
                sPC |= 0xFF00
            if (self.ACC != 0):
                self.PC += (sPC + 1)
            else:
                self.PC += (1)                
        elif (opcode == 0xD6):
            # IJMP
            self.PC = self.ACC
        elif (opcode == 0xD7):
            # SWITCH (why Dave, why...)
            sw = 0
            while True:
                saddr = self.fetch_operand(self.INDEX + sw, 1)
                sval  = self.fetch_operand(self.INDEX + sw + 2, 1)
                if saddr == 0:
                    # default option
                    self.PC = sval
                    break
                elif sval == self.ACC:
                    # matches entry
                    self.PC = saddr
                    break
                sw += 4
        elif (opcode == 0xD8):
            # CALL
            self.SP -= 2
            self.store_operand(self.SP, 1, self.PC + 2)
            self.PC = self.fetch_operand(self.PC, 1)
        elif (opcode == 0xD9):
            # RET
            self.PC = self.fetch_operand(self.SP, 1)
            self.SP += 2

    def opcode_stack(self, opcode: int):
        if opcode == 0xDA:
            # ALLOC
            self.SP -= self.fetch_operand(self.PC, 0)
            self.PC += (1)
        elif opcode == 0xDB:
            # FREE
            self.SP += self.fetch_operand(self.PC, 0)
            self.PC += 1
        elif opcode == 0xDC:
            # PUSHA
            self.SP -= 2
            self.store_operand(self.SP, 1, self.ACC)
        elif opcode == 0xDD:
            # PUSHI
            self.SP -= 2
            self.store_operand(self.SP, 1, self.INDEX)
        elif opcode == 0xDE:
            # TAS
            self.SP = self.ACC
        elif opcode == 0xDF:
            # TSA
            self.ACC = self.SP

    def opcode_misc(self, opcode: int):
        if opcode == 0xE0:
            self.ACC = 0
        elif opcode == 0xE2:
            self.ACC ^= 0xFFFF
        elif opcode == 0xE3:
            self.ACC = 65536 - self.ACC
        elif opcode == 0xE4:
            self.ACC += 1
        elif opcode == 0xE5:
            self.ACC -= 1
        elif opcode == 0xE6:
            self.INDEX = self.ACC
        elif opcode == 0xE7:
            self.ACC = self.INDEX
        elif opcode == 0xE8:
            self.INDEX += self.ACC
        elif opcode == 0xE9:
            self.ACC = self.ALT
        elif opcode == 0xEA:
            # OUT
            port = self.fetch_operand(self.PC, 0)
            self.PC += 1
            if (port == 0):
                print(chr(self.ACC & 0xFF), end='')
        elif opcode == 0xEB:
            # IN
            port = self.fetch_operand(self.PC, 0)
            self.PC += 1
            if (port == 0):
                try:
                    self.ACC = ord(key_queue.get_nowait()) & 0xFF
                except queue.Empty:
                    self.ACC = 0xFFFF
            else:
                self.ACC = 0
        elif opcode == 0xED:
            # CPUID
            self.ACC = 0
        elif opcode == 0xEE:
            # RDTSC
            self.ACC = 0
        elif opcode == 0xEF:
            # TAR0
            self.R0 = self.ACC
        elif opcode == 0xF0:
            # TAR1
            self.R1 = self.ACC
        elif opcode == 0xF1:
            # TR0A
            self.ACC = self.R0
        elif opcode == 0xF2:
            # TR1A
            self.ACC = self.R1
        elif opcode == 0xF3:
            # SWAPR0
            tmp = self.ACC
            self.ACC = self.R0
            self.R0 = tmp
        elif opcode == 0xF4:
            # SWAPR1
            tmp = self.ACC
            self.ACC = self.R1
            self.R1 = tmp
        elif opcode == 0xF5:
            # DEC_R0_A
            self.R0 -= 1
            self.ACC = self.R0
        elif opcode == 0xF6:
            # DEC_R1_A
            self.R1 -= 1
            self.ACC = self.R1
        elif opcode == 0xF7:
            # ADAR0
            self.R0 += self.ACC
        elif opcode == 0xF8:
            # ADAR1
            self.R1 += self.ACC
        elif opcode == 0xF9:
            # INCR0I
            self.R0 += 1
            self.INDEX = self.R0
        elif opcode == 0xFA:
            # INCR0I
            self.R1 += 1
            self.INDEX = self.R1

    # step the cpu one instruction
    def step(self, log: bool = False):
        # read opcode byte
        opcode = self.mem[self.PC]

        if log is True:
            print(f"OPCODE={opcode:#04x} PC={self.PC:#06x} ACC={self.ACC:#06x} INDEX={self.INDEX:#06x} SP={self.SP:#06x} ALT={self.ALT:#06x} R0={self.R0:#06x} R1={self.R1:#06x}")

        self.PC += 1

        if opcode <= 0x97 or (opcode >= 0xB8 and opcode <= 0xC7):
            # ALU opcodes
            self.opcode_alu(opcode)
        elif opcode <= 0xB7:
            # LEAI, ST, STB, STI
            self.opcode_mem(opcode)
        elif opcode <= 0xCF:
            # LT/ULT/...
            self.opcode_compare(opcode)
        elif opcode <= 0xD9:
            # jumps
            self.opcode_jumps(opcode)
        elif opcode <= 0xDF:
            # stack
            self.opcode_stack(opcode)
        else:
            # misc
            self.opcode_misc(opcode)

        self.SP    &= 0xFFFF
        self.ACC   &= 0xFFFF
        self.PC    &= 0xFFFF
        self.INDEX &= 0xFFFF
        self.R0    &= 0xFFFF
        self.R1    &= 0xFFFF
        self.ALT   &= 0xFFFF

    def run(self, steps: int = 0, log: bool = False):
        step = 0
        while steps == 0 or (step < steps):
            self.step(log=log)
            step += 1

    def run_till(self, targetPC: int, log: bool = False):
        while self.PC != targetPC:
            self.step(log=log)

if __name__ == "__main__":
    threading.Thread(target=keyboard_thread, daemon=True).start()
    cf = CFLEA()
    cf.load(fname="cf/bios.cf", entry=0xF000, base=0xF000)
    cf.run(log=False)
