#include "SPI.h"

// start a memory transaction
void spi_mem_start_cmd(int cs_pin, uint32_t address, uint8_t cmd)
{
  digitalWrite(cs_pin, LOW);
  SPI.beginTransaction(SPISettings(10000000, MSBFIRST, SPI_MODE0)); // adjust clock speed per your SRAM specs
  SPI.transfer(cmd);
  SPI.transfer((address>>16)&0xFF);
  SPI.transfer((address>>8)&0xFF);
  SPI.transfer(address&0xFF);
}

// send a single byte command and return the next byte read
uint8_t spi_mem_single_cmd(int cs_pin, uint8_t cmd)
{
  uint8_t res;
  digitalWrite(cs_pin, LOW);
  SPI.beginTransaction(SPISettings(10000000, MSBFIRST, SPI_MODE0)); // adjust clock speed per your SRAM specs
  SPI.transfer(cmd); // WREN write enable
  res = SPI.transfer(0xFF);
  SPI.endTransaction();
  digitalWrite(cs_pin, HIGH);
  return res;
}

void spi_mem_single_pulse(int cs_pin, uint8_t cmd)
{
  uint8_t res;
  digitalWrite(cs_pin, LOW);
  SPI.beginTransaction(SPISettings(10000000, MSBFIRST, SPI_MODE0)); // adjust clock speed per your SRAM specs
  SPI.transfer(cmd); // WREN write enable
  SPI.endTransaction();
  digitalWrite(cs_pin, HIGH);
}

void spi_mem_end_cmd(int cs_pin)
{
  SPI.endTransaction();
  digitalWrite(cs_pin, HIGH);
}

// also works as eeprom_read()
// 23A1024 SRAM
// read a block of memory into CPU memory
void sram_read(int cs_pin, uint32_t address, uint8_t *dst, uint16_t len)
{
  spi_mem_start_cmd(cs_pin, address, 0x03);
  while (len--) {
    *dst++ = SPI.transfer(0xFF);
  }
  spi_mem_end_cmd(cs_pin);
}
#define eeprom_read sram_read

// write CPU memory out to SPI SRAM memory 
void sram_write(int cs_pin, uint32_t address, const uint8_t *src, uint16_t len)
{
  spi_mem_start_cmd(cs_pin, address, 0x02);
  while (len--) {
    SPI.transfer(*src++);
  }
  spi_mem_end_cmd(cs_pin);
}

// 23CSM01 EEPROM
// Wait for Write-in-progress
void eeprom_wait_wip(int cs_pin)
{
  // wait while writing
  uint8_t status;
  do {
    status = spi_mem_single_cmd(cs_pin, 0x05); // RDSR read status reg
  } while (status & 1);
}

// Write from CPU memory to EEPROM memory
// Note: You cannot cross page boundaries on my 23CSM01 it's 256 byte pages but on
// other EEPROMs it could be smaller (64, 128 bytes, etc...)
void eeprom_write(int cs_pin, uint32_t address, const uint8_t *src, uint16_t len)
{
  // make sure there isn't a write in progress
  eeprom_wait_wip(cs_pin);

  // enable write latch
  spi_mem_single_pulse(cs_pin, 0x06); // WREN write enable

  // write buffer to EEPROM buffer (SRAM write and EEPROM write are the same command one you enable the write latch)
  sram_write(cs_pin, address, src, len);

  // wait for EEPROM to commit buffer to NV memory
  eeprom_wait_wip(cs_pin);
}
