#define baud 230400

void setup() {
  // put your setup code here, to run once:
  Serial.begin(baud);
  Serial0.begin(baud, SERIAL_8N1, 20, 21);
}

void loop() {
  // put your main code here, to run repeatedly:
  if (Serial.available()) {
    Serial0.write(Serial.read());
  }
  if (Serial0.available()) {
    Serial.write(Serial0.read());
  }
}
