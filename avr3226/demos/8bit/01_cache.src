#ifdef TRACE
#define CACHE_STATS
#endif

#ifdef HOSTPC
#define CACHE_STATS
#endif

#ifdef CACHE_STATS
#define CACHE_HIT() ++cache_trace_hit;
#define CACHE_MISS() ++cache_trace_miss;
#define CACHE_SPLIT_READ() ++cache_trace_split_read;
#define CACHE_SPLIT_WRITE() ++cache_trace_split_write;
#else
#define CACHE_HIT()
#define CACHE_MISS()
#define CACHE_SPLIT_READ()
#define CACHE_SPLIT_WRITE()
#endif

#ifdef CACHE_STATS
uint64_t cache_trace_hit, cache_trace_miss, cache_trace_split_read, cache_trace_split_write;
#endif

#if defined(TRACE) && defined(HOSTPC)
#include <ncurses.h>
#define LOG(...) fprintf(stderr, __VA_ARGS__) 
#else
#define LOG(...)
#endif

// the CPU sees memory through the cache layer some memory regions are tied to peripherals
// others are non-cacheable, etc.
// if no match is found then it just goes to the cache which is backed by the memory
static const struct {
	cache_addr_t start, end;
	void (*byte_write)(uint16_t bo, uint8_t val); // bo == offset from start of region
	uint8_t (*byte_read)(uint16_t bo);
	void (*word_write)(uint16_t bo, uint16_t val); // bo == offset from start of region
	uint16_t (*word_read)(uint16_t bo);
} regions[] = {
#ifndef USING_BOARD
	// manually add peripherals if we're hacking something not using a board config
	#ifdef ACIA6551_BASE
		{ ACIA6551_BASE, ACIA6551_BASE + 3, &write_6551, &read_6551, NULL, NULL },
	#endif
	#ifdef APPLE1_PIA_BASE
		{ APPLE1_PIA_BASE, APPLE1_PIA_BASE + 0x20, &write_apple1_pia, &read_apple1_pia, NULL, NULL },
	#endif
	#ifdef APPLE2_KBD_BASE
		{ APPLE2_KBD_BASE, APPLE2_KBD_BASE + 0xFE, &write_apple2_kbd, &read_apple2_kbd, NULL, NULL },
	#endif
	#ifdef APPLE_PLATFORM_BASE
		{ APPLE_PLATFORM_BASE, APPLE_PLATFORM_BASE, &write_platform, &read_platform, NULL, NULL },
	#endif
#endif

#ifdef BOARD_APPLE1
	#ifdef APPLE_PLATFORM_BASE
		{ APPLE_PLATFORM_BASE, APPLE_PLATFORM_BASE, &write_platform, &read_platform, NULL, NULL },
	#endif
	#ifdef APPLE1_PIA_BASE
		{ APPLE1_PIA_BASE, APPLE1_PIA_BASE + 0x20, &write_apple1_pia, &read_apple1_pia, NULL, NULL },
	#endif
#endif

#ifdef BOARD_APPLE2
	#ifdef APPLE_PLATFORM_BASE
		{ APPLE_PLATFORM_BASE, APPLE_PLATFORM_BASE, &write_platform, &read_platform, NULL, NULL },
	#endif
	#ifdef APPLE2_KBD_BASE
		{ APPLE2_KBD_BASE, APPLE2_KBD_BASE + 0xFE, &write_apple2_kbd, &read_apple2_kbd, NULL, NULL },
	#endif
	#ifdef ACIA6551_BASE
		{ ACIA6551_BASE, ACIA6551_BASE + 3, &write_6551, &read_6551, NULL, NULL },
	#endif
#endif

#ifdef BOARD_RISCV
	#ifdef RISCV_PLATFORM_BASE
		{ RISCV_PLATFORM_BASE, RISCV_PLATFORM_BASE + 0xFF, &write_platform, &read_platform, NULL, NULL },
	#endif
#endif

#ifdef DISABLE_CACHE
	// the entire memory is non cacheable
	{ 0x0000, 0xFFFF, &mem_write_byte, &mem_read_byte, &mem_write_word, &mem_read_word },
#endif
};

