#ifndef LT1000_SD_H
#define LT1000_SD_H

int sd_init(uint8_t cs_sel, uint8_t init_div, uint8_t oper_div, uint8_t *csd, uint32_t *sectors);
int sd_sector_op(uint8_t cs_sel, uint8_t div, uint32_t sector, unsigned char *dst, int wr_en);

#endif
