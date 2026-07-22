import argparse
import sys
import re

class Assembler:
    def __init__(self):
        self.labels = {}
        self.memory = [0] * 256
        self.opcodes = {
            'ADD': 0,  'SUB': 1,  'XOR': 2,  'OR': 3,
            'AND': 4,  'LDI': 5,  'LD': 6,   'ST': 7,
            'JMP': 8,  'JZ': 9,   'JALR': 10,'RET': 11,
            'SILT': 12,'SIEQ': 13,'SIGT': 14,'HALT': 15,
            'INC': 12, 'DEC': 13  # Aliased opcodes using Rs == Rd encoding
        }
        # 2-byte instructions that consume an immediate byte at PC+1
        self.two_byte_ops = {'LDI', 'JMP', 'JZ', 'JALR'}
        self.regs = {'R0': 0, 'R1': 1, 'R2': 2, 'R3': 3}

    def clean_line(self, line):
        """Remove comments and strip whitespace."""
        line = re.sub(r';.*', '', line)  # Strip semi-colon comments
        line = re.sub(r'//.*', '', line) # Strip double-slash comments
        return line.strip()

    def parse_imm(self, val_str, bits=8, signed=False):
        """Parse integers, hex, or symbol labels into a bounded bit-width immediate."""
        val_str = val_str.strip()
        
        # Resolve symbol if known
        if val_str in self.labels:
            val = self.labels[val_str]
        else:
            try:
                if val_str.lower().startswith('0x'):
                    val = int(val_str, 16)
                else:
                    val = int(val_str)
            except ValueError:
                raise ValueError(f"Unknown symbol or invalid integer: '{val_str}'")

        # Bounds checks
        if signed:
            min_val = -(1 << (bits - 1))
            max_val = (1 << (bits - 1)) - 1
            if not (min_val <= val <= max_val):
                raise ValueError(f"Immediate {val} out of signed {bits}-bit range ({min_val} to {max_val})")
            return val & ((1 << bits) - 1)
        else:
            max_val = (1 << bits) - 1
            if not (0 <= val <= max_val):
                raise ValueError(f"Immediate {val} out of unsigned {bits}-bit range (0 to {max_val})")
            return val

    def assemble(self, source_code):
        lines = source_code.splitlines()
        
        # Reset internal state
        self.labels = {}
        self.memory = [0] * 256
        
        # --- PASS 1: Calculate PC offsets and record Label addresses ---
        pc = 0
        cleaned_lines = []
        
        for line_num, raw_line in enumerate(lines, 1):
            line = self.clean_line(raw_line)
            if not line:
                continue
                
            # Check for label declaration (e.g., "my_loop:" or "data_table:")
            label_match = re.match(r'^([a-zA-Z_][a-zA-Z0-9_]*):(.*)', line)
            if label_match:
                label_name = label_match.group(1)
                if label_name in self.labels:
                    raise SyntaxError(f"Line {line_num}: Redefinition of label '{label_name}'")
                self.labels[label_name] = pc
                line = label_match.group(2).strip()
                if not line:
                    continue  # Label-only line
            
            # Check for ORG directive
            org_match = re.match(r'^\.ORG\s+(.+)', line, re.IGNORECASE)
            if org_match:
                pc = self.parse_imm(org_match.group(1), 8, signed=False)
                continue

            cleaned_lines.append((line_num, pc, line))
            
            # Determine byte size for PC advancement
            tokens = [t.strip() for t in re.split(r'[\s,]+', line) if t.strip()]
            first_token = tokens[0].upper()

            if first_token in self.two_byte_ops:
                pc += 2
            elif first_token in ('.DB', '.BYTE'):
                pc += len(tokens[1:])
            else:
                # 1-byte opcode or raw data byte/symbol
                pc += 1

            if pc > 256:
                raise MemoryError("Program size exceeded the 256-byte memory limit!")

        # --- PASS 2: Encode Instructions and Data Bytes ---
        for line_num, instr_pc, line in cleaned_lines:
            tokens = [t.strip() for t in re.split(r'[\s,]+', line) if t.strip()]
            if not tokens:
                continue
                
            op = tokens[0].upper()
            
            try:
                # 1. Single-Register Ops: INC / DEC (Overloaded Rs == Rd)
                if op in ['INC', 'DEC']:
                    if len(tokens) < 2:
                        raise SyntaxError(f"Opcode {op} expects a target register")
                    reg = tokens[1].upper()
                    if reg not in self.regs:
                        raise SyntaxError(f"Invalid register: {reg}")
                    
                    reg_idx = self.regs[reg]
                    opcode_bits = self.opcodes[op]
                    # Encode as opcode_bits | Rs=reg | Rd=reg
                    byte_val = (opcode_bits << 4) | (reg_idx << 2) | reg_idx
                    self.memory[instr_pc] = byte_val

                # 2. Two-Register ALU / Memory Ops (1 Byte: Ins[7:4], Rs[3:2], Rd[1:0])
                elif op in ['ADD', 'SUB', 'XOR', 'OR', 'AND', 'LD', 'ST', 'SILT', 'SIEQ', 'SIGT']:
                    if len(tokens) < 3:
                        raise SyntaxError(f"Opcode {op} expects Rs and Rd registers")
                    rs, rd = tokens[1].upper(), tokens[2].upper()
                    if rs not in self.regs or rd not in self.regs:
                        raise SyntaxError(f"Invalid registers: {rs}, {rd}")
                        
                    opcode_bits = self.opcodes[op]
                    byte_val = (opcode_bits << 4) | (self.regs[rs] << 2) | self.regs[rd]
                    self.memory[instr_pc] = byte_val

                # 3. LDI Instruction (2 Bytes: Byte0 = Ins[7:4] | Rs[3:2], Byte1 = imm)
                elif op == 'LDI':
                    if len(tokens) < 3:
                        raise SyntaxError("LDI expects a register and an immediate/symbol value")
                    rs = tokens[1].upper()
                    if rs not in self.regs:
                        raise SyntaxError(f"Invalid register: {rs}")
                        
                    imm = self.parse_imm(tokens[2], 8, signed=False)
                    opcode_bits = self.opcodes['LDI']
                    
                    self.memory[instr_pc]     = (opcode_bits << 4) | (self.regs[rs] << 2)
                    self.memory[instr_pc + 1] = imm

                # 4. Control Flow Jumps (2 Bytes: Byte0 = Ins[7:4], Byte1 = target imm/label)
                elif op in ['JMP', 'JZ', 'JALR']:
                    if len(tokens) < 2:
                        raise SyntaxError(f"{op} expects a target address or symbol")
                    
                    target_addr = self.parse_imm(tokens[1], 8, signed=False)
                    opcode_bits = self.opcodes[op]
                    
                    self.memory[instr_pc]     = (opcode_bits << 4)
                    self.memory[instr_pc + 1] = target_addr

                # 5. Single-Byte Control Ops (1 Byte: Ins[7:4])
                elif op == 'RET':
                    self.memory[instr_pc] = (self.opcodes['RET'] << 4)
                elif op == 'HALT':
                    self.memory[instr_pc] = (self.opcodes['HALT'] << 4)

                # 6. Data Directives (.DB / .BYTE)
                elif op in ('.DB', '.BYTE'):
                    for idx, data_token in enumerate(tokens[1:]):
                        val = self.parse_imm(data_token, 8, signed=False)
                        self.memory[instr_pc + idx] = val

                # 7. Raw Data / Symbol Literals (e.g. "0xFF", "42", or "my_label")
                else:
                    byte_val = self.parse_imm(tokens[0], 8, signed=False)
                    self.memory[instr_pc] = byte_val

            except Exception as e:
                print(f"Assembly Error on Line {line_num} (PC={instr_pc}): {e}")
                sys.exit(1)

        return self.memory

    def write_hex(self, filename):
        """Writes standard Verilog $readmemh compatible file."""
        with open(filename, 'w') as f:
            for byte in self.memory:
                f.write(f"{byte:02X}\n")
# --- Example Execution Usage ---
if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Assemble Toy ISA to Hex format"
    )
    parser.add_argument(
        'filename', 
        type=str, 
        help="file to assemble"
    )

    args = parser.parse_args()
    with open(args.filename, "r") as f:
        program = f.read();
    compiler = Assembler();
    mem_dump = compiler.assemble(program);
    hexname = args.filename + ".hex"
    compiler.write_hex(hexname)
    print(f"Assembly complete! '{hexname}' generated successfully.")
