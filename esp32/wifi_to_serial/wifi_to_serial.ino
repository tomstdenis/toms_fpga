// this works fine on my ESP32-C3 "NoName" Super Mini 
#include <WiFi.h>
#include <EEPROM.h>

// size of the local buffer
#define LB_SIZE 64
static unsigned char linebuf[LB_SIZE];

// size of TCP ring buffer
#define RB_SIZE 4096
static struct {
  unsigned char rb[RB_SIZE];
  unsigned wptr, rptr, left;
} tcp_rb, ser_rb;

#define debug 0

static int port = 8888;  //Port number
static WiFiServer server(port);

//Server connect to WiFi Network
#define STRLEN 128
static char ssid[STRLEN];  //Enter your wifi SSID
static char password[STRLEN];  //Enter your wifi Password
static int server_loaded, serial_input = 0;
static unsigned long blink, baud = 1000000;
static int first_cfg = 1;

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
static int load_eeprom(void)
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
static void save_eeprom(void)
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
static void read_string(char *p)
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
  int x, y;

  if (server_loaded == 0) {
    ESP.restart();
  }

  WiFiClient client = server.accept();
  if (client) {
    if(client.connected())
    {
      digitalWrite(BUILTIN_LED, LOW);
      // reset tcp ring buffer
      memset(&tcp_rb, 0, sizeof tcp_rb);
      tcp_rb.left = sizeof tcp_rb.rb;

      // reset serial ring buffer
      memset(&ser_rb, 0, sizeof ser_rb);
      ser_rb.left = sizeof ser_rb.rb;

      client.flush();
    }
    while(client.connected()){
      yield(); // since loop() doesn't exit we need to yield to background tasks

      if (debug) Serial.printf("line: %d\n", __LINE__);

      // fill from TCP into local buffer
      while ((x = client.available())) {
        if (debug) Serial.printf("%d bytes avaialble from TCP\n", x);
        // we can fill at most the least of x, left, sizeof buf bytes
        if (x > tcp_rb.left) {
          x = tcp_rb.left;
        }
        if (x > sizeof(linebuf)) {
          x = sizeof(linebuf);
        }
        if (!x) {
          if (debug) Serial.printf("TCP ring buffer is full!\n");
          break;
        }
        if (debug) Serial.printf("Reading %d bytes\n", x);
        x = client.read(linebuf, x);
        if (debug) Serial.printf("Read %d bytes\n", x);
        y = 0;
        while (x--) {
          tcp_rb.rb[tcp_rb.wptr++] = linebuf[y++];
          if (tcp_rb.wptr == RB_SIZE) {
            tcp_rb.wptr = 0;
          }
          tcp_rb.left--;
        }
      }

      if (debug) Serial.printf("line: %d\n", __LINE__);

      // read from device serial to relay out over wifi and CDC
      while((x = Serial0.available())>0)
      {
        x = sizeof(linebuf);
        if (x > ser_rb.left) {
          x = ser_rb.left;
        }
        if (!x) {
          break;
        }
        // if service mode is disabled just copy from one to the other in bulk
        x = Serial0.read(linebuf, x);
        if (debug) Serial.printf("%d bytes read from device serial\n", x);
        y = 0;
        while (x--) {
          ser_rb.rb[ser_rb.wptr++] = linebuf[y++];
          if (ser_rb.wptr == RB_SIZE) {
            ser_rb.wptr = 0;
          }
          ser_rb.left--;
        }
      }

      if (debug) Serial.printf("line: %d, tcpleft == %d\n", __LINE__, tcp_rb.left);

      // write one TCP byte per loop since this might block and take time
      // note you may want to avoid writing more at any time than your device Serial FIFO
      // if we write 128 bytes here but your Serial FIFO is only 16 bytes it could drop
      // a lot if the device is busy doing something else.
      // also if you write more than 1 byte at a time you may want to check if there's 
      // Serial to read in the same loop
      if (tcp_rb.left != RB_SIZE) {
        Serial0.write(tcp_rb.rb[tcp_rb.rptr]);
        tcp_rb.rptr++;
        if (tcp_rb.rptr == RB_SIZE) {
          tcp_rb.rptr = 0;
        }
        tcp_rb.left++;
      }

      if (debug) Serial.printf("line: %d, serleft == %d\n", __LINE__, ser_rb.left);

      // write upto linebuf at a time
      // the TCP stack should have reasonable ability to buffer things
      if (ser_rb.left != RB_SIZE) {
        y = 0;
        while (y < LB_SIZE && ser_rb.rptr != ser_rb.wptr) {
          linebuf[y++] = ser_rb.rb[ser_rb.rptr];
          ser_rb.rptr++;
          if (ser_rb.rptr == RB_SIZE) {
            ser_rb.rptr = 0;
          }
          ser_rb.left++;
        }
        client.write(linebuf, y);
      }

      if (debug) Serial.printf("line: %d\n", __LINE__);

    }
    client.stop();
  } else {
    yield();
    if ((millis() - blink) > 250) {
      blink = millis();
      digitalWrite(BUILTIN_LED, !digitalRead(BUILTIN_LED));
    }

    // handle configuration commands
    if (Serial.available()) {
      switch (Serial.read()) {
        case CFG_COMMAND_SET_PSK:
          Serial.print("Received CFG_COMMAND_SET_PSK: [");
          read_string(password);
          Serial.print(password);
          Serial.println("]");
          break;
        case CFG_COMMAND_SET_SSID:
          Serial.print("Received CFG_COMMAND_SET_SSID: [");
          read_string(ssid);
          Serial.print(ssid);
          Serial.println("]");
          break;
        case CFG_COMMAND_SET_BAUD:
          Serial.print("Received CFG_COMMAND_SET_BAUD: ");
          Serial.readBytes((char *)&baud, 4);
          Serial.println(baud);
          break;
        case CFG_COMMAND_SET_STORE:
          Serial.println("Received CFG_COMMAND_SET_STORE command.");
          Serial.write(0xAA); // sync byte
          save_eeprom();
          ESP.restart();
          break;
      }
    }
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
    }
  }
*/    
}