static struct {
	cache_addr_t tag; // top 15..CACHE_LINE_BITS is the address, bit 0 is valid, bit 1 is dirty
	uint8_t cache[CACHE_LINE_BYTES];
} cache_lines[CACHE_LINES];

static cache_addr_t tag1, tag0; // quick check for the tag of the 0'th entry
static uint8_t *cache1_bytes, *cache0_bytes; // quick pointer to the 0'th cache line
static uint8_t cache_hit = 0, cache_map[CACHE_LINES]; // this is a mapping to cache lines so we don't have to move cache data around just the indecies

#ifdef TRACE
void cache_trace(void)
{
	LOG("CACHE:{%llu,%llu,%llu,%llu} ", (unsigned long long)cache_trace_hit, (unsigned long long)cache_trace_miss, (unsigned long long)cache_trace_split_read, (unsigned long long)cache_trace_split_write);
}
#endif

void cache_init(void)
{
	uint8_t x;
	memset(cache_lines, 0, sizeof cache_lines);
	for (x = 0; x < CACHE_LINES; x++) {
		cache_map[x] = x;
	}
	cache0_bytes = &cache_lines[0].cache[0];
	cache1_bytes = &cache_lines[1].cache[0];
	cache_hit = 0;

	// always read something so the 0'th cache line is valid
	tag0 = INVALID_TAG;
	tag1 = INVALID_TAG;
	cache_read_byte(0);
}

// move the y'th entry of the cache_map to the 0'th entry and shift everything else up
static void cache_mtf(uint8_t y)
{
	LOG("cache_mtf: %d\n", y);
	// many 8-bit processors will likely bounce between 2 cache lines (one for opcode, one for data being worked on) so let's avoid mtf if we're not the first two
	if (y>1) {
		uint8_t t = cache_map[y];
		// move the y'th entry to the front of the list
		memmove(&cache_map[1], &cache_map[0], y);
		cache_map[0] = t;

		// reset quick pointers to first two lines
		cache0_bytes = &cache_lines[cache_map[0]].cache[0];
		tag0 = cache_lines[cache_map[0]].tag >> CACHE_LINE_BITS;
		cache1_bytes = &cache_lines[cache_map[1]].cache[0];
		tag1 = cache_lines[cache_map[1]].tag >> CACHE_LINE_BITS;

		// our hit is now in line 0
		cache_hit = 0;	
	}
}

// evict the y'th line back to RAM
static void cache_evict(uint8_t y)
{
	LOG("cache_evict: %d\n", y);
	if ((cache_lines[y].tag & 3) == 3) { // is it valid and dirty?
		// evict
		cache_lines[y].tag &= ~2U; // clear dirty bit
#ifdef USE32BIT
		if ((cache_lines[y].tag & ~((1U << CACHE_LINE_BITS) - 1)) < SPI_SRAM_TOP) {
			mem_write_block(cache_lines[y].tag & ~((1U << CACHE_LINE_BITS) - 1), CACHE_LINE_BYTES, &cache_lines[y].cache[0]);
		}
#else
		mem_write_block(cache_lines[y].tag & ~((1U << CACHE_LINE_BITS) - 1), CACHE_LINE_BYTES, &cache_lines[y].cache[0]);
#endif
	}
}

// fill the y'th cache_line with addr's data
static void cache_fill(cache_addr_t addr, uint8_t y)
{
	LOG("cache_fill: %04x, %d\n", addr, y);
	cache_lines[y].tag = (addr & ~((1U << CACHE_LINE_BITS) - 1)) | 1; // tag + valid
#ifdef USE32BIT
	if ((cache_lines[y].tag & ~((1U << CACHE_LINE_BITS) - 1)) >= SPI_SRAM_TOP) {
		flash_read_block((addr & ~((1U << CACHE_LINE_BITS) - 1)) - SPI_SRAM_TOP, &cache_lines[y].cache[0], CACHE_LINE_BYTES);
	} else {
		mem_read_block(addr & ~((1U << CACHE_LINE_BITS) - 1), CACHE_LINE_BYTES, &cache_lines[y].cache[0]);
	}
#else
	mem_read_block(addr & ~((1U << CACHE_LINE_BITS) - 1), CACHE_LINE_BYTES, &cache_lines[y].cache[0]);
#endif
}

