#include <Arduino.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

BLEServer *pServer = nullptr;
BLECharacteristic *pCharacteristic = nullptr;
bool deviceConnected = false;
bool oldDeviceConnected = false;

// JSON data to send - adjust this to fit the required structure
const char *jsonData = R"(
[
  {
    "param": "ssid_name",
    "desc": "WiFi SSID Name",
    "type": "String",
    "value": "default_ssid"
  },
  {
    "param": "ssid_pass",
    "desc": "SSID Password",
    "type": "String",
    "value": "12345678"
  },
  {
    "param": "ssid_test",
    "desc": "SSID test",
    "type": "String",
    "value": "00123124"
  }
]
)";

// UUIDs for the BLE service and characteristic
#define SERVICE_UUID           "12345678-1234-1234-1234-1234567890ab"
#define CHARACTERISTIC_UUID    "abcdefab-1234-5678-1234-abcdefabcdef"

class MyServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) {
    deviceConnected = true;
    Serial.println("Device connected");
  }

  void onDisconnect(BLEServer* pServer) {
    deviceConnected = false;
    Serial.println("Device disconnected");
  }
};

void setup() {
  Serial.begin(115200);

  // Initialize BLE
  BLEDevice::init("ESP32_JSON_Server");
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  // Create a BLE Service
  BLEService *pService = pServer->createService(SERVICE_UUID);

  // Create a BLE Characteristic for JSON data
  pCharacteristic = pService->createCharacteristic(
                      CHARACTERISTIC_UUID,
                      BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY
                    );

  // Add descriptor for notification
  pCharacteristic->addDescriptor(new BLE2902());

  // Set initial JSON data as the characteristic value
  pCharacteristic->setValue(jsonData);

  // Start the service
  pService->start();

  // Start advertising
  pServer->getAdvertising()->start();
  Serial.println("Waiting for a client connection to send JSON data...");
}

void loop() {
  // Check if device is connected and notify data
  if (deviceConnected) {
    pCharacteristic->setValue(jsonData); // Set JSON data
    pCharacteristic->notify(); // Notify connected client
    Serial.println("JSON data sent via notification");
    delay(2000); // Delay to simulate periodic updates
  }

  // Handle disconnection
  if (!deviceConnected && oldDeviceConnected) {
    delay(500); // Give some time before restarting advertising
    pServer->getAdvertising()->start();
    Serial.println("Restarting advertising...");
    oldDeviceConnected = deviceConnected;
  }

  // Update oldDeviceConnected state
  if (deviceConnected && !oldDeviceConnected) {
    oldDeviceConnected = deviceConnected;
  }
}
