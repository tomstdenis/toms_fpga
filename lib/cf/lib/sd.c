// SD library

// 100 KHz = 10uS per cycle (5uS per half cycle)
#define SD_SLOW_CLK 5

#define SD_FAST_CLK 1

int sd_is_init, sd_is_hc, sd_port, sd_cs_pin, sd_sck_pin, sd_miso_pin, sd_mosi_pin;
unsigned sd_clk, sd_sectors[2];
unsigned char sd_csd[16];

sd_init(int port, int cs, int sck, int miso, int mosi)
{
	sd_port = port;
	sd_cs_pin = cs;
	sd_sck_pin = sck;
	sd_miso_pin = miso;
	sd_mosi_pin = mosi;
	sd_is_hc = 0;
	sd_is_init = 0;
}

unsigned sd_cmd(unsigned cmd, unsigned ph, unsigned pl, unsigned crc)
{
	unsigned x, y;
	
	spi_transfer(0xFF, sd_clk);
	spi_transfer(0xFF, sd_clk);
	spi_transfer(0x40 + cmd, sd_clk);
	spi_transfer(ph>>8, sd_clk);
	spi_transfer(ph&0xFF, sd_clk);
	spi_transfer(pl>>8, sd_clk);
	spi_transfer(pl&0xFF, sd_clk);
	spi_transfer(crc, sd_clk);
	
	// wait for R1 byte
	for (x = 0; x < 256; x++) {
		y = spi_transfer(0xFF);
		if (!(y & 0x80)) {
#ifdef DEBUG
	printf("sd_cmd::%d, %04x%04x, %02x returned %02x\n", cmd, ph, pl, crc, y);
#endif
			return y;						// return R1 byte
		}
	}
#ifdef DEBUG
	printf("sd_cmd::%d, %04x%04x, %02x timeout\n", cmd, ph, pl, crc);
#endif
	return 0xFFFF;							// timed out
}

int sd_reset()
{
	unsigned x, y, t;
	
	y        = 0;
retry:
#ifdef DEBUG
	printf("sd_reset()::Try %d\n", y);
#endif
	sd_clk   = SD_SLOW_CLK;
	sd_is_hc = 0;
	sd_is_init = 0;
	if (++y == 16) {
		return -1;
	}
	// set SPI to our SD port
	spi_setup(sd_port, sd_cs_pin, sd_sck_pin, sd_miso_pin, sd_mosi_pin);

	// make CS high
	spi_set_cs(1);
	
	// toggle SCK 80 times
	for (x = 0; x < 80; x++) {
		spi_set_sck(1);
		wait_us(sd_clk);
		spi_set_sck(0);
		wait_us(sd_clk);
	}
	
	// make CS low
	spi_set_cs(0);
	
#ifdef DEBUG
	printf("sd_reset()::Sending CMD0...\n");
#endif

	// send CMD0
	if (sd_cmd(0, 0, 0, 0x95) != 0x01) { goto retry; }
	
#ifdef DEBUG
	printf("sd_reset()::Sending CMD8...\n");
#endif

	// send CMD8 (this rejects SDSC cards)
	if (sd_cmd(8, 0, 0x01AA, 0x87) != 0x01) { goto retry; }
	
#ifdef DEBUG
	printf("sd_reset()::Receiving CMD8 payload...\n");
#endif

	// recv payload 0x000001AA
	if (spi_transfer(0xFF, sd_clk) != 0x00) { goto retry; }
	if (spi_transfer(0xFF, sd_clk) != 0x00) { goto retry; }
	if (spi_transfer(0xFF, sd_clk) != 0x01) { goto retry; }
	if (spi_transfer(0xFF, sd_clk) != 0xAA) { goto retry; }

#ifdef DEBUG
	printf("sd_reset()::Sending ACMD41...\n");
#endif
	
	// loop on ACMD41 which is CMD55/CMD41(0x40000000)
	for (x = 0; x < 256; x++) {
		if (sd_cmd(55, 0, 0, 0) != 0x01) { goto retry; }
		if (sd_cmd(41, 0x4000, 0, 0) == 0x00) {
			break;
		}
	}
	if (x == 256) { goto retry; }
	
	// switch clockrate
	sd_clk = SD_FAST_CLK;

#ifdef DEBUG
	printf("sd_reset()::Sending CMD58...\n");
#endif

	// loop on CMD58 until powered up
	for (x = 0; x < 256; x++) {
		if (sd_cmd(58, 0, 0, 0) != 0) { goto retry; }
		t = spi_transfer(0xFF, sd_clk);
		spi_transfer(0xFF, sd_clk);
		spi_transfer(0xFF, sd_clk);
		spi_transfer(0xFF, sd_clk);
		if (t & 0x80) { // it's ready
			sd_is_hc = t & 0x40 ? 1 : 0;
			break;
		}
	}
	if (x == 256) { goto retry; }
	
	// if it's not SDHC then set blocklen
	if (!sd_is_hc) {
#ifdef DEBUG
	printf("sd_reset()::Sending CMD16...\n");
#endif
		if (sd_cmd(16, 0, 0x200, 0) != 0x00) { goto retry; }
	}

#ifdef DEBUG
	printf("sd_reset()::Sending CMD9...\n");
#endif

	// let's read the CSD
	if (sd_cmd(9, 0, 0, 0) != 0) { goto retry; }
	// wait for READ_TOKEN
	for (x = 0; x < 256; x++) {
		t = spi_transfer(0xFF, sd_clk);
		if (t == 0xFE) {
			break;
		}
	}
	if (x == 256) { goto retry; }
	// now payload
	for (x = 0; x < 16; x++) {
		sd_csd[x] = spi_transfer(0xFF, sd_clk);
	}
	
	// decode # of sectors (it's bits 69:48 shifted left 10)
	sd_sectors[0] = (unsigned)sd_csd[6] << 10;
	sd_sectors[1] = (sd_csd[6] >> 6) | ((unsigned)sd_csd[7] << 2) | ((unsigned)(sd_csd[8] & 0x3F) << 10);
	return 0;
}
