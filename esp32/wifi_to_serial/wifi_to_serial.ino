// this works fine on my ESP32-C3 "NoName" Super Mini 
#include <WiFi.h>
#include <EEPROM.h>

int port = 8888;  //Port number
WiFiServer server(port);

//Server connect to WiFi Network
#define STRLEN 128
char ssid[STRLEN];  //Enter your wifi SSID
char password[STRLEN];  //Enter your wifi Password
char server_loaded;
unsigned long blink, baud = 1000000;
int first_cfg = 1;

#define EEPROM_MAGIC          0xAA
#define EEPROM_SSID_OFFSET    1
#define EEPROM_PSK_OFFSET     (1 + STRLEN)
#define EEPROM_BAUD_OFFSET    (1 + STRLEN + STRLEN)

enum cfg_commands {
  CFG_COMMAND_SET_SSID = 0,
  CFG_COMMAND_SET_PSK = 1,
  CFG_COMMAND_SET_STORE = 2,
  CFG_COMMAND_SET_BAUD = 3,
};

#define PIN_SETUP 0

// try to load settings from EEPROM
int load_eeprom(void)
{
  EEPROM.begin(512);
  if (EEPROM.read(0) == EEPROM_MAGIC) {
    Serial.println("Valid EEPROM magic in load...");
    EEPROM.readBytes(EEPROM_SSID_OFFSET, ssid, STRLEN);
    EEPROM.readBytes(EEPROM_PSK_OFFSET, password, STRLEN);
    EEPROM.readBytes(EEPROM_BAUD_OFFSET, &baud, 4);
    EEPROM.end();
    return 0;
  }
  Serial.println("no valid EEPROM magic in load...");
  return -1;
}

// store settings in eeprom
void save_eeprom(void)
{
  EEPROM.begin(512);
  Serial.println("Storing EEPROM...");
  EEPROM.write(0, EEPROM_MAGIC);
  EEPROM.writeBytes(EEPROM_SSID_OFFSET, ssid, STRLEN);
  EEPROM.writeBytes(EEPROM_PSK_OFFSET, password, STRLEN);
  EEPROM.writeBytes(EEPROM_BAUD_OFFSET, &baud, 4);
  EEPROM.end();
}

// read a string upto STRLEN-1 bytes (can terminate early with NUL)
void read_string(char *p)
{
  int x = 0;
  memset(p, 0, STRLEN);
  while (x < STRLEN-1) {
    char ch;
    while (!Serial.available());
    ch = Serial.read();
    if (!ch) {
      return;
    }
    p[x++] = ch;
  }
}

//=======================================================================
//                    Power on setup
//=======================================================================
void setup() 
{
  memset(ssid, 0, sizeof ssid);
  memset(password, 0, sizeof password);

  int loaded = load_eeprom();
  Serial.setTxBufferSize(256);
  Serial.setRxBufferSize(256);
  Serial0.setTxBufferSize(256);
  Serial0.setRxBufferSize(256);
  Serial.begin(baud);
  Serial0.begin(baud, SERIAL_8N1, 20, 21);

  WiFi.mode(WIFI_STA);
  WiFi.setTxPower(WIFI_POWER_8_5dBm);
  pinMode(BUILTIN_LED, OUTPUT);
  pinMode(PIN_SETUP, INPUT_PULLUP);
  digitalWrite(BUILTIN_LED, HIGH);
  server_loaded = 0;

  // try to load from EEPROM
  Serial.println("Booting...");
  if (digitalRead(PIN_SETUP) == HIGH && loaded == 0) {
    Serial.println("Read settings from EERPOM trying to connect...");
    Serial.print("SSID: [");
    Serial.print(ssid);
    Serial.println("]");
    Serial.print("Password: [");
    Serial.print(password);
    Serial.println("]");
    Serial.print("Baud: ");
    Serial.println(baud);
    int tries = 30;
    WiFi.begin(ssid, password); //Connect to wifi
  
    // Wait for connection  
    while (WiFi.status() != WL_CONNECTED) {   
      delay(250); yield();
      delay(250); yield();
      delay(250); yield();
      delay(250); yield();
      Serial.write('.');
      if (!--tries) {
        break;
      }
    }

    if (WiFi.status() == WL_CONNECTED) {
      Serial.println("Connected.");
      server.begin();
      server_loaded = 1;
    } else {
      Serial.println("Not connected.");
    }
  }
  blink = millis();
}
//=======================================================================
//                    Loop
//=======================================================================

void loop() 
{
  unsigned char buf[64];
  int x, y;

  if (server_loaded == 0) {
    ESP.restart();
  }

  WiFiClient client = server.accept();
  if (client) {
    if(client.connected())
    {
      digitalWrite(BUILTIN_LED, LOW);
    }
    while(client.connected()){
      yield(); // since loop() doesn't exit we need to yield to background tasks
      while((x = client.available())>0){
        if (x > sizeof(buf)) {
          x = sizeof(buf);
        }
        // read data from the connected client
        client.read(buf, x);
        Serial0.write(buf, x);
        yield();
      }
      //Send Data to connected client
      while((x = Serial0.available())>0)
      {
        if (x > sizeof(buf)) {
          x = sizeof(buf);
        }
        // if service mode is disabled just copy from one to the other in bulk
        Serial0.read(buf, x);
        Serial.write(buf, x);
        client.write(buf, x);
        yield();
      }
    }
    client.stop();
  } else {
    yield();
    if ((millis() - blink) > 250) {
      blink = millis();
      digitalWrite(BUILTIN_LED, !digitalRead(BUILTIN_LED));
    }

    /* TODO: put listening to Serial here ... */
  }
/* TODO: drop the setup pin and just parse setup commands if we receive on Serial ...
   else {
    if (first_cfg) {
      UART.end();
#ifdef USE_GPIO
      Serial0.begin(9600, SERIAL_8N1, 20, 21);
#else
      Serial.begin(9600);
#endif  
      first_cfg = 0;
    }
    if ((millis() - blink) > 1000) {
      blink = millis();
      digitalWrite(BUILTIN_LED, !digitalRead(BUILTIN_LED));
    }
    // handle configuration commands
    if (UART.available()) {
      switch (UART.read()) {
        case CFG_COMMAND_SET_PSK:
          UART.print("Received CFG_COMMAND_SET_PSK: [");
          read_string(password);
          UART.print(password);
          UART.println("]");
          break;
        case CFG_COMMAND_SET_SSID:
          UART.print("Received CFG_COMMAND_SET_SSID: [");
          read_string(ssid);
          UART.print(ssid);
          UART.println("]");
          break;
        case CFG_COMMAND_SET_BAUD:
          UART.print("Received CFG_COMMAND_SET_BAUD: ");
          UART.readBytes((char *)&baud, 4);
          UART.println(baud);
          break;
        case CFG_COMMAND_SET_STORE:
          UART.println("Received CFG_COMMAND_SET_STORE command.");
          UART.write(0xAA); // sync byte
          save_eeprom();
          ESP.restart();
          break;
      }
    }
  }
*/    
}
