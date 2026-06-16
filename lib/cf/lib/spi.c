/* SPI library

Assumes the entire SPI interface is on one GPIO block

*/

unsigned spi_cs_mask;
unsigned spi_sck_mask;
unsigned spi_miso_mask;
unsigned spi_mosi_mask;
unsigned spi_cs_mask_ds;
unsigned spi_sck_mask_ds;
unsigned spi_miso_mask_ds;
unsigned spi_mosi_mask_ds;
int spi_port;

spi_setup(int port, int cs_pin, int sck_pin, int miso_pin, int mosi_pin)
{
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
	
	// default to all pulled up inputs except sck
	outport(port, 0x00FF & ~spi_sck_mask);
}

// set the cs pin to cs
spi_set_cs(int cs)
{
	outport(spi_port, spi_cs_mask_ds | (cs ? spi_cs_mask : 0));
}

// set the sck pin to sck
spi_set_sck(int sck)
{
	outport(spi_port, spi_sck_mask_ds | (sck ? spi_sck_mask : 0));
}

// transfer 8 bits, using loops # delay_loops per SCK half cycle
unsigned spi_transfer(unsigned out, unsigned delay_us)
{
	unsigned x, y;
		
	y = 0;
	for (x = 0; x < 8; x++) {
		// SCK low phase
			// load current bit
			outport(spi_port, spi_mosi_mask_ds | ((out & 0x80) ? spi_mosi_mask : 0));
			out <<= 1;
			// delay for SCK half cycle
			wait_us(delay_us);
			// read MISO
			y <<= 1;
			y |= (inport(spi_port, 0) & spi_miso_mask) ? 1 : 0;
		// SCK high phase
			spi_set_sck(1);
			wait_us(delay_us);
			spi_set_sck(0);
	}
	return y;
}
