#include "UCFG.h"

String UniversalConfigurator::generateUUID() {
    uint32_t part1 = esp_random();
    uint32_t part2 = esp_random();
    uint32_t part3 = esp_random();
    uint32_t part4 = esp_random();

    char uuid[37]; 
    snprintf(uuid, sizeof(uuid), "%08X-%04X-%04X-%04X-%08X%04X",
             part1,
             (part2 & 0xFFFF),
             ((part2 >> 16) & 0x0FFF) | 0x4000,
             ((part3 & 0x3FFF) | 0x8000),
             part3 >> 16,
             (part4 & 0xFFFF));
    return String(uuid);
}

String UniversalConfigurator::getOrCreateUUID(const String& key) {
    preferences.begin("BLEUUIDs", true);
    String uuid = preferences.getString(key.c_str(), "");
    if (uuid.isEmpty()) {
        uuid = generateUUID();
        saveUUID(key, uuid);
    }
    preferences.end();
    Serial.println("UUID loaded: " + uuid);
    return uuid;
}

void UniversalConfigurator::saveUUID(const String& key, const String& uuid) {
    preferences.begin("BLEUUIDs", false);
    preferences.putString(key.c_str(), uuid);
    preferences.end();
}

void UniversalConfigurator::initBLE(const String& deviceName) {
    BLEDevice::init(deviceName.c_str());
    pServer = BLEDevice::createServer();

    pServer->setCallbacks(new UCFG_BLEServerCallbacks(&deviceConnected));

    String serviceUUID = getOrCreateUUID("serviceUUID");
    String characteristicUUID = getOrCreateUUID("characteristicUUID");

    BLEService* pService = pServer->createService(serviceUUID.c_str());

    pCharacteristic = pService->createCharacteristic(
        characteristicUUID.c_str(),
        BLECharacteristic::PROPERTY_READ |
        BLECharacteristic::PROPERTY_WRITE |
        BLECharacteristic::PROPERTY_NOTIFY
    );
    pCharacteristic->addDescriptor(new BLE2902());

    String initialConfig = getConfig();
    pCharacteristic->setValue(initialConfig.c_str());

    pService->start();
    pServer->getAdvertising()->start();

    Serial.println("BLE initialized with device name: " + deviceName);
    Serial.println("Service UUID: " + serviceUUID);
    Serial.println("Characteristic UUID: " + characteristicUUID);
}

void UniversalConfigurator::sendConfig() {
    if (deviceConnected) {
        String configData = getConfig();
        pCharacteristic->setValue(configData.c_str());
        pCharacteristic->notify();
        Serial.println("Data sent to BLE client:");
        Serial.println(configData);
    } else {
        Serial.println("No BLE client connected. Data not sent.");
    }
}

void UniversalConfigurator::saveToPreferences(const String& key, const String& jsonData) {
    preferences.begin("Configuration", false);
    preferences.putString(key.c_str(), jsonData);
    preferences.end();
    // Serial.println("Data saved to preferences");
}

String UniversalConfigurator::readFromPreferences(const String& key) {
    preferences.begin("Configuration", true);
    String jsonData = preferences.getString(key.c_str(), "");
    preferences.end();
    return jsonData;
}

String UniversalConfigurator::readOrInitPreferences() {
    String jsonData = readFromPreferences("config");
    if (jsonData.isEmpty()) {
        jsonData = "{}";
        saveToPreferences("config", jsonData);
    }
    return jsonData;
}
void UniversalConfigurator::initConfig(const String& param, const String& value, const String& description, const String& type) {
    String jsonData = readOrInitPreferences();
    JSONVar jsonConfig = JSON.parse(jsonData);

    if (JSON.typeof(jsonConfig) != "undefined") {
        if (jsonConfig.hasOwnProperty(param)) { // Kalau parameter sudah ada, update
            jsonConfig[param]["value"] = value;
            jsonConfig[param]["description"] = description;
            jsonConfig[param]["type"] = type;
        } else { // Kalau belum ada, tambahkan parameter baru
            JSONVar newParam;
            newParam["value"] = value;
            newParam["description"] = description;
            newParam["type"] = type;
            jsonConfig[param] = newParam;
        }
        saveToPreferences("config", JSON.stringify(jsonConfig));
        Serial.println("Configuration updated:");
        Serial.println(JSON.stringify(jsonConfig));
    } else {
        Serial.println("Error: Failed to parse JSON!");
    }
}

void UniversalConfigurator::clearPreferences() {
    preferences.begin("Configuration", false);
    preferences.clear();
    preferences.end();
    Serial.println("Preferences cleared.");
}


String UniversalConfigurator::getConfig() {
    if (pCharacteristic->getValue().length() > 0) {
        String receivedData = pCharacteristic->getValue().c_str(); 
        // Serial.println("Received BLE data: " + receivedData);
        DynamicJsonDocument doc(1024);
        DeserializationError error = deserializeJson(doc, receivedData);
        if (error) {
            Serial.print("deserializeJson() failed: ");
            Serial.println(error.c_str());
            return readFromPreferences("config"); 
        }
        saveToPreferences("config", receivedData);
        // Serial.println("Configuration saved: " + receivedData);
    }
    return readFromPreferences("config");
}

  void UniversalConfigurator::parseConfig() {
      String config = readFromPreferences("config");
      if (config.isEmpty()) {
          Serial.println("Preferences kosong, tidak ada konfigurasi untuk diparse.");
          return;
      }

      DynamicJsonDocument doc(config.length() * 2);

      DeserializationError error = deserializeJson(doc, config);
      if (error) {
          Serial.print("deserializeJson() failed: ");
          Serial.println(error.c_str());
          return;
      }

      for (JsonPair kv : doc.as<JsonObject>()) {
          String key = kv.key().c_str();
          String value = kv.value()["value"].as<String>();
          configMap[key] = value;
      }
  }

String UniversalConfigurator::getConfigValue(const String& param) {
    if (configMap.find(param) != configMap.end()) {
        return configMap[param];
    } else {
        Serial.print("Parameter " + param + " tidak ditemukan.");
        return "";
    }
}