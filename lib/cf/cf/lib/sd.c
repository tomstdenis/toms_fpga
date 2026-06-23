// SD library using a Digilent style SPI micro SD PMOD
#ifndef SD_C_
#define SD_C_

#include "cf/lib/io.h"
#include "cf/lib/mem.h"
#include "cf/lib/tni.h"

#ifdef USE_BIOS

#include "cf/lib/bios.h"

sd_spi_setup()
{
	asm {
		JMP SD_SPI_SETUP
	}
}
sd_spi_set_cs(int cs)
{
	asm {
		JMP SD_SPI_SET_CS
	}
}
unsigned sd_spi_transfer(unsigned out)
{
	asm {
		JMP SD_SPI_TRANSFER
	}
}
unsigned sd_spi_recv()
{
	asm {
		JMP SD_SPI_RECV
	}
}
sd_init()
{
	asm {
		JMP SD_INIT
	}
}

unsigned sd_cmd(unsigned cmd, unsigned ph, unsigned pl, unsigned crc)
{
	asm {
		JMP SD_CMD
	}
}
int sd_read_block(unsigned char *dst, unsigned len)
{
	asm {
		JMP SD_READ_BLOCK
	}
}
int sd_reset()
{
	asm {
		JMP SD_RESET
	}
}
unsigned sd_sector_op(unsigned sector[2], unsigned char *dst, int wr_en)
{
	asm {
		JMP SD_SECTOR_OP
	}
}
#else

// Which PMOD to use (0..3)
#ifndef SD_PMOD
#define SD_PMOD 0
#endif

// Data Port
#define SD_SPI_PORT (SD_PMOD + PORT_PMOD_BASE)

// Direction Mode POrt
#define SD_SPI_PORT2 (SD_PMOD + PORT_PMOD_DIR_BASE)

#ifdef SD_BIOS
// 0xFFD0..0xFFEF for BIOS based SD lib
#define sd_is_init *((unsigned char*)sd_is_init_addr)
#define sd_is_hc *((unsigned char*)sd_is_hc_addr)
#define sd_sectors ((unsigned*)sd_sectors_addr)
#else
unsigned char sd_is_init, sd_is_hc;
unsigned sd_sectors[2];
#endif

sd_spi_setup()
{
	// default to all pulled up inputs except sck
	asm {
		LDB #$0D					* CS | SCK | MOSI as outputs
		OUT SD_SPI_PORT2
		LDB #$0A					* make CS and MISO high
		OUT SD_SPI_PORT
	}
}

// set the cs pin to cs
sd_spi_set_cs(int cs)
{
	asm {
		LD 2,S
		SHL #3
		OR #$F700
		OUT SD_SPI_PORT
	}
}

// transfer 8 bits, using loops # delay_loops per SCK half cycle
unsigned sd_spi_transfer(unsigned out)
{
	// r0 == out
	// r1 == x
	asm {
		LD 2,S
		TNI TAR0				* R0 = out (what to send)
		LDB #8
		TNI TAR1				* R1 = 8
		
?sd_spi_transfer_top EQU *
		TNI TR0A				* A = R0
		TNI ADAR0				* R0 = R0 << 1
		SHR #5					* we want bit 7 of out to be in bit 2 (mosi) location
		ANDB #4					* mask mosi bit
		OR #$FA00				* enable SCK and MOSI output (also write SCK=0)
		OUT SD_SPI_PORT			* write to PMOD0
		
		LD #$0100				* enable toggle of SCK pin
		IN SD_SPI_PORT			* read PMOD0 and toggle SCK
		ANDB #2					* mask MISO bit
		SHR #1					* shift left
		TNI ADAR0				* add MISO bit to R0 (out)
		
		TNI DECR1A				* DEC R1 and store copy in ACC
		SJNZ ?sd_spi_transfer_top
		
		LD #$FE00				* SCK bit enable, write 0
		OUT SD_SPI_PORT			* write to PMOD0
		
		TNI TR0A				* A = R0 (which now has MISO shifted in and MOSI in the upper 8 bits)
		ANDB #255				* only keep bottom bits 
	}
}

