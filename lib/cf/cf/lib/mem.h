#ifndef MEM_H_
#define MEM_H_

// fixed things
#define bootrom_addr	0xF000
#define vidmem_addr		0xF800

// how much memory you can clear before hitting the lib variables
#define vidmem_clearsize 0x7D0

// using video mem (like for bios rom)
// these are all after the last byte of text space 
#define getc_echo_addr  65488
#define sd_is_init_addr 0xFFD1
#define sd_is_hc_addr   0xFFD2
#define sd_sectors_addr 0xFFD3 // 4 bytes
#define console_x_addr  0xFFD7
#define console_y_addr  0xFFD8
#define console_tx_addr 0xFFD9
#define console_ty_addr 0xFFDA
#define fat16_lba	    0xFFDB // 4 bytes!
#endif
