#define baud 1000000

uint32_t tick = 0;
bool led_state = false;

void setup() {
  // Bump hardware buffers to avoid overruns at 1 MBaud
  Serial.setTxBufferSize(2048);
  Serial.setRxBufferSize(2048);
  Serial0.setTxBufferSize(2048);
  Serial0.setRxBufferSize(2048);
  
  Serial.begin(baud);
  Serial0.begin(baud, SERIAL_8N1, 20, 21);
  
  pinMode(LED_BUILTIN, OUTPUT);
  digitalWrite(LED_BUILTIN, LOW);
}

void loop() {
  uint8_t buf[256];
  
  // 1. Bulk forward: Serial -> Serial0
  int avail = Serial.available();
  if (avail > 0) {
    int to_read = min(avail, (int)sizeof(buf));
    int bytes_read = Serial.readBytes((char*)buf, to_read);
    Serial0.write(buf, bytes_read);
    
    tick = millis();
    led_state = true;
  }

  // 2. Bulk forward: Serial0 -> Serial
  int avail0 = Serial0.available();
  if (avail0 > 0) {
    int to_read0 = min(avail0, (int)sizeof(buf));
    int bytes_read0 = Serial0.readBytes((char*)buf, to_read0);
    Serial.write(buf, bytes_read0);
    
    tick = millis();
    led_state = true;
  }

  // 3. Low-overhead LED status activity blinker
  if (led_state && (millis() - tick > 50)) {
    led_state = false;
    digitalWrite(LED_BUILTIN, LOW);
  } else if (led_state) {
    digitalWrite(LED_BUILTIN, HIGH);
  }
}