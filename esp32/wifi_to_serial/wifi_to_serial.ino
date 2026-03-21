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

#define EEPROM_MAGIC          0xAA
#define EEPROM_SSID_OFFSET    1
#define EEPROM_PSK_OFFSET     (1 + STRLEN)

enum cfg_commands {
  CFG_COMMAND_SET_SSID = 0,
  CFG_COMMAND_SET_PSK = 1,
  CFG_COMMAND_SET_STORE = 2,
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
  EEPROM.end();
}

// read a string upto STRLEN-1 bytes (can terminate early with NUL)
void read_string(char *p)
{
  int x;
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
  Serial.begin(1000000);
  Serial.setRxBufferSize(128);
  Serial.setTxBufferSize(128);
  
  memset(ssid, 0, sizeof ssid);
  memset(password, 0, sizeof password);

  WiFi.mode(WIFI_STA);
  pinMode(BUILTIN_LED, OUTPUT);
  pinMode(PIN_SETUP, INPUT_PULLUP);
  digitalWrite(BUILTIN_LED, HIGH);
  server_loaded = 0;

  // try to load from EEPROM
  Serial.println("Booting...");
  if (load_eeprom() == 0) {
    Serial.println("Read settings from EERPOM trying to connect...");
    Serial.print("SSID: [");
    Serial.print(ssid);
    Serial.println("]");
    Serial.print("Password: [");
    Serial.print(password);
    Serial.println("]");
    int tries = 15;
    WiFi.begin(ssid, password); //Connect to wifi
  
    // Wait for connection  
    while (WiFi.status() != WL_CONNECTED) {   
      delay(1000);
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
  } else {
  }
}
//=======================================================================
//                    Loop
//=======================================================================

void loop() 
{
  unsigned char buf[256];
  int x, y;

  if (1 || digitalRead(PIN_SETUP) == HIGH) {
    WiFiClient client = server.available();
    
    if (client) {
      if(client.connected())
      {
        digitalWrite(BUILTIN_LED, LOW);
      }
      while(client.connected()){      
        while((x = client.available())>0){
          // read data from the connected client
          client.read(buf, x);
          Serial.write(buf, x); 
        }
        //Send Data to connected client
        while((x = Serial.available())>0)
        {
          // if service mode is disabled just copy from one to the other in bulk
          Serial.read(buf, x);
          client.write(buf, x);
        }
      }
      client.stop();
    } else {
      digitalWrite(BUILTIN_LED, HIGH);
    }
  } else {
    // handle configuration commands
    while (!Serial.available());
    switch (Serial.read()) {
      case CFG_COMMAND_SET_PSK:
        read_string(password);
        break;
      case CFG_COMMAND_SET_SSID:
        read_string(ssid);
        break;
      case CFG_COMMAND_SET_STORE:
        save_eeprom();
        ESP.restart();
        break;
    }
  }
}
//=======================================================================