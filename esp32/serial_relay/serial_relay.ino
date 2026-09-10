#define baud 1000000

uint32_t tick;
void setup() {
  // put your setup code here, to run once:
  Serial.begin(baud);
  Serial0.begin(baud, SERIAL_8N1, 20, 21);
  pinMode(LED_BUILTIN, OUTPUT);
  digitalWrite(LED_BUILTIN, 0);
  tick = 0;
}
void loop() {
  unsigned char b;
  // put your main code here, to run repeatedly:
  while (Serial.available()) {
    digitalWrite(BUILTIN_LED, !digitalRead(BUILTIN_LED));
    tick = millis();
    Serial.readBytes(&b, 1);
    Serial0.write(b);
  }
  while (Serial0.available()) {
    digitalWrite(BUILTIN_LED, !digitalRead(BUILTIN_LED));
    tick = millis();
    Serial0.readBytes(&b, 1);
    Serial.write(b);
  }
  if (tick && millis() - tick > 100) {
    digitalWrite(BUILTIN_LED, !digitalRead(BUILTIN_LED));
    tick = 0;
  }
}
