#ifndef LT1000_SD_H
#define LT1000_SD_H

extern uint32_t sd_sectors;
int sd_init(uint8_t cs_sel, uint8_t init_div, uint8_t oper_div);
int sd_sector_op(uint8_t cs_sel, uint8_t div, uint32_t sector, unsigned char *dst, int wr_en);

#endif
