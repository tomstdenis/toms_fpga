// this works fine on my ESP32-C3 "NoName" Super Mini 
#include <WiFi.h>

int port = 8888;  //Port number
WiFiServer server(port);

//Server connect to WiFi Network
const char *ssid = "";  //Enter your wifi SSID
const char *password = "";  //Enter your wifi Password

//=======================================================================
//                    Power on setup
//=======================================================================
void setup() 
{
  Serial.begin(921600);
  Serial.setRxBufferSize(128);
  Serial.setTxBufferSize(128);
  Serial.println();

  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid, password); //Connect to wifi
 
  // Wait for connection  
  while (WiFi.status() != WL_CONNECTED) {   
    delay(500);
    delay(500);
  }

  server.begin();
  pinMode(BUILTIN_LED, OUTPUT);
  digitalWrite(BUILTIN_LED, HIGH);
}
//=======================================================================
//                    Loop
//=======================================================================

void loop() 
{
  unsigned char buf[64], x;

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
        Serial.read(buf, x);
        client.write(buf, x);
      }
    }
    client.stop();
  } else {
    digitalWrite(BUILTIN_LED, HIGH);
  }
}
//=======================================================================