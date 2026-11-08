#if defined(TRACE) && defined(HOSTPC)
#include <ncurses.h>
#define LOG(...) fprintf(stderr, __VA_ARGS__) 
#else
#define LOG(...)
#endif

// Max number of remaps (basically how many banks do you want to be able to swap)
#define MAX_REMAPS 8

// table of remaps that map anything inside a region to a new offset (offset = target_addr - start)
static struct {
	uint32_t start, end, offset;
} mem_remaps[MAX_REMAPS];

// remap a range to another base address.  This will form the basis of bank switching in the future
// map to a target of 0 to remove this entry (null entries are where start == end == 0)
void mem_remap(uint32_t start, uint32_t end, uint32_t target)
{
	uint8_t x;
	// are we updating an existing mapping
	for (x = 0; x < MAX_REMAPS; x++) {
		if (mem_remaps[x].start == start && mem_remaps[x].end == end) {
store:
			if (target != 0) {
				// update the offset of this mapping, the start/end are set when it's first create below
				mem_remaps[x].offset = target - start;
			} else {
				// we're deleting this mapping so shift the array up and clear the last.
				for (; x < (MAX_REMAPS-1); x++) {
					mem_remaps[x] = mem_remaps[x+1];
					if (!mem_remaps[x].end) {
						// we hit the end of the list so we don't need to move any more
						break;
					}
				}
				mem_remaps[MAX_REMAPS-1].start = mem_remaps[MAX_REMAPS-1].end = 0;
			}
			return;
		}
	}
	for (x = 0; x< MAX_REMAPS; x++) {
		if (mem_remaps[x].end == 0) {
			// new entry so store the start/end
			mem_remaps[x].start = start;
			mem_remaps[x].end   = end;
			goto store;
		}
	}
}

// translate an address based on current mappings or return identity function if not found
uint32_t mem_translate(uint32_t addr)
{
	uint8_t x;
	for (x = 0; x < MAX_REMAPS && mem_remaps[x].end; x++) {
		if (addr >= mem_remaps[x].start && addr <= mem_remaps[x].end) {
			return addr + mem_remaps[x].offset;
		}
	}
	return addr;
}

// memcpy but for this memory
void mem_memcpy(uint32_t src, uint32_t dst, uint16_t len)
{
	uint8_t buf[8];
	while (len) {
		uint16_t blklen = (len > sizeof(buf)) ? sizeof(buf) : len;
		mem_read_block(src, blklen, buf);
		mem_write_block(dst, blklen, buf);
		src += blklen;
		dst += blklen;
		len -= blklen;
	}
}

#ifdef HOSTPC

static uint8_t mem[512UL*1024UL]; // 512KiB

int mem_init(void)
{
	memset(mem, 0, sizeof mem);
	memset(mem_remaps, 0, sizeof mem_remaps);
	return 0;
}

void mem_read_block(uint32_t addr, uint16_t len, uint8_t *dst)
{
	LOG("mem_read_block: %04x %04x\n", addr, len);
	memcpy(dst, &mem[mem_translate(addr)], len);
}

void mem_write_block(uint32_t addr, uint16_t len, uint8_t *src)
{
	LOG("mem_write_block: %04x %04x\n", addr, len);
	memcpy(&mem[mem_translate(addr)], src, len);
}


uint8_t mem_read_byte(uint32_t addr)
{
	LOG("mem_read_byte: %04x\n", addr);
	return mem[mem_translate(addr)];
}

uint16_t mem_read_word(uint32_t addr)
{
	uint32_t ta = mem_translate(addr);
	LOG("mem_read_word: %04x\n", addr);
	return ((uint16_t)mem[ta+1] << 8) | mem[ta];
}

void mem_write_byte(uint32_t addr, uint8_t val)
{
	LOG("mem_write_byte: %04x %02x\n", addr, val);
	mem[mem_translate(addr)] = val;
}

void mem_write_word(uint32_t addr, uint16_t val)
{
	uint32_t ta = mem_translate(addr);
	LOG("mem_write_byte: %04x %04x\n", addr, val);
	mem[ta] = val&0xFF;
	mem[ta+1] = val>>8;
}

#else

