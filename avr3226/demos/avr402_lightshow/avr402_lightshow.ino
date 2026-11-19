/*

AVR tiny402 based lightshow.  Uses a SPI EEPROM to bang out a preformatted bit stream where the MISO
pin is also tied to a WS2182b string.  The TX pin is being used for CS so we turn on the transmitted as
required.

This uses a 9600 baud serial connection (ultimately an HC-12).

Each "frame" can be up to 1024 bytes which includes 2 bytes of trailer and 9 bytes per LED which is preformatted
into HLL and HHL bit patterns by the PC.

The gist is the EEPROM SO is also commoned to the first LEDs data in pin.  The AVR clocks out 3 times per RGB bit at 3x
the sample rate.  The PC can program a 32 byte block of EEPROM by transmitting the first byte of a 24-bit address (32 byte aligned),
reading a 0x54 ACK, then writing the remaining 2 bytes of the address, reading a 0x55, then writing the 32 bytes, reading a 0x56,
then waiting to read a 0x57.  At that point the 32 bytes are programmed.

This allows me to have many patterns controlled by a tiny ass 8-pin 8-bit MCU cuz I'm crazy like this.  In my setup I'm using
a 1Mbit EEPROM which allows me to have 128 patterns.

*/

#include <avr/io.h>

// each LED consumes 9 bytes, each frame has a 2 byte trailer, so LEDS * 9 + 2 bytes are used. Must be smaller than or equal
// to 1024 (113 LEDs max).
#define LEDS 16

#define BAUDRATE 9600        // HC-12 default baud rate

uint8_t uart_timedout = 0;

void usart_rx_only_init(void) {
    // BAUD = (64 * F_CPU) / (16 * baud_rate) = (4 * F_CPU) / baud_rate
    USART0.BAUD = (uint16_t)((4.0 * F_CPU) / BAUDRATE);

    // - Enable Receiver ONLY: Set RXEN bit, leave TXEN bit cleared.
    // - Frame format: 8 data bits, no parity, 1 stop bit (default 8N1).
    USART0.CTRLB = USART_RXEN_bm; 
}

uint8_t usart_read_available(void) {
    return USART0.STATUS & USART_RXCIF_bm;
}

uint8_t usart_read_byte(uint8_t timeout) {
    // Wait until data is received in the buffer
    uint16_t time_ms = millis() + 3000;
    if (uart_timedout) {
      return 0;
    }
    while (!(USART0.STATUS & USART_RXCIF_bm)) {
      if (timeout && millis() >= time_ms) {
        uart_timedout = 1;
        return 0;
      }
    }
    
    // Reading USART0.RXDATAL automatically clears the flag
    return USART0.RXDATAL; 
}

void usart_tx_control(uint8_t enable) {
    if (enable) {
        USART0.CTRLB |= USART_TXEN_bm;  // Enable transmitter
    } else {
        USART0.CTRLB &= ~USART_TXEN_bm; // Disable transmitter
    }
}

void usart_send_byte(uint8_t data) {
    // Wait until DREIF (Data Register Empty Flag) is set
    while (!(USART0.STATUS & USART_DREIF_bm));
    
    // Write data to transmit low data register
    USART0.TXDATAL = data;
}

uint8_t spi_transfer_byte(uint8_t tx_data) {
    SPI0.DATA = tx_data;                  // Writing to DATA triggers the transfer
    while (!(SPI0.INTFLAGS & SPI_RXCIF_bm)); // Poll the Interrupt Flag for completion
    return SPI0.DATA;                     // Reading DATA returns the received MISO byte and clears flags
}

// EEPROM CS enable/disabled
void eeprom_select(void) {
    PORTA.OUTCLR = PIN6_bm; // Drive CS low
}

void eeprom_deselect(void) {
    PORTA.OUTSET = PIN6_bm; // Drive CS high
}

// 23CSM01 EEPROM
// Wait for Write-in-progress
void eeprom_wait_wip()
{
  // wait while writing
  uint8_t status;
  do {
    eeprom_select();
    spi_transfer_byte(0x05);
    status = spi_transfer_byte(0x00); // RDSR read status reg
    eeprom_deselect();
  } while (status & 1);
}

// Note: You cannot cross page boundaries on my 23CSM01 it's 256 byte pages but on
// other EEPROMs it could be smaller (64, 128 bytes, etc...)
void eeprom_write(uint32_t addr, const uint8_t *src, uint16_t len)
{
  // make sure there isn't a write in progress
  eeprom_wait_wip();

  // enable write latch
  eeprom_select();
  spi_transfer_byte(0x06);
  eeprom_deselect();

  // write buffer to EEPROM buffer
  eeprom_select();
  spi_transfer_byte(0x02);
  spi_transfer_byte((addr>>16)&0xFF);
  spi_transfer_byte((addr>>8)&0xFF);
  spi_transfer_byte((addr)&0xFF);
  while (len--) {
    spi_transfer_byte(*src++);
  }
  eeprom_deselect();

  // wait for EEPROM to commit buffer to NV memory
  eeprom_wait_wip();
}

