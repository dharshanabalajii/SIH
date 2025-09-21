#include <TinyGPSPlus.h>
#include <HardwareSerial.h>
#include <LoRa.h>
#include <MAX30100_PulseOximeter.h>
#include <OneWire.h>
#include <DallasTemperature.h>

// GPS pins and baud rate
#define RXD2 17  // GPS TX pin to ESP32 RX2 (GPIO17)
#define TXD2 16  // GPS RX pin to ESP32 TX2 (GPIO16)
#define GPS_BAUD 9600

// LoRa pins (adjust if your wiring is different)
#define LORA_SS   15  // LoRa NSS (CS)
#define LORA_RST  14  // LoRa RESET
#define LORA_DIO0 26  // LoRa DIO0

// Touch sensor pin
#define TOUCH_PIN 2  // GPIO2, adjust if needed

// Temperature sensor pin
#define DS18B20_PIN 5  // GPIO5 for DS18B20 data line

TinyGPSPlus gps;
HardwareSerial gpsSerial(2);

PulseOximeter pox;
bool max30100_ok = false;

OneWire oneWire(DS18B20_PIN);
DallasTemperature sensors(&oneWire);

// Timing variables for mainTask
unsigned long lastTempRequest = 0;
const unsigned long tempRequestInterval = 1000; // 1 second
unsigned long lastSendTime = 0;
const unsigned long sendInterval = 1000; // 1 second

// Forward declarations of tasks
void hrTask(void *pvParameters);
void mainTask(void *pvParameters);

void setup() {
  Serial.begin(115200);
  Serial.println("GPS + LoRa + Touch + MAX30100 + Temp Test with FreeRTOS");

  // Initialize GPS serial
  gpsSerial.begin(GPS_BAUD, SERIAL_8N1, RXD2, TXD2);

  // Initialize LoRa
  LoRa.setPins(LORA_SS, LORA_RST, LORA_DIO0);
  Serial.print("Initializing LoRa... ");
  if (!LoRa.begin(433E6)) {  // Change frequency if needed (868E6 or 915E6)
    Serial.println("Failed!");
    while (1) {
      delay(1000);
    }
  }
  Serial.println("Success!");
  LoRa.setTxPower(17);  // Adjust power if needed

  // Initialize touch sensor pin
  pinMode(TOUCH_PIN, INPUT);

  // Initialize temperature sensor
  sensors.begin();
  Serial.println("Temperature sensor started");

  // Initialize MAX30100 sensor
  max30100_ok = pox.begin();
  if (max30100_ok) {
    Serial.println("MAX30100 initialized successfully");
  } else {
    Serial.println("Failed to initialize MAX30100");
  }

  // Create FreeRTOS tasks pinned to specific cores
  xTaskCreatePinnedToCore(
    hrTask,        // Task function
    "HR Task",     // Name
    10000,         // Stack size (bytes)
    NULL,          // Parameters
    2,             // Priority (higher)
    NULL,          // Task handle
    0              // Core 0
  );

  xTaskCreatePinnedToCore(
    mainTask,
    "Main Task",
    20000,
    NULL,
    1,             // Lower priority
    NULL,
    1              // Core 1
  );
}

void loop() {
  // Empty - FreeRTOS tasks handle everything
}

// Task to continuously update MAX30100 sensor
void hrTask(void *pvParameters) {
  (void) pvParameters;
  while (1) {
    if (max30100_ok) {
      pox.update();
    }
    // Small delay to yield CPU, adjust if needed
    vTaskDelay(1 / portTICK_PERIOD_MS);
  }
}

// Main task to handle GPS, temperature, touch sensor, and LoRa
void mainTask(void *pvParameters) {
  (void) pvParameters;

  float temp_c = 0.0;

  while (1) {
    // Read GPS data non-blocking
    while (gpsSerial.available() > 0) {
      gps.encode(gpsSerial.read());
    }

    // Read touch sensor state
    int touchState = digitalRead(TOUCH_PIN);

    // Request temperature every tempRequestInterval ms (non-blocking)
    if (millis() - lastTempRequest >= tempRequestInterval) {
      sensors.requestTemperatures();
      lastTempRequest = millis();
    }

    // Read temperature
    float tempReading = sensors.getTempCByIndex(0);
    if (tempReading == DEVICE_DISCONNECTED_C) {
      Serial.println("Error: Could not read temperature data");
      temp_c = 0.0;
    } else {
      temp_c = tempReading;
    }

    // Send data every sendInterval ms if GPS location updated
    if (gps.location.isUpdated() && (millis() - lastSendTime >= sendInterval)) {
      float hr = 0.0, spo2 = 0.0;
      if (max30100_ok) {
        hr = pox.getHeartRate();
        spo2 = pox.getSpO2();
      }

      String message = "";

      // Format GPS data into a string
      message += "Lat:" + String(gps.location.lat(), 6);
      message += ",Lng:" + String(gps.location.lng(), 6);
      message += ",Alt:" + String(gps.altitude.meters(), 1);
      message += ",Sat:" + String(gps.satellites.value());
      message += ",Date:" + String(gps.date.day()) + "/" + String(gps.date.month()) + "/" + String(gps.date.year());
      message += ",Time:" + String(gps.time.hour()) + ":" + String(gps.time.minute()) + ":" + String(gps.time.second());

      // Append touch sensor state
      message += ",Touch:" + String(touchState);

      // Append MAX30100 data
      message += ",HR:" + String(hr, 1);
      message += ",SpO2:" + String(spo2, 1);

      // Append temperature data
      message += ",Temp:" + String(temp_c, 1);

      Serial.println("Sending GPS + Touch + MAX30100 + Temp data via LoRa:");
      Serial.println(message);

      // Send message via LoRa
      LoRa.beginPacket();
      LoRa.print(message);
      LoRa.endPacket();

      lastSendTime = millis();
    }

    // Small delay to yield CPU and prevent watchdog reset
    vTaskDelay(10 / portTICK_PERIOD_MS);
  }
}
