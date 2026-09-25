#ifndef LT1000_MEM_H
#define LT1000_MEM_H

// ROM base address
#define ROM_ADDR   0x01000000
// TCM base address
#define TCM_ADDR   0x02000000
// VGA base address
#define VGA_ADDR   0x04000000
// PSRAM base address
#define PSRAM_ADDR 0x08000000
// MMIO base address
#define MMIO_ADDR  0x10000000

// .tcm_code section labels
extern uint32_t __tcm_code_start, __tcm_code_end, __tcm_code_load_start;

// Start of free area in TCM memory, this grows upwards to the stack
// Memory above this point is free to use and won't impact with
// .tcm_code memory
#define TCM_FREE ((intptr_t)&__tcm_code_end)

// place a function in TCM memory for faster
// more predictable execution
#ifndef LT1000_BIOS
#define TCM_FUNC(name) __attribute__((section(".tcm_code." #name), noinline))
#else
#define TCM_FUNC(name)
#endif

// reload .tcm_code section into TCM memory from where it was initially loaded in PSRAM
// handy if you need to scrap over parts of .tcm_code temporarily
void load_tcm_code(void);

#endif
