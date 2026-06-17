// SD library

unsigned char sd_is_init, sd_is_hc, sd_port, sd_cs_pin, sd_sck_pin, sd_miso_pin, sd_mosi_pin;
unsigned sd_sectors[2];
unsigned char sd_csd[16], sd_read_error;

sd_init(unsigned port, unsigned cs, unsigned sck, unsigned miso, unsigned mosi)
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
	
	spi_recv();
	spi_recv();
	spi_transfer(0x40 + cmd);
	spi_transfer(ph>>8);
	spi_transfer(ph&0xFF);
	spi_transfer(pl>>8);
	spi_transfer(pl&0xFF);
	spi_transfer(crc);
	
	// wait for R1 byte
	for (x = 256; x; x--) {
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

unsigned sd_cmd13_status()
{
	if (sd_cmd(13, 0, 0, 0) == 0) {
		return spi_recv();
	} else {
		return 0xFFFF;
	}
}

// read a block, when called we're expecting a read token 0xFE coming up at some point
int sd_read_block(unsigned char *dst, unsigned len)
{
	unsigned x, t;
	// wait for READ_TOKEN
	for (x = 256; x--;) {
		t = spi_recv();
		if (t == 0xFE) {
			break;
		}
		if (!(t&(0x80|0x40|0x20))) {
			sd_read_error = t & 0x1F;
			return -1;
		}
	}
	if (!x) { return -1; }

	// now payload
	for (x = len; x--; ) {
		*dst++ = spi_recv();
	}
	spi_recv(); // skip CRC
	spi_recv();
	return 0;
}

sd_port_setup()
{
	spi_setup(sd_port, sd_cs_pin, sd_sck_pin, sd_miso_pin, sd_mosi_pin);
}

int sd_reset()
{
	unsigned x, y, t;

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
	
	// set SPI to our SD port
	sd_port_setup();

	// make CS high
	spi_set_cs(1);
	
	// toggle SCK 80 times
	for (x = 0; x < 10; x++) {
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
	if (spi_recv() != 0x00) { goto retry; }
	if (spi_recv() != 0x00) { goto retry; }
	if (spi_recv() != 0x01) { goto retry; }
	if (spi_recv() != 0xAA) { goto retry; }

#ifdef DEBUG
	printf("%5u:sd_reset()::Sending ACMD41...\n", since_us());
#endif
	
	// loop on ACMD41 which is CMD55/CMD41(0x40000000)
	for (x = 256; x; x--) {
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
	for (x = 256; x; x--) {
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

sd_tail()
{
	spi_set_cs(1);
	spi_recv();						// clock after the command
	spi_recv();
}

unsigned sd_read_sector(unsigned sector[2], unsigned char *dst)
{
	unsigned ret, r;
	
	ret = 0xFFFF;
	r = 0;
	
	// set SPI to our SD port
	sd_port_setup();

	spi_set_cs(0);
retry:	
	if (sd_cmd(17, sector[1], sector[0], 0) != 0) { goto error; }
	if (sd_read_block(dst, 512) != 0) { goto error; }
	
	ret = 0;
error:
	// retry command upto 10 times before bailing
	if (ret != 0 && r++ < 10) {
		wait_ms(10);								// wait 10ms between tries
		goto retry;
	}
	sd_tail();
	return ret;
}

unsigned sd_write_sector(unsigned sector[2], unsigned char *dst)
{
	unsigned ret, r, x;
	
	ret = 0xFFFF;
	r = 0;
	
	// set SPI to our SD port
	sd_port_setup();

retry:	
	spi_set_cs(0);
	if (sd_cmd(24, sector[1], sector[0], 0) != 0) { goto error; }
	spi_transfer(0xFE);
	for (x = 0; x < 512; x++) {
		spi_transfer(dst[x]);
	}
	spi_transfer(0x00);
	spi_transfer(0x00);
	if ((spi_transfer(0xFF) & 0x1F) != 0x05) { goto error; }
	for (x = 0; x < 256; x++) {
		if (spi_recv()) { break; }
	}
	if (x == 256) { goto error; };
	
	ret = 0;
error:
	sd_tail();
	// retry command upto 32 times before bailing
	if (ret != 0 && r++ < 32) {
		wait_ms(250);								// wait 250ms between tries
		goto retry;
	}
	return ret;
}
