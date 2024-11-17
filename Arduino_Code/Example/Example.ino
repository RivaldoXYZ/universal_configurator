#include "UCFG.h" // Include Library Universal Configurator

UniversalConfigurator ucfg; // deklarasi pemanggilan class Universal Configurtor menjadi variabel ucfg

void setup() {
    Serial.begin(115200);
    ucfg.initBLE("MyBLEDevice"); // Panggil Fungsi untuk Menginisialisasi Bluetooth dengan memberikan Nama Device sebagai Parameter
    ucfg.initConfig("defauld_param", "default_value", "description", "string");

    String config = ucfg.getConfigJSON(); // Memanggil fungsi getConfigJSON yang akan mengambil config JSon yang di simpan di preference
    Serial.println("Current Configuration:");
    Serial.println(config); //Menampilkan configurasi yang sudah tersimpan di preference
    
}

void loop() {
    if (ucfg.isDeviceConnected()) {
        // Tambahkan logika Anda di sini
        Serial.println("Device is connected!");
        ucfg.sendConfig();
    } else {
        Serial.println("Device is not connected.");
    }
    delay (1000);
}

