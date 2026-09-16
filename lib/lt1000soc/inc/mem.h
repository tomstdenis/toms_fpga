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

#define TCM_FUNC __attribute__((section(".tcm_code"), noinline)) 

void load_tcm_code(void);

#endif
