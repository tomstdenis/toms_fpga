#ifndef MEM_H_
#define MEM_H_

// fixed things
#define bootrom_addr	0xF000
#define vidmem_addr		0xF800

// using video mem (like for bios rom)
// First entry is the getc echo (0xFF00, set to 0 to not echo or FF to echo)
#define getc_echo_addr  65280
#define sd_is_init_addr 0xFF01
#define sd_is_hc_addr   0xFF02
#define sd_sectors_addr 0xFF03 // 4 bytes
#define console_x_addr  0xFF07
#define console_y_addr  0xFF08
#define console_tx_addr 0xFF09
#define console_ty_addr 0xFF0A

#endif
