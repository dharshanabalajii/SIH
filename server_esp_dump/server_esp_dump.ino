#include <LoRa.h>

#define LORA_SS   15
#define LORA_RST  4
#define LORA_DIO0 2

unsigned long lastActivePrint = 0;

void setup() {
  Serial.begin(115200);
  while (!Serial);

  LoRa.setPins(LORA_SS, LORA_RST, LORA_DIO0);

  if (!LoRa.begin(433E6)) {
    Serial.println("LoRa init failed!");
    while (1);
  }

  Serial.println("LoRa Active");
}

void loop() {
  int packetSize = LoRa.parsePacket();
  if (packetSize) {
    String received = "";
    while (LoRa.available()) {
      received += (char)LoRa.read();
    }
    Serial.println(received);
    lastActivePrint = millis();
  } else {
    // Print a dot every second to show LoRa is listening
    if (millis() - lastActivePrint > 1000) {
      Serial.print(".");
      lastActivePrint = millis();
    }
  }
}