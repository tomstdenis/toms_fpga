import sys
import re
import argparse

class Assembler:
    def __init__(self):
        self.labels = {}
        self.memory = [0] * 256
        self.opcodes = {
            'ADD': 0, 'SUB': 1, 'LDI': 2, 
            'LD': 3,  'ST': 4,  'JMP': 5, 
            'JZ': 6,  'HALT': 7
        }
        self.regs = {'R0': 0, 'R1': 1, 'R2': 2, 'R3': 3}

    def clean_line(self, line):
        """Remove comments and strip whitespace."""
        line = re.sub(r';.*', '', line) # strip semi-colon comments
        line = re.sub(r'//.*', '', line) # strip double-slash comments
        return line.strip()

    def parse_imm(self, val_str, bits, signed=False):
        """Parse integers, hex, or symbols into a bounded bit-width immediate."""
        val_str = val_str.strip()
        
        # If it's a known label/symbol, resolve its address
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

        # Masking and bounds checks
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
        
        # --- PASS 1: Identify Label Positions and ORG directives ---
        pc = 0
        cleaned_lines = []
        
        for line_num, raw_line in enumerate(lines, 1):
            line = self.clean_line(raw_line)
            if not line:
                continue
                
            # Check for label declaration (e.g., "my_loop:")
            label_match = re.match(r'^([a-zA-Z_][a-zA-Z0-9_]*):(.*)', line)
            if label_match:
                label_name = label_match.group(1)
                if label_name in self.labels:
                    raise SyntaxError(f"Line {line_num}: Redefinition of label '{label_name}'")
                self.labels[label_name] = pc
                line = label_match.group(2).strip()
                if not line:
                    continue # Label-only line
            
            # Check for ORG directive
            org_match = re.match(r'^\.ORG\s+(.+)', line, re.IGNORECASE)
            if org_match:
                # We temporarily parse the ORG expression assuming no forward label symbols are used for ORG
                pc = self.parse_imm(org_match.group(1), 8, signed=False)
                continue
                
            # It's an instruction
            cleaned_lines.append((line_num, pc, line))
            pc += 1
            if pc > 256:
                raise MemoryError("Program size exceeded the 256-byte memory limits!")

        # --- PASS 2: Generate Binary Opcodes ---
        for line_num, instr_pc, line in cleaned_lines:
            # Tokenize by space, commas
            tokens = [t.strip() for t in re.split(r'[\s,]+', line) if t.strip()]
            if not tokens:
                continue
                
            op = tokens[0].upper()
#            if op not in self.opcodes:
#                raise SyntaxError(f"Line {line_num}: Unknown opcode '{op}'")
            if op in self.opcodes:
                opcode_bits = self.opcodes[op]
            else:
                opcode_bits = 0;
            byte_val = 0
            
            try:
                if op in ['ADD', 'SUB', 'LD', 'ST']:
                    # Target layout: Ins[7:5], Rs[3:2], Rd[1:0]
                    if len(tokens) < 3:
                        raise SyntaxError(f"Opcode {op} expects Rs and Rd registers")
                    rs = tokens[1].upper()
                    rd = tokens[2].upper()
                    
                    if rs not in self.regs or rd not in self.regs:
                        raise SyntaxError(f"Invalid registers: {rs}, {rd}")
                        
                    byte_val = (opcode_bits << 5) | (self.regs[rs] << 2) | self.regs[rd]
                    
                elif op == 'LDI':
                    # Target layout: Ins[7:5], uimm5[4:0] (Hardcoded R0 destination)
                    if len(tokens) < 2:
                        raise SyntaxError("LDI expects an immediate value or symbol")
                    uimm5 = self.parse_imm(tokens[1], 5, signed=False)
                    byte_val = (opcode_bits << 5) | uimm5
                    
                elif op in ['JMP', 'JZ']:
                    # Target layout: Ins[7:5], simm5[4:0] (PC relative)
                    if len(tokens) < 2:
                        raise SyntaxError(f"{op} expects a target address or symbol")
                    
                    # Target can be a literal or a label
                    target_str = tokens[1]
                    if target_str in self.labels:
                        # Calculate PC-relative offset: target - current_instruction_pc
                        target_pc = self.labels[target_str]
                        offset = target_pc - instr_pc
                    else:
                        offset = self.parse_imm(target_str, 5, signed=True)
                        
                    simm5 = self.parse_imm(str(offset), 5, signed=True)
                    byte_val = (opcode_bits << 5) | simm5
                    
                elif op == 'HALT':
                    # Target layout: Ins[7:5], all other bits 0
                    byte_val = (opcode_bits << 5)
                else:
                    byte_val = int(tokens[0], base=16)
                    
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