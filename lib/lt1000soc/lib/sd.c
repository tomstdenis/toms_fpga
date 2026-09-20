#include "lt1000.h"

// shift a byte in/out
static uint8_t spi_transfer(uint8_t mosi_byte, uint8_t div, uint8_t cs_start, uint8_t cs_end, uint8_t cs_sel)
{
	uint32_t v;
	
	// issue transfer
	SPI_TRANSFER =
		mosi_byte |
		((div & 0xF) << 8) |
		((cs_start & 1) << 12) |
		((cs_end & 1) << 13) |
		((cs_sel & 3) << 14) |
		(1UL << 16);

	// wait for done
	do {
		v = SPI_TRANSFER;
	} while ((v & 0x100) == 0);
	return v & 0xFF;
}

// send a SD CMD
static uint32_t sd_cmd(uint8_t cs_sel, uint8_t div, uint8_t cmd, uint32_t param, uint8_t crc)
{
	uint32_t r1, tries;
	
	// clock out 16 bits
	spi_transfer(0xFF, div, 0, 0, cs_sel);
	spi_transfer(0xFF, div, 0, 0, cs_sel);

	// transfer cmd, then param, then crc
	spi_transfer(0x40 + cmd, div, 0, 0, cs_sel);
	spi_transfer((param>>24)&0xFF, div, 0, 0, cs_sel);
	spi_transfer((param>>16)&0xFF, div, 0, 0, cs_sel);
	spi_transfer((param>>8)&0xFF, div, 0, 0, cs_sel);
	spi_transfer(param&0xFF, div, 0, 0, cs_sel);
	spi_transfer(crc, div, 0, 0, cs_sel);
	
	// try to read R1 byte
	for (tries = 0; tries < 1024; tries++) {
		yield();
		r1 = spi_transfer(0xFF, div, 0, 0, cs_sel);
		if (!(r1 & 0x80)) {
			return r1 & 0xFF;
		}
	}
	return 0xFFFFFFFF;
}

// read a block, when called we're expecting a read token 0xFE coming up at some point
static int sd_read_block(uint8_t cs_sel, uint8_t div, unsigned char *dst, unsigned len)
{
	unsigned x, t;
	
	for (x = 0; x < 8192; x++) {
		yield();
		t = spi_transfer(0xFF, div, 0, 0, cs_sel);
		if (t == 0xFE) {
			// ready
			for (x = 0; x < len; x++) {
				*dst++ = spi_transfer(0xFF, div, 0, 0, cs_sel);
			}
			// skip CRC
			spi_transfer(0xFF, div, 0, 0, cs_sel);
			spi_transfer(0xFF, div, 0, 0, cs_sel);
			yield();
			return 0;
		}
	}
	return 1;
}

// initialize an SD card
static int sd_is_init = 0;
uint32_t sd_sectors;
int sd_init(uint8_t cs_sel, uint8_t init_div, uint8_t oper_div)
{
	uint32_t tries, x, y, t;
	uint8_t csd[16];
	tries = 0;
top:	
	for (; tries < 16; tries++) {
		yield();

		// toggle SCK 80 times while CS is high (exit with CS low)
		for (x = 0; x < 10; x++) {
			spi_transfer(0xFF, init_div, 1, (x == 9) ? 0 : 1, cs_sel);
		}

		// send CMD0
		if (sd_cmd(cs_sel, init_div, 0, 0x00000000, 0x95) != 0x01) {
			continue;
		}
		
		// send CMD8 (rejects v1 cards)
		if (sd_cmd(cs_sel, init_div, 8, 0x000001AA, 0x87) != 0x01) {
			continue;
		}
		
		// receive CMD8 payload
		if (spi_transfer(0xFF, init_div, 0, 0, cs_sel) != 0x00) { continue; }
		if (spi_transfer(0xFF, init_div, 0, 0, cs_sel) != 0x00) { continue; }
		if (spi_transfer(0xFF, init_div, 0, 0, cs_sel) != 0x01) { continue; }
		if (spi_transfer(0xFF, init_div, 0, 0, cs_sel) != 0xAA) { continue; }
		
		// loop on ACMD41
		for (x = 0; x < 256; x++) {
			yield();
			if (sd_cmd(cs_sel, init_div, 55, 0x00000000, 0x00) != 0x01) {
				++tries;
				goto top;
			}
			if (sd_cmd(cs_sel, init_div, 41, 0x40000000, 0x00) == 0x00) {
				break;
			}
		}
		if (x == 256) {
			continue;
		}

		for (x = 0; x < 256; x++) {
			yield();
			if (sd_cmd(cs_sel, init_div, 58, 0x00000000, 0x00) != 0) {
				++tries;
				goto top;
			}
			y = spi_transfer(0xFF, init_div, 0, 0, cs_sel);
			spi_transfer(0xFF, init_div, 0, 0, cs_sel);
			spi_transfer(0xFF, init_div, 0, 0, cs_sel);
			spi_transfer(0xFF, init_div, 0, 0, cs_sel);
			if (y & 0x80) {
				// TODO: 0x40 is HC flag
				break;
			}
		}
		if (x == 256) {
			continue;
		}

		// read CSD
		if (sd_cmd(cs_sel, oper_div, 9, 0x00000000, 0x00) != 0) {
			continue;
		}
		if (sd_read_block(cs_sel, oper_div, csd, 16) != 0) {
			continue;
		}
		
		// # of sectors is bits 69:48 shifted left 10 bits (the data is transmitted big endian...)
		sd_sectors = (((uint32_t)csd[15-6])                     | // bits 55:48
		             ((uint32_t)csd[15-7] << 8)                 | // bits 63:56
		             ((uint32_t)(csd[15-8] & 0x1F) << 16)) << 10; // bits 69:64

		// raise CS and clock out
		spi_transfer(0xFF, oper_div, 1, 1, cs_sel);
		spi_transfer(0xFF, oper_div, 1, 1, cs_sel);
		sd_is_init = 1;
		return 1;
	}
	return 0;
}

int sd_sector_op(uint8_t cs_sel, uint8_t div, uint32_t sector, unsigned char *dst, int wr_en)
{
	uint32_t r, x;
	int ret;
	
	if (!sd_is_init) {
		if (!sd_init(cs_sel, 0xF, div)) {
			return -1;
		}
	}
	
	ret = -1;
	r = 0;

retry:
	yield();
	spi_transfer(0xFF, div, 1, 0, cs_sel); // lower CS after clocking a byte
	if (sd_cmd(cs_sel, div, wr_en ? 24 : 17, sector, 0) != 0) { goto error; }

	if (wr_en) {
		spi_transfer(0xFE, div, 0, 0, cs_sel);
		for (x = 0; x < 512; x++) {
			spi_transfer(dst[x], div, 0, 0, cs_sel);
		}
		yield();
		spi_transfer(0xFF, div, 0, 0, cs_sel); // CRC
		spi_transfer(0xFF, div, 0, 0, cs_sel);
		if ((spi_transfer(0xFF, div, 0, 0, cs_sel) & 0x1F) != 0x05) { goto error; }
		for (x = 8193; --x;) {
			yield();
			if (spi_transfer(0xFF, div, 0, 0, cs_sel)) { break; }
		}
		if (x == 0) { goto error; }
	} else {
		if (sd_read_block(cs_sel, div, dst, 512) != 0) { goto error; }
		yield();
	}

	ret = 0;
error:
	spi_transfer(0xFF, div, 1, 1, cs_sel);
	spi_transfer(0xFF, div, 1, 1, cs_sel);

	// retry command upto 32 times before bailing
	if (ret != 0 && r++ < 32) {
		// wait_ms(250);								// wait 250ms between tries
		goto retry;
	}
	return ret;
}
