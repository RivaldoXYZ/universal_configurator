#ifndef UCFG_H
#define UCFG_H

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <Preferences.h>
#include <Arduino_JSON.h>


class UniversalConfigurator {
public:
    void initBLE(const String& deviceName); // Fungsi untuk menginisialisasi Bluetooth
    void sendConfig(); // Fungsi untuk mengirimkan konfigurasi

    void saveToPreferences(const String& key, const String& jsonData); // Fungsi untuk menyimpan ke Preferences
    String readFromPreferences(const String& key); // Membaca data dari Preferences

    void applySettings(const String& jsonData); // Menerapkan pengaturan yang di ambil dari Preferences
    String getOrCreateUUID(const String& key); // Fungsi untuk Membuat UUID

    void initConfig(const String& param, const String& value, const String& description, const String& type); // fungsi untuk membuat konfigurasi dan di simpan dalam bentuk format JSON
    void clearPreferences(); // fungsi untuk membersihkan Preferences
    String getConfigJSON();  // Menerima data Config dalam bentuk Js
    
public:
    bool isDeviceConnected() {
        return deviceConnected;
    }


private:
    BLEServer* pServer;
    BLECharacteristic* pCharacteristic;
    Preferences preferences;
    bool deviceConnected = false;

    String generateUUID();
    void saveUUID(const String& key, const String& uuid);

    String readOrInitPreferences(); // Helper for initializing or reading JSON from Preferences
};

// Callback class untuk menangani event BLE
class UCFG_BLEServerCallbacks : public BLEServerCallbacks {
public:
    UCFG_BLEServerCallbacks(bool* deviceConnected) : deviceConnected(deviceConnected) {}

    void onConnect(BLEServer* pServer) override {
        *deviceConnected = true;
        Serial.println("BLE client connected.");
    }

    void onDisconnect(BLEServer* pServer) override {
        *deviceConnected = false;
        Serial.println("BLE client disconnected. Restarting advertising...");
        pServer->getAdvertising()->start();
    }



private:
    bool* deviceConnected;
};

#endif
