#include "UCFG.h"
#include <esp_system.h> 

String UniversalConfigurator::generateUUID() {
    // Menggunakan fungsi random dari ESP untuk membuat bagian-bagian UUID
    uint32_t part1 = esp_random();
    uint32_t part2 = esp_random();
    uint32_t part3 = esp_random();
    uint32_t part4 = esp_random();

    // Format UUID menjadi string sesuai standar
    char uuid[37]; 
    snprintf(uuid, sizeof(uuid), "%08X-%04X-%04X-%04X-%08X%04X",
             part1,
             (part2 & 0xFFFF),
             ((part2 >> 16) & 0x0FFF) | 0x4000, // Set version 4 UUID
             ((part3 & 0x3FFF) | 0x8000),       // Set variant UUID
             part3 >> 16,
             (part4 & 0xFFFF));
    return String(uuid); // Kembalikan UUID dalam bentuk string
}

String UniversalConfigurator::getOrCreateUUID(const String& key) {
    preferences.begin("BLEUUIDs", true); // Mulai Preferences dengan namespace "BLEUUIDs"
    String uuid = preferences.getString(key.c_str(), ""); // Ambil UUID berdasarkan key

    if (uuid.isEmpty()) { // Kalau belum ada, buat UUID baru
        uuid = generateUUID();
        saveUUID(key, uuid); // Simpan UUID baru ke Preferences
    }
    preferences.end();
    Serial.println("UUID loaded: " + uuid); // Cetak UUID yang diambil
    return uuid; // Kembalikan UUID
}

void UniversalConfigurator::saveUUID(const String& key, const String& uuid) {
    preferences.begin("BLEUUIDs", false); // Mulai Preferences untuk write
    preferences.putString(key.c_str(), uuid); // Simpan UUID dengan key tertentu
    preferences.end();
}

void UniversalConfigurator::initBLE(const String& deviceName) {
    BLEDevice::init(deviceName.c_str()); // Inisialisasi perangkat BLE
    pServer = BLEDevice::createServer(); // Membuat server BLE

    // Menyambungkan callback untuk event connect/disconnect
    pServer->setCallbacks(new UCFG_BLEServerCallbacks(&deviceConnected));

    // Buat atau ambil UUID untuk Service dan Characteristic
    String serviceUUID = getOrCreateUUID("serviceUUID");
    String characteristicUUID = getOrCreateUUID("characteristicUUID");

    // Membuat Service BLE dengan UUID
    BLEService* pService = pServer->createService(serviceUUID.c_str());

    // Membuat Characteristic BLE dengan properti Read, Write, dan Notify
    pCharacteristic = pService->createCharacteristic(
        characteristicUUID.c_str(),
        BLECharacteristic::PROPERTY_READ |
        BLECharacteristic::PROPERTY_WRITE |
        BLECharacteristic::PROPERTY_NOTIFY
    );
    pCharacteristic->addDescriptor(new BLE2902()); // Tambahkan descriptor untuk Notify

    // Atur nilai awal Characteristic dengan konfigurasi JSON
    String initialConfig = getConfig();
    pCharacteristic->setValue(initialConfig.c_str());

    pService->start(); // Mulai Service
    pServer->getAdvertising()->start(); // Mulai advertising BLE

    // Cetak informasi ke Serial
    Serial.println("BLE initialized with device name: " + deviceName);
    Serial.println("Service UUID: " + serviceUUID);
    Serial.println("Characteristic UUID: " + characteristicUUID);
}

void UniversalConfigurator::sendConfig() {
    if (deviceConnected) { // Hanya kirim jika ada perangkat yang terkoneksi
        String configData = getConfig();
        pCharacteristic->setValue(configData.c_str()); // Set nilai Characteristic
        pCharacteristic->notify(); // Kirim notifikasi ke client BLE
        Serial.println("Data sent to BLE client:");
        Serial.println(configData); // Cetak data yang dikirim
    } else {
        Serial.println("No BLE client connected. Data not sent."); // Kalau belum terkoneksi, beri notifikasi
    }
}

void UniversalConfigurator::saveToPreferences(const String& key, const String& jsonData) {
    preferences.begin("Configuration", false); // Mulai Preferences dengan namespace "Configuration"
    preferences.putString(key.c_str(), jsonData); // Simpan data JSON dengan key tertentu
    preferences.end();
    Serial.println("Data saved to preferences"); // Cetak bahwa data telah disimpan
}

String UniversalConfigurator::readFromPreferences(const String& key) {
    preferences.begin("Configuration", true); // Mulai Preferences untuk read
    String jsonData = preferences.getString(key.c_str(), ""); // Ambil data berdasarkan key
    preferences.end();
    return jsonData;
}

String UniversalConfigurator::readOrInitPreferences() {
    String jsonData = readFromPreferences("config");
    if (jsonData.isEmpty()) { // Jika belum ada data, buat data kosong
        jsonData = "{}";
        saveToPreferences("config", jsonData); // Simpan data kosong sebagai default
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

        saveToPreferences("config", JSON.stringify(jsonConfig)); // Simpan konfigurasi yang diperbarui
        Serial.println("Configuration updated:");
        Serial.println(JSON.stringify(jsonConfig)); // Cetak konfigurasi terbaru
    } else {
        Serial.println("Error: Failed to parse JSON!"); // Jika JSON gagal diproses
    }
}

void UniversalConfigurator::clearPreferences() {
    preferences.begin("Configuration", false); // Mulai Preferences dengan namespace "Configuration"
    preferences.clear(); // Bersihkan semua data di namespace ini
    preferences.end();
    Serial.println("Preferences cleared."); // Cetak bahwa Preferences telah dihapus
}

void UniversalConfigurator::applySettings(const String& jsonData) {
    Serial.println("Applying settings: " + jsonData); // Cetak data yang diterapkan
}

String UniversalConfigurator::getConfig() {
    if (pCharacteristic->getValue().length() > 0) {
        String receivedData = pCharacteristic->getValue().c_str(); 
        Serial.println("Received BLE data: " + receivedData);
        JSONVar jsonData = JSON.parse(receivedData);
        if (JSON.typeof(jsonData) == "undefined") {
            Serial.println("Error: Invalid JSON format received!");
            return readFromPreferences("config"); 
        }
        saveToPreferences("config", receivedData);
        Serial.println("Configuration saved: " + receivedData);
    }
    return readFromPreferences("config");
}