// this is meant to clock the RGB data and then read the framing bytes at the end
uint16_t spi_burst_and_read16(uint32_t addr, uint16_t total_transfers) {
    // select chip
    eeprom_select();

    // write READ command and address
    spi_transfer_byte(0x03);
    spi_transfer_byte((addr>>16)&0xFF);
    spi_transfer_byte((addr>>8)&0xFF);
    spi_transfer_byte((addr)&0xFF);

    // Kick off the first byte
    SPI0.DATA = 0x00;
    total_transfers--;

    // Stream the remaining burst bytes back-to-back with zero gaps
    while (total_transfers > 0) {
        while (!(SPI0.INTFLAGS & SPI_DREIF_bm)); // Wait for holding register empty
        SPI0.DATA = 0x00;
        total_transfers--;
    }

    // Wait for the final burst byte to finish shifting out completely
    while (!(SPI0.INTFLAGS & SPI_IF_bm));
    (void)SPI0.DATA; // Dummy read to clear receive buffer flag

    // Immediately clock in the next 16 bits (2 bytes) from MISO
    // Sending 0x00 dummy bytes keeps SCK toggling to read the EEPROM framing payload
    uint8_t hi_byte = spi_transfer_byte(0x00);
    uint8_t lo_byte = spi_transfer_byte(0x00);

    eeprom_deselect();

    return ((uint16_t)hi_byte << 8) | lo_byte;
}

void spi_init(void) {
    // Set Pin Directions on PORTA
    // MOSI (PA1) -> Output
    // MISO (PA2) -> Input
    // SCK (PA3)  -> Output
    // CS   (PA6)  -> Output (Default HIGH to keep EEPROM deselected)
    PORTA.DIRSET = PIN1_bm | PIN3_bm | PIN6_bm;
    PORTA.DIRCLR = PIN2_bm;
    
    // Set CS/PA6 high initially so the EEPROM is idle
    PORTA.OUTSET = PIN6_bm;

    // Initialize SPI Peripheral (Host Mode)
    // Enable SPI, set as Host (Master), and choose clock prescaler (e.g., DIV4)
    // 20MHz / 2 / 4 => 2.5MHz
    SPI0.CTRLA = SPI_ENABLE_bm | SPI_MASTER_bm | SPI_PRESC_DIV4_gc;
    
    // 4. Enable Double Buffer mode for zero inter-byte jitter during WS2812B streaming
    SPI0.CTRLB = SPI_BUFEN_bm;
}

uint8_t active, frame_idx, frame_delay;

void setup() {
  usart_rx_only_init();
  spi_init();
  frame_idx = 0;
  active    = 1;
}

void loop() {
  uint16_t frame_data;
  uint32_t addr;
  uint8_t x, y, buf[32];
  if (usart_read_available()) {
    // turn off LED string
    active = 0;

    // read address 
    usart_tx_control(1);
    x = usart_read_byte(1); usart_send_byte(x); addr = x & ~0x1F; // ACK first byte, align to 32 bytes
    x = usart_read_byte(1); usart_send_byte(x); addr = (addr << 8) | x;
    x = usart_read_byte(1); usart_send_byte(x); addr = (addr << 8) | x;
    if (addr == 0xFFFF00) {
      // special address to turn LED back on
      active = 1;
    } else {
      // read payload
      for (y = 0; y < 32; y++) {
        buf[y] = usart_read_byte(1);
        if (uart_timedout) {
          uart_timedout = 0;
          active        = 1;
          frame_idx     = 0; // reset frame IDX
          usart_tx_control(0);
          return;
        }
        if ((y & 7) == 7) {
          usart_send_byte(buf[y]);
        }
      }
      usart_tx_control(0);          // turn off UART TX for SPI command
      eeprom_write(addr, buf, 32);
      usart_tx_control(1);          // turn on UART TX to ACK eepromg write
      usart_send_byte(0x55);        // ACK eeprom write
    }
    usart_tx_control(0);
    frame_idx = 0; // reset frame IDX
  }
  if (active) {
    frame_data  = spi_burst_and_read16((uint32_t)frame_idx << 10, LEDS);
    frame_idx   = (frame_data >> 8);
    frame_delay = (frame_data & 0xFF);
    delay(((uint16_t)frame_delay + 1) * 10);
  }
}