#ifdef HOSTPC
unsigned long cachehit0 = 0, cachehit1 = 0;
#endif

// make 'addr' accessible in cache_lines[cache_map[0]] somehow (sort, or evict and replace)
static uint8_t cache_access_page(cache_addr_t addr)
{
	cache_addr_t tag;
	uint8_t x;

	LOG("cache_access_page: %04x\n", addr);

	// almost all cache hits will be in the 0'th line
	// followed by the 1'th line so we check these quickly first
	// before searching the rest of the lines
	
	// quick check if page is ready to access
	tag = addr >> CACHE_LINE_BITS;
	if (tag0 == tag) {
		cache_hit = 0;
		CACHE_HIT();
#ifdef HOSTPC
		++cachehit0;
#endif
		return 1;
	}
	// try the 2nd cache line quickly
	if (tag1 == tag) {
		cache_hit = 1;
		CACHE_HIT();
#ifdef HOSTPC
		++cachehit1;
#endif
		return 1;
	}

	// is this in the cache (start at line 2 since we check line 0 and 1 above
	for (x = 2; x < CACHE_LINES; x++) {
		if ((cache_lines[cache_map[x]].tag >> CACHE_LINE_BITS) == tag) {
			if (cache_lines[cache_map[x]].tag & 1) {
				// found it, since it's not one of the first two we move it to the front
				cache_mtf(x);
				CACHE_HIT();
				return 1;
			}
		}
	}
	return 0;
}

// prep a line to be cacheable
static void cache_prep_line(cache_addr_t addr)
{
	// line wasn't found so we must evict the last (least recently used) line
	CACHE_MISS();
	
	// it's not in the cache so we evict cache_lines[cache_map[CACHE_LINES-1]]
	cache_evict(cache_map[CACHE_LINES-1]);
	
	// load cache line
	cache_fill(addr, cache_map[CACHE_LINES-1]); // fill the line
	cache_mtf(CACHE_LINES-1); // move this to the front
}

uint8_t cache_read_byte(cache_addr_t addr)
{
	uint8_t x;
	LOG("cache_read_byte: %04x\n", addr);
	if (!cache_access_page(addr)) {
		for (x = 0; x < (sizeof(regions) / sizeof(regions[0])); x++) {
			if (regions[x].byte_read && regions[x].start <= addr && regions[x].end >= addr) {
				return regions[x].byte_read(addr - regions[x].start);
			}
		}
		// it's not MMIO so let's put this line in cache
		cache_prep_line(addr);
	}
	
	// read from memory
	if (!cache_hit) {
		return cache0_bytes[addr & ((1U << CACHE_LINE_BITS) - 1)];
	} else {
		return cache1_bytes[addr & ((1U << CACHE_LINE_BITS) - 1)];
	}
}

