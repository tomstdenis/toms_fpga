// SD library
#ifndef SD_C_
#define SD_C_

#ifdef SD_BIOS
// 0xFFE0..0xFFEF for BIOS based SD lib
#define sd_is_init *((unsigned char*)0xFFEF)
#define sd_is_hc *((unsigned char*)0xFFEE)
#define sd_sectors ((unsigned*)0xFFEA)
#else
unsigned char sd_is_init, sd_is_hc;
unsigned sd_sectors[2];
#endif

#ifndef SPI_FIXED
unsigned char sd_port, sd_cs_pin, sd_sck_pin, sd_miso_pin, sd_mosi_pin;
#endif

sd_init(unsigned port, unsigned cs, unsigned sck, unsigned miso, unsigned mosi)
{
#ifndef SPI_FIXED
	sd_port = port;
	sd_cs_pin = cs;
	sd_sck_pin = sck;
	sd_miso_pin = miso;
	sd_mosi_pin = mosi;
#endif
	sd_is_hc = 0;
	sd_is_init = 0;
#ifdef SPI_FIXED
	spi_setup();
#else
	spi_setup(port, cs, sck, miso, mosi);
#endif
}

unsigned sd_cmd(unsigned cmd, unsigned ph, unsigned pl, unsigned crc)
{
	unsigned x, y;
	
	spi_recv();
	spi_recv();
	spi_transfer(0x40 + cmd);
	spi_transfer(ph>>8);
	spi_transfer(ph&0xFF);
	spi_transfer(pl>>8);
	spi_transfer(pl&0xFF);
	spi_transfer(crc);
	
	// wait for R1 byte
	for (x = 256; x--; ) {
		y = spi_recv();
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

// read a block, when called we're expecting a read token 0xFE coming up at some point
int sd_read_block(unsigned char *dst, unsigned len)
{
	unsigned x, t;
	// wait for READ_TOKEN
	for (x = 256; x--;) {
		t = spi_recv();
		if (t == 0xFE) {
			for (x = len; x--; ) {
				*dst++ = spi_recv();
			}
			spi_recv(); // skip CRC
			spi_recv();
			return 0;
		}
	}
	return -1;
}

#ifndef SPI_FIXED
sd_port_setup()
{
	spi_setup(sd_port, sd_cs_pin, sd_sck_pin, sd_miso_pin, sd_mosi_pin);
}
#endif

int sd_reset()
{
	unsigned x, y, t;
	unsigned char b;
	unsigned char sd_csd[16];

	y        = 0;
retry:
#ifdef DEBUG
	since_us();
	printf("sd_reset()::Try %d\n", y);
#endif
	sd_is_hc   = 0;
	sd_is_init = 0;
	if (++y == 16) {
		return -1;
	}
	
#ifndef SPI_FIXED
	// set SPI to our SD port
	sd_port_setup();
#endif

	// make CS high
	spi_set_cs(1);
	
	// toggle SCK 80 times
	for (x = 10; x--;) {
		spi_recv();
	}
	
	// make CS low
	spi_set_cs(0);
	
#ifdef DEBUG
	printf("%5u:sd_reset()::Sending CMD0...\n", since_us());
#endif

	// send CMD0
	if (sd_cmd(0, 0, 0, 0x95) != 0x01) { goto retry; }
	
#ifdef DEBUG
	printf("%5u:sd_reset()::Sending CMD8...\n", since_us());
#endif

	// send CMD8 (this rejects SDSC v1 cards)
	if (sd_cmd(8, 0, 0x01AA, 0x87) != 0x01) { goto retry; }
	
#ifdef DEBUG
	printf("%5u:sd_reset()::Receiving CMD8 payload...\n", since_us());
#endif

	// recv payload 0x000001AA
	b = spi_recv();
	b += spi_recv();
	b += spi_recv();
	b += spi_recv();
	if (b != 0xAB) goto retry;

#ifdef DEBUG
	printf("%5u:sd_reset()::Sending ACMD41...\n", since_us());
#endif
	
	// loop on ACMD41 which is CMD55/CMD41(0x40000000)
	for (x = 256; x--; ) {
		if (sd_cmd(55, 0, 0, 0) != 0x01) { goto retry; }
		if (sd_cmd(41, 0x4000, 0, 0) == 0x00) {
			break;
		}
	}
	if (!x) { goto retry; }

#ifdef DEBUG
	printf("%5u:sd_reset()::Sending CMD58...\n", since_us());
#endif

	// loop on CMD58 until powered up
	for (x = 256; x--; ) {
		if (sd_cmd(58, 0, 0, 0) != 0) { goto retry; }
		t = spi_recv();
		spi_recv();
		spi_recv();
		spi_recv();
		if (t & 0x80) { // it's ready
			sd_is_hc = t & 0x40 ? 1 : 0;
			break;
		}
	}
	if (!x) { goto retry; }
	
	// if it's not SDHC then set blocklen
	if (!sd_is_hc) {
#ifdef DEBUG
	printf("%5u:sd_reset()::Sending CMD16...\n", since_us());
#endif
		if (sd_cmd(16, 0, 0x200, 0) != 0x00) { goto retry; }
	}

#ifdef DEBUG
	printf("%5u:sd_reset()::Sending CMD9...\n", since_us());
#endif

	// let's read the CSD
	if (sd_cmd(9, 0, 0, 0) != 0) { goto retry; }
#ifdef DEBUG
	printf("%5u:sd_reset()::Reading CMD9 payload...\n", since_us());
#endif
	if (sd_read_block(sd_csd, 16) != 0) { goto retry; }
#ifdef DEBUG
	printf("%5u:sd_reset()::Init done...\n", since_us());
#endif

	spi_set_cs(1); // raise CS

	// decode # of sectors (it's bits 69:48 shifted left 10)
	// also recall bit 127 is transmitted first so it's bits 69:48 from sd_csd[15] downwards...
	sd_sectors[0] = (unsigned)sd_csd[9] << 10;
	sd_sectors[1] = (sd_csd[9] >> 6) | ((unsigned)sd_csd[8] << 2) | ((unsigned)(sd_csd[7] & 0x3F) << 10);
	sd_is_init    = 1;
	return 0;
}

unsigned sd_sector_op(unsigned sector[2], unsigned char *dst, int wr_en)
{
	unsigned ret, r, x;
	
	ret = 0xFFFF;
	r = 0;
	
#ifndef SPI_FIXED
	// set SPI to our SD port
	sd_port_setup();
#endif

retry:
	spi_set_cs(0);
	if (sd_cmd(wr_en ? 24 : 17, sector[1], sector[0], 0) != 0) { goto error; }
	if (wr_en) {
		spi_transfer(0xFE);
		for (x = 0; x < 512; x++) {
			spi_transfer(dst[x]);
		}
		spi_recv();
		spi_recv();
		if ((spi_recv() & 0x1F) != 0x05) { goto error; }
		for (x = 8192; x--;) {
			if (spi_recv()) { break; }
		}
		if (x == 0) { goto error; }
	} else {
		if (sd_read_block(dst, 512) != 0) { goto error; }
	}

	ret = 0;
error:
	spi_set_cs(1);
	spi_recv();						// clock after the command
	spi_recv();
	// retry command upto 32 times before bailing
	if (ret != 0 && r++ < 32) {
		wait_ms(250);								// wait 250ms between tries
		goto retry;
	}
	return ret;
}

#endif
