/* SPI library

Assumes the entire SPI interface is on one GPIO block

*/

#ifndef SPI_FIXED
unsigned spi_cs_mask;
unsigned spi_sck_mask;
unsigned spi_miso_mask;
unsigned spi_mosi_mask;
unsigned spi_cs_mask_ds;
unsigned spi_sck_mask_ds;
unsigned spi_miso_mask_ds;
unsigned spi_mosi_mask_ds;
unsigned char spi_port;
#endif

spi_setup(unsigned port, unsigned cs_pin, unsigned sck_pin, unsigned miso_pin, unsigned mosi_pin)
{
	// default to all pulled up inputs except sck
#ifdef SPI_FIXED
	dirport(0, 0x08 | 0x01 | 0x04); // make CS, SCK, and MOSI outputs
	outport(0, (0x08 | 0x02));				// make CS/MISO high
#else
	spi_port = port;
	spi_cs_mask = (1 << cs_pin);
	spi_sck_mask = (1 << sck_pin);
	spi_miso_mask = (1 << miso_pin);
	spi_mosi_mask = (1 << mosi_pin);
	
	// the DIRSET masks
	spi_cs_mask_ds   = (~spi_cs_mask) << 8;
	spi_sck_mask_ds  = (~spi_sck_mask) << 8;
	spi_miso_mask_ds = (~spi_miso_mask) << 8;
	spi_mosi_mask_ds = (~spi_mosi_mask) << 8;

	dirport(port, spi_cs_mask | spi_sck_mask | spi_mosi_mask); // set OE bits
	outport(port, (spi_cs_mask_ds | spi_mosi_mask_ds | spi_sck_mask_ds | spi_miso_mask_ds) | spi_cs_mask);
#endif
}

// set the cs pin to cs
spi_set_cs(int cs)
{
#ifdef SPI_FIXED
	asm {
		LD 2,S
		SHL #3
		OR #$F700
		OUT $01
	}
#else
	outport(spi_port, spi_cs_mask_ds | (cs ? spi_cs_mask : 0));
#endif
}

// set the sck pin to sck
spi_set_sck(int sck)
{
#ifdef SPI_FIXED
	outport(0, (0xFF00 ^ 0x0100) | (sck ? 1 : 0));
#else
	outport(spi_port, spi_sck_mask_ds | (sck ? spi_sck_mask : 0));
#endif
}

#ifdef SPI_FIXED
unsigned spi_transfer_in()
{
	asm {
		CLR
		IN $01
		ANDB #$02
		NOT
		NOT
	}
}
#endif	

// transfer 8 bits, using loops # delay_loops per SCK half cycle
unsigned spi_transfer(unsigned out)
{
	unsigned x, y;
		
	y = 0;
	for (x = 0; x < 8; x++) {
		// SCK low phase
#ifdef SPI_FIXED
			asm {
				LD #$FE00				* enable writesel for SCK and SCK=0
				OUT $01
			}

			// write mosi
			asm {
				LD 6,S					* load out, we have to jump over x,y 
				SHR #5					* we want bit 7 at bit 2s location
				ANDB #$04
				OR #$FB00				* turn on write enable for bit 2
				OUT $01
				LD 6,S					* shift out left one
				SHL #1
				ST 6,S
			}

			// load miso
			asm {
				LD 2,S					* load y
				SHL #1					* shift left
				ST 2,S					* store it
				CLR						* ensure ACC is cleared when inputting to avoid toggling
				IN $01
				ANDB #$02				* mask for MISO
				NOT
				NOT
				OR 2,S					* or in y
				ST 2,S					* store in y
			}
			asm {
				LD #$FE01
				OUT $01
			}
#else
			spi_set_sck(0);
			// load current bit
			outport(spi_port, spi_mosi_mask_ds | ((out & 0x80) ? spi_mosi_mask : 0));
			out <<= 1;
			// read MISO
			y <<= 1;
			y |= !!((inport(spi_port, 0) & spi_miso_mask));
		// SCK high phase
			spi_set_sck(1);
#endif
	}
#ifdef SPI_FIXED
	asm {
		LD #$FE00
		OUT $01
	}
#else
	spi_set_sck(0);
#endif

	return y;
}

unsigned spi_recv()
{
	return spi_transfer(0xFF);
}
