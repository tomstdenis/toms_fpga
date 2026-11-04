void sram_read(int cs_pin, uint32_t address, uint8_t *dst, uint8_t len)
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

void sram_write(int cs_pin, uint32_t address, const uint8_t *src, uint8_t len)
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
