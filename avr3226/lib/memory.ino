#include "SPI.h"

// also works as eeprom_read()
// 23A1024 SRAM
void sram_read(int cs_pin, uint32_t address, uint8_t *dst, uint16_t len)
{
  // bring CS low
  digitalWrite(cs_pin, LOW);
  SPI.beginTransaction(SPISettings(10000000, MSBFIRST, SPI_MODE0)); // adjust clock speed per your SRAM specs
  SPI.transfer(0x03);
  SPI.transfer((address>>16)&0xFF);
  SPI.transfer((address>>8)&0xFF);
  SPI.transfer(address&0xFF);
  while (len--) {
    *dst++ = SPI.transfer(0xFF);
  }
  SPI.endTransaction();
  digitalWrite(cs_pin, HIGH);
}
#define eeprom_read sram_read

void sram_write(int cs_pin, uint32_t address, const uint8_t *src, uint16_t len)
{
  // bring CS low
  digitalWrite(cs_pin, LOW);
  SPI.beginTransaction(SPISettings(10000000, MSBFIRST, SPI_MODE0)); // adjust clock speed per your SRAM specs
  SPI.transfer(0x02);
  SPI.transfer((address>>16)&0xFF);
  SPI.transfer((address>>8)&0xFF);
  SPI.transfer(address&0xFF);
  while (len--) {
    SPI.transfer(*src++);
  }
  SPI.endTransaction();
  digitalWrite(cs_pin, HIGH);
}

// 23CSM01 EEPROM
void eeprom_wait_wip(int cs_pin)
{
  // wait while writing
  uint8_t status;
  do {
    digitalWrite(cs_pin, LOW);
    SPI.beginTransaction(SPISettings(10000000, MSBFIRST, SPI_MODE0)); // adjust clock speed per your SRAM specs
    SPI.transfer(0x05); // RDSR read status register
    status = SPI.transfer(0xFF);
    SPI.endTransaction();
    digitalWrite(cs_pin, HIGH);
  } while (status & 1);
}

void eeprom_write(int cs_pin, uint32_t address, const uint8_t *src, uint16_t len)
{
  // make sure there isn't a write in progress
  eeprom_wait_wip(cs_pin);

  // enable write latch
  digitalWrite(cs_pin, LOW);
  SPI.beginTransaction(SPISettings(10000000, MSBFIRST, SPI_MODE0)); // adjust clock speed per your SRAM specs
  SPI.transfer(0x06); // WREN write enable
  SPI.endTransaction();
  digitalWrite(cs_pin, HIGH);

  // write buffer
  digitalWrite(cs_pin, LOW);
  SPI.beginTransaction(SPISettings(10000000, MSBFIRST, SPI_MODE0)); // adjust clock speed per your SRAM specs
  SPI.transfer(0x02);
  SPI.transfer((address>>16)&0xFF);
  SPI.transfer((address>>8)&0xFF);
  SPI.transfer(address&0xFF);
  while (len--) {
    SPI.transfer(*src++);
  }
  SPI.endTransaction();
  digitalWrite(cs_pin, HIGH);

  // wait for WIP
  eeprom_wait_wip(cs_pin);
}
