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
    // Fungsi untuk mengaktifkan Bluetooth dan memberikan nama ke perangkat
    void initBLE(const String& deviceName); 

    // Fungsi untuk mengirim data konfigurasi ke aplikasi Universal Configurator lewat Bluetooth
    void sendConfig(); 

    // Fungsi untuk menyimpan data konfigurasi ke Preferences (semacam memori internal ESP32)
    void saveToPreferences(const String& key, const String& jsonData); 

    // Fungsi untuk membaca data konfigurasi yang sudah disimpan di Preferences
    String readFromPreferences(const String& key); 

    // Fungsi untuk menerapkan pengaturan dari data konfigurasi berbentuk JSON
    void applySettings(const String& jsonData); 

    // Fungsi untuk membuat UUID secara acak atau mengambil yang sudah ada dari Preferences
    String getOrCreateUUID(const String& key); 

    // Fungsi untuk membuat konfigurasi dalam format JSON, bisa dipakai untuk menyimpan atau dikirim
    void initConfig(const String& param, const String& value, const String& description, const String& type); 

    // Fungsi untuk menghapus semua data konfigurasi yang ada di Preferences
    void clearPreferences(); 

    // Fungsi untuk mengambil semua konfigurasi yang ada dalam bentuk JSON
    String getConfigJSON();  
    
public:
    // Mengecek apakah perangkat sudah terkoneksi ke aplikasi via Bluetooth
    bool isDeviceConnected() {
        return deviceConnected;
    }

private: // Bagian untuk inisialisasi Bluetooth dan data internal
    BLEServer* pServer;                 // Server BLE untuk menangani koneksi
    BLECharacteristic* pCharacteristic; // Karakteristik BLE, yaitu data yang bisa diakses lewat Bluetooth
    Preferences preferences;            // Objek untuk menyimpan data di memori internal
    bool deviceConnected = false;       // Status koneksi perangkat

    // Fungsi untuk membuat UUID secara random
    String generateUUID(); 

    // Fungsi untuk menyimpan UUID ke Preferences
    void saveUUID(const String& key, const String& uuid); 

    // Fungsi untuk membaca atau inisialisasi data JSON dari Preferences
    String readOrInitPreferences(); 
};

// Callback class untuk menangani event BLE seperti koneksi dan diskoneksi
class UCFG_BLEServerCallbacks : public BLEServerCallbacks {
public:
    // Konstruktor, menerima pointer ke status koneksi supaya bisa di-update
    UCFG_BLEServerCallbacks(bool* deviceConnected) : deviceConnected(deviceConnected) {}

    // Dipanggil saat perangkat terhubung ke Bluetooth
    void onConnect(BLEServer* pServer) override {
        *deviceConnected = true;  // Update status jadi terkoneksi
        Serial.println("BLE client connected."); // Notifikasi di Serial Monitor
    }

    // Dipanggil saat perangkat terputus dari Bluetooth
    void onDisconnect(BLEServer* pServer) override {
        *deviceConnected = false;  // Update status jadi tidak terkoneksi
        Serial.println("BLE client disconnected. Restarting advertising...");
        pServer->getAdvertising()->start(); // Mulai ulang advertising Bluetooth
    }

private:
    bool* deviceConnected; // Pointer untuk mengakses status koneksi
};

#endif
