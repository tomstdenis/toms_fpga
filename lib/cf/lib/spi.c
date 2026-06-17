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
#else
#include "lib/tni.h"
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
#ifndef SPI_FIXED
	unsigned x;
	x = 8;
	for (x = 8; x--;) {
#endif
		// SCK low phase
#ifdef SPI_FIXED
			// write mosi
			// r0 == out
			// r1 == x
			asm {
				LD 2,S
				TNI TAR0				* R0 = out
				LDB #8
				TNI TAR1				* R1 = 8
				
?spi_transfer_top EQU *
				TNI TR0A				* A = R0
				TNI ADAR0				* R0 = R0 << 1
				SHR #5					* we want bit 7 of out to be in bit 2 (mosi) location
				ANDB #4					* mask mosi bit
				OR #$FA00				* enable SCK and MOSI output (also write SCK=0)
				OUT $01					* write to PMOD0
				
				LD #$0100				* enable toggle of SCK pin
				IN $01					* read PMOD0 and toggle SCK
				ANDB #2					* mask MISO bit
				SHR #1					* shift left
				TNI ADAR0				* add MISO bit to R0 (out)
				
				TNI DECR1A				* DEC R1 and store copy in ACC
				SJNZ ?spi_transfer_top
				
				LD #$FE00				* SCK bit enable, write 0
				OUT $01					* write to PMOD0
				
				TNI TR0A				* A = R0
				ANDB #255				* only keep bottom bits 
				RET
			}
#else
			spi_set_sck(0);
			// load current bit
			outport(spi_port, spi_mosi_mask_ds | ((out & 0x80) ? spi_mosi_mask : 0));
			out <<= 1;
			// read MISO
			out |= !!((inport(spi_port, 0) & spi_miso_mask));
		// SCK high phase
			spi_set_sck(1);
	}
#endif
	
	// exit with clock low
#ifndef SPI_FIXED
	spi_set_sck(0);
	return out;
#endif
}

unsigned spi_recv()
{
	return spi_transfer(0xFF);
}