unsigned sd_spi_recv()
{
#ifdef DEBUG
	unsigned c;
	c = sd_spi_transfer(0xFF);
	printf("sd_spi_recv(): %02x\n", c);
	return c;
#else
	return sd_spi_transfer(0xFF);
#endif
}

sd_init()
{
	sd_is_hc = sd_is_init = 0;
	sd_spi_setup();
}

unsigned sd_cmd(unsigned cmd, unsigned ph, unsigned pl, unsigned crc)
{
	unsigned x, y;
	
	sd_spi_recv();
	sd_spi_recv();
	sd_spi_transfer(0x40 + cmd);
	sd_spi_transfer(ph>>8);
	sd_spi_transfer(ph&0xFF);
	sd_spi_transfer(pl>>8);
	sd_spi_transfer(pl&0xFF);
	sd_spi_transfer(crc);
	
	// wait for R1 byte
	for (x = 256; x--; ) {
		y = sd_spi_recv();
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
#ifdef DEBUG
	printf("sd_read_block: Reading %u bytes to %04x\n", len, dst);
#endif
	// wait for READ_TOKEN
	for (x = 8192; x--;) {
		t = sd_spi_recv();
		if (t == 0xFE) {
#ifdef DEBUG
	printf("sd_read_block: Got READ_TOKEN at x==%u\n", x);
#endif
			for (x = len; x--; ) {
				*dst++ = sd_spi_recv();
			}
			sd_spi_recv(); // skip CRC
			sd_spi_recv();
			return 0;
		}
	}
	return -1;
}

int sd_reset()
{
	unsigned x, y, t;
	unsigned char sd_csd[16];

	y        = 0;
retry:
#ifdef DEBUG
	since_us();
	printf("sd_reset()::Try %d\n", y);
#endif
	sd_is_hc   = sd_is_init = 0;
	if (++y == 16) {
		return -1;
	}

	// make CS high
	sd_spi_set_cs(1);
	
	// toggle SCK 80 times
	for (x = 10; x--;) {
		sd_spi_recv();
	}
	
	// make CS low
	sd_spi_set_cs(0);
	
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
	if ((sd_spi_recv() + sd_spi_recv() + sd_spi_recv() + sd_spi_recv()) != 0xAB) goto retry;

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
		t = sd_spi_recv();
		sd_spi_recv();
		sd_spi_recv();
		sd_spi_recv();
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

	sd_spi_set_cs(1); // raise CS

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

retry:
	sd_spi_set_cs(0);
#ifdef SD_NO_WRITE
	if (sd_cmd(17, sector[1], sector[0], 0) != 0) { goto error; }
#else
	if (sd_cmd(wr_en ? 24 : 17, sector[1], sector[0], 0) != 0) { goto error; }
#endif
#ifndef SD_NO_WRITE
	if (wr_en) {
		sd_spi_transfer(0xFE);
		for (x = 0; x < 512; x++) {
			sd_spi_transfer(dst[x]);
		}
		sd_spi_recv();
		sd_spi_recv();
		if ((sd_spi_recv() & 0x1F) != 0x05) { goto error; }
		for (x = 8192; x--;) {
			if (sd_spi_recv()) { break; }
		}
		if (x == 0) { goto error; }
	} else {
#endif
		if (sd_read_block(dst, 512) != 0) { goto error; }
#ifndef SD_NO_WRITE
	}
#endif

	ret = 0;
error:
	sd_spi_set_cs(1);
	sd_spi_recv();						// clock after the command
	sd_spi_recv();
	// retry command upto 32 times before bailing
	if (ret != 0 && r++ < 32) {
		wait_ms(250);								// wait 250ms between tries
		goto retry;
	}
	return ret;
}

#endif
#endif