// driver for 23AA04M-I/SN SPI SRAM

#include <SPI.h>

#define CS_PORT VPORTC
#define CS_PIN_BM PIN3_bm

int mem_init(void)
{
	// clear the remapping table
	memset(mem_remaps, 0, sizeof mem_remaps);

	// set CS pin high as it's active low
	CS_PORT.DIR |= CS_PIN_BM;
	CS_PORT.OUT |= CS_PIN_BM;
	
	// TODO: configure sequential mode ...
	// 2. Start Transaction FIRST (configures pins & interrupts)
	SPI.beginTransaction(SPISettings(10000000, MSBFIRST, SPI_MODE0));

	// 3. Set CS active
	CS_PORT.IN = CS_PIN_BM;    // (writing to the VPORT.IN will toggle the pin) toggle PA7 (make it low)

	// compose command
	SPI.transfer(0x01);					// 01 - WRSR
	SPI.transfer(1U << 6);              // sequential mode (this is the default but we want to make sure it's in this mode)
	SPI.transfer((2 << 3) | (4));       // defaults (slew rate = 4.33V/ns, drive strength=50%)

	// 6. Set CS idle
	CS_PORT.IN = CS_PIN_BM;    // (writing to the VPORT.IN will toggle the pin) toggle PA7 (make it high)

	// 7. End Transaction LAST
	SPI.endTransaction();
	
	return 0;
}

void mem_read_block(uint32_t addr, uint16_t len, uint8_t *dst)
{
	// translate address to linear address
    addr = mem_translate(addr);

	// 2. Start Transaction FIRST (configures pins & interrupts)
	SPI.beginTransaction(SPISettings(10000000, MSBFIRST, SPI_MODE0));

	// 3. Set CS active
	CS_PORT.IN = CS_PIN_BM;    // (writing to the VPORT.IN will toggle the pin) toggle PA7 (make it low)

	// compose command
	SPI.transfer(0x03);					// 03 - read
	SPI.transfer(addr >> 16);			// addr[23:16]
	SPI.transfer((addr >> 8) & 0xFF);	// addr[15:8]
	SPI.transfer(addr & 0xFF);			// addr[7:0]
	SPI.transfer(dst, len);

	// 6. Set CS idle
	CS_PORT.IN = CS_PIN_BM;    // (writing to the VPORT.IN will toggle the pin) toggle PA7 (make it high)

	// 7. End Transaction LAST
	SPI.endTransaction();
}

void mem_write_block(uint32_t addr, uint16_t len, uint8_t *src)
{
	// translate address to linear address
    addr = mem_translate(addr);

	// 2. Start Transaction FIRST (configures pins & interrupts)
	SPI.beginTransaction(SPISettings(10000000, MSBFIRST, SPI_MODE0));

	// 3. Set CS active
	CS_PORT.IN = CS_PIN_BM;    // (writing to the VPORT.IN will toggle the pin) toggle PA7 (make it low)

	// compose command
	SPI.transfer(0x02);					// 02 - write
	SPI.transfer(addr >> 16);			// addr[23:16]
	SPI.transfer((addr >> 8) & 0xFF);	// addr[15:8]
	SPI.transfer(addr & 0xFF);			// addr[7:0]
	while (len--) {
		SPI.transfer(*src++);
	}

	// 6. Set CS idle
	CS_PORT.IN = CS_PIN_BM;    // (writing to the VPORT.IN will toggle the pin) toggle PA7 (make it high)

	// 7. End Transaction LAST
	SPI.endTransaction();
}

uint8_t mem_read_byte(uint32_t addr)
{
	uint8_t ch;
	mem_read_block(addr, 1, &ch);
	return ch;
}

uint16_t mem_read_word(uint32_t addr)
{
	uint16_t ch;
	mem_read_block(addr, 2, (uint8_t*)&ch);
	return ch;
}

void mem_write_byte(uint32_t addr, uint8_t val)
{
	mem_write_block(addr, 1, &val);
}

void mem_write_word(uint32_t addr, uint16_t val)
{
	mem_write_block(addr, 2, (uint8_t*)&val);
}

#undef CS_PORT
#undef CS_PIN_BM

#endif
