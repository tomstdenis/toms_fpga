#ifndef LT1000_SD_H
#define LT1000_SD_H

extern uint32_t sd_sectors;

// initialize SD library typically cs_sel=0, init_div=15, oper_div=4
int sd_init(uint8_t cs_sel, uint8_t init_div, uint8_t oper_div);

// read (wr_en=0) or write (wr_en=1) a sector on disk
int sd_sector_op(uint8_t cs_sel, uint8_t div, uint32_t sector, unsigned char *dst, int wr_en);

#endif
