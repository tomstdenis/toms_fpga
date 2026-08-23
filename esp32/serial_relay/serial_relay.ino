#define baud 230400

void setup() {
  // put your setup code here, to run once:
  Serial.begin(baud);
  Serial0.begin(baud, SERIAL_8N1, 20, 21);
}

void loop() {
  unsigned char b;
  // put your main code here, to run repeatedly:
  if (Serial.available()) {
    Serial.readBytes(&b, 1);
    Serial0.write(b);
  }
  if (Serial0.available()) {
    Serial0.readBytes(&b, 1);
    Serial.write(b);
  }
}