uint16_t cache_read_word(cache_addr_t addr)
{
	uint8_t x;
	LOG("cache_read_word: %04x\n", addr);
	if ((addr + 1) & (CACHE_LINE_BYTES - 1)) {
		// it's not a split read
		if (!cache_access_page(addr)) {
			for (x = 0; x < (sizeof(regions) / sizeof(regions[0])); x++) {
				if (regions[x].word_read && regions[x].start <= addr && regions[x].end >= addr) {
					return regions[x].word_read(addr - regions[x].start);
				}
			}
			// it's not MMIO so let's put this line in cache
			cache_prep_line(addr);
		}
	} else {
		// split read so we need to prep both cache lines
		if (!cache_access_page(addr) || !cache_access_page(addr+1)) {
			for (x = 0; x < (sizeof(regions) / sizeof(regions[0])); x++) {
				if (regions[x].word_read && regions[x].start <= addr && regions[x].end >= addr) {
					return regions[x].word_read(addr - regions[x].start);
				}
			}
			// it's not MMIO so let's put this line in cache
			cache_prep_line(addr);
			cache_prep_line(addr+1);
		}
	}

	// read from memory
	if (((addr & ((1U << CACHE_LINE_BITS) - 1)) + 1) == CACHE_LINE_BYTES) {
		// read spans two lines
		CACHE_SPLIT_READ();
		return ((uint16_t)cache_read_byte(addr+1) << 8) | cache_read_byte(addr);
	} else {
		// 2x8-bit read from same cache line
		cache_access_page(addr);
		addr &= (1U << CACHE_LINE_BITS) - 1;
		if (!cache_hit) {
			return ((uint16_t)cache0_bytes[addr+1] << 8) | cache0_bytes[addr];
		} else {
			return ((uint16_t)cache1_bytes[addr+1] << 8) | cache1_bytes[addr];
		}
	}
}

void cache_write_byte(cache_addr_t addr, uint8_t val)
{
	uint8_t x;
	LOG("cache_write_byte: %04x\n", addr);
	if (!cache_access_page(addr)) {
		for (x = 0; x < (sizeof(regions) / sizeof(regions[0])); x++) {
			if (regions[x].byte_write && regions[x].start <= addr && regions[x].end >= addr) {
				regions[x].byte_write(addr - regions[x].start, val);
				return;
			}
		}
		// it's not MMIO so let's put this line in cache
		cache_prep_line(addr);
	}

	// write to memory
	if (!cache_hit) {
		cache_lines[cache_map[0]].tag |= 2; // dirty bit
		cache0_bytes[addr & ((1U << CACHE_LINE_BITS) - 1)] = val;
	} else {
		cache_lines[cache_map[1]].tag |= 2; // dirty bit
		cache1_bytes[addr & ((1U << CACHE_LINE_BITS) - 1)] = val;
	}
}

void cache_write_word(cache_addr_t addr, uint16_t val)
{
	uint8_t x;
	LOG("cache_write_word: %04x\n", addr);
	if (!cache_access_page(addr) || !cache_access_page(addr+1)) {
		for (x = 0; x < (sizeof(regions) / sizeof(regions[0])); x++) {
			if (regions[x].word_write && regions[x].start <= addr && regions[x].end >= addr) {
				regions[x].word_write(addr - regions[x].start, val);
				return;
			}
		}
		// it's not MMIO so let's put this line in cache
		cache_prep_line(addr);
		cache_prep_line(addr+1);
	}

	// write to memory
	if (((addr & ((1U << CACHE_LINE_BITS) - 1)) + 1) == CACHE_LINE_BYTES) {
		CACHE_SPLIT_WRITE();
		cache_write_byte(addr, val&0xFF);
		cache_write_byte(addr+1,val>>8);
	} else {
		cache_access_page(addr);
		addr &= (1U << CACHE_LINE_BITS) - 1;
		if (!cache_hit) {
			cache_lines[cache_map[0]].tag |= 2; // dirty bit
			cache0_bytes[addr] = val & 0xFF;
			cache0_bytes[addr+1] = val >> 8;
		} else {
			cache_lines[cache_map[1]].tag |= 2; // dirty bit
			cache1_bytes[addr] = val & 0xFF;
			cache1_bytes[addr+1] = val >> 8;
		}
	}
}

// write all dirty pages
void cache_flush(void)
{
	uint8_t x;
	LOG("cache_flush:\n");
	for (x = 0; x < CACHE_LINES; x++) {
		cache_evict(x);
	}
}

uint8_t *cache_reuse(void)
{
	cache_flush();
	return (uint8_t*)&cache_lines;
}

// flush cache and re-init 
void cache_invalidate(void)
{
	LOG("cache_invalidate:\n");
	cache_flush();
	cache_init();
}
