import sys
import argparse
import re

def calculate_symbol_sizes(filename):
    try:
        with open(filename, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
    except FileNotFoundError:
        print(f"Error: The file '{filename}' could not be found.", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error reading file: {e}", file=sys.stderr)
        sys.exit(1)

    # Step 1: Isolate the Symbol Table at the end of the file
    if "SYMBOL TABLE:" in content:
        symbol_data = content.split("SYMBOL TABLE:")[1]
    else:
        print("Error: Could not find 'SYMBOL TABLE:' header in the listing file.", file=sys.stderr)
        sys.exit(1)

    # Step 2: Regex to match SymbolName followed by optional spaces, a hyphen, and HexAddress
    pattern = re.compile(r'([A-Za-z0-9_?]+)\s*-([0-9A-Fa-f]+)')
    matches = pattern.findall(symbol_data)

    user_symbols = {}

    # Step 3: Extract and Filter
    for name, addr_hex in matches:
        # Ignore compiler/library internals starting with '?'
        if name.startswith('?'):
            continue
            
        addr = int(addr_hex, 16)
        
        # Filter out RAM variables and IO registers below the ORG $1000 segment
        if addr >= 0x1000:
            user_symbols[name] = addr

    if not user_symbols:
        print("No user symbols (>= 0x1000) found in the symbol table.")
        return

    # Step 4: Sort by address first to compute accurate linear deltas
    sorted_by_addr = [{'name': k, 'addr': v} for k, v in user_symbols.items()]
    sorted_by_addr.sort(key=lambda x: x['addr'])

    # Step 5: Process spans into a list of dictionaries
    processed_symbols = []
    for i in range(len(sorted_by_addr)):
        curr = sorted_by_addr[i]
        
        if i + 1 < len(sorted_by_addr):
            nxt = sorted_by_addr[i+1]
            size = nxt['addr'] - curr['addr']
            next_boundary = f"0x{nxt['addr']:04X}"
            size_str = str(size)
        else:
            # Sentinel value (-1) for sorting the unknown last element to the bottom
            size = -1 
            next_boundary = "0x????"
            size_str = "Unknown (Last)"

        processed_symbols.append({
            'name': curr['name'],
            'start_addr': curr['addr'],
            'next_boundary': next_boundary,
            'size_bytes': size,
            'size_display': size_str
        })

    # Step 6: Sort by size (Descending order - largest functions first)
    processed_symbols.sort(key=lambda x: x['size_bytes'], reverse=True)

    # Step 7: Output the formatted table
    print(f"{'Symbol / Function':<24} | {'Start (Hex)':<12} | {'Next Boundary':<14} | {'Size (Bytes)'}")
    print("-" * 72)
    
    for sym in processed_symbols:
        print(f"{sym['name']:<24} | 0x{sym['start_addr']:04X}       | {sym['next_boundary']:<14} | {sym['size_display']}")

if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description="Extract function sizes from Dunfield listing symbol tables sorted by size footprint."
    )
    parser.add_argument(
        'filename', 
        type=str, 
        help="Path to the toolchain listing file (e.g. GPIO.LST)"
    )
    
    args = parser.parse_args()
    calculate_symbol_sizes(args.filename)