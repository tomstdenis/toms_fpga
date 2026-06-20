/* SPI library

Assumes the entire SPI interface is on one GPIO block

define SPI_MOD before including this to change which PMOD to use
or use the default PMOD0

*/
#ifndef SPI_C_
#define SPI_C_

#include "lib/io.h"

// Which PMOD to use
#ifndef SPI_PMOD
#define SPI_PMOD 0
#endif

// Data Port
#define SPI_PORT (SPI_PMOD + PORT_PMOD_BASE)

// Direction Mode POrt
#define SPI_PORT2 (SPI_PMOD + PORT_PMOD_DIR_BASE)

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
#else
#include "lib/tni.h"
#endif

#ifdef SPI_FIXED
spi_setup_fixed()
#else
spi_setup(unsigned port, unsigned cs_pin, unsigned sck_pin, unsigned miso_pin, unsigned mosi_pin)
#endif
{
	// default to all pulled up inputs except sck
#ifdef SPI_FIXED
	asm {
		LDB #$0D					* CS | SCK | MOSI as outputs
		OUT SPI_PORT2
		LDB #$0A					* make CS and MISO high
		OUT SPI_PORT
	}
#else
	spi_port = port;
	spi_cs_mask = (1 << cs_pin);
	spi_sck_mask = (1 << sck_pin);
	spi_miso_mask = (1 << miso_pin);
	spi_mosi_mask = (1 << mosi_pin);
	
	// the WRITESEL masks
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
		OUT SPI_PORT
	}
#else
	outport(spi_port, spi_cs_mask_ds | (cs ? spi_cs_mask : 0));
#endif
}

unsigned spi_transfer(unsigned out)
{
#ifdef SPI_FIXED
	// write mosi
	// r0 == out
	// r1 == x
	asm {
		LD 2,S
		TNI TAR0				* R0 = out (what to send)
		LDB #8
		TNI TAR1				* R1 = 8
		
?spi_transfer_top EQU *
		TNI TR0A				* A = R0
		TNI ADAR0				* R0 = R0 << 1
		SHR #5					* we want bit 7 of out to be in bit 2 (mosi) location
		ANDB #4					* mask mosi bit
		OR #$FA00				* enable SCK and MOSI output (also write SCK=0)
		OUT SPI_PORT			* write to PMOD0
		
		LD #$0100				* enable toggle of SCK pin
		IN SPI_PORT				* read PMOD0 and toggle SCK
		ANDB #2					* mask MISO bit
		SHR #1					* shift left
		TNI ADAR0				* add MISO bit to R0 (out)
		
		TNI DECR1A				* DEC R1 and store copy in ACC
		SJNZ ?spi_transfer_top
		
		LD #$FE00				* SCK bit enable, write 0
		OUT SPI_PORT			* write to PMOD0
		
		TNI TR0A				* A = R0 (which now has MISO shifted in and MOSI in the upper 8 bits)
		ANDB #255				* only keep bottom bits 
	}
#else
	unsigned x;
	for (x = 0; x < 8; x++) {
		outport(spi_port, (spi_mosi_mask_ds&spi_sck_mask_ds) | ((out & 0x80) ? spi_mosi_mask : 0)); // write MOSI and SCK=0
		out <<= 1;
		out |= !!((inport(spi_port, spi_sck_mask << 8) & spi_miso_mask));							// read MISO and toggle SCK back to 1
	}
	// exit with clock low
	spi_set_sck(0);
	return out&0xFF;
#endif
}

unsigned spi_recv()
{
#ifdef DEBUG
	unsigned c;
	c = spi_transfer(0xFF);
	printf("spi_recv(): %02x\n", c);
	return c;
#else
	return spi_transfer(0xFF);
#endif
}

#endif
