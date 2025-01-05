#include "UCFG.h" // Include Library Universal Configurator 

// Deklarasi objek UniversalConfigurator sebagai ucfg
UniversalConfigurator ucfg; // digunakan untuk mengakses semua fungsi dari Universal Configurator

// Deklarasi variabel global untuk setiap parameter
int PIN;
int port;
String ipmqtt;
String usernamemqtt;
String passwordmqtt;
int Threshold;

void Parse(){
    ucfg.parseConfig();

    // ucfg.getConfigValue("name of parameter")
    port = ucfg.getConfigValue("port").toInt();
    ipmqtt = ucfg.getConfigValue("ipmqtt");
    usernamemqtt = ucfg.getConfigValue("usernamemqtt");
    passwordmqtt = ucfg.getConfigValue("passwordmqtt");
    Threshold = ucfg.getConfigValue("Threshold").toInt();

    Serial.print("port: "); Serial.println(port);
    Serial.print("ipmqtt: "); Serial.println(ipmqtt);
    Serial.print("usernamemqtt: "); Serial.println(usernamemqtt);
    Serial.print("passwordmqtt: "); Serial.println(passwordmqtt);
    Serial.print("Threshold: "); Serial.println(Threshold);
    Serial.println("\n");
};

void setup() {
    Serial.begin(115200);
    ucfg.initBLE("Seminar TA 1");

    // Menghapus preferensi hanya jika perlu
    ucfg.clearPreferences(); 

    // Inisialisasi konfigurasi, 
    // Jika tipe int value di konversi ke string String(value dalam int)
    // ucfg.initConfig("parameter", "value", "Deskripsi Parameter ", "string");
    // ucfg.initConfig("parameter2", "String(Value2)", "Deskripsi Parameter 2", "int"); // Untuk tipe data integer

    ucfg.initConfig("PIN", String(1234), "PIN untuk autentikasi", "int");
    ucfg.initConfig("port", String(1845), "Port Node Red", "int");
    ucfg.initConfig("ipmqtt", "192.168.1.1", "IP address MQTT Server", "string");
    ucfg.initConfig("usernamemqtt", "admin", "Username MQTT", "string");
    ucfg.initConfig("passwordmqtt", "admin", "Password MQTT", "string");
    ucfg.initConfig("Threshold", String(87), "Threshold sistem pengairan", "int");

    String configData = ucfg.readFromPreferences("config");
    Serial.println("Configuration loaded: " + configData);
}

void loop() {
    if (ucfg.isDeviceConnected()) {
        Serial.println("Device is connected!");
        ucfg.sendConfig();
        Parse();
    } else {
        Serial.println("Device is not connected.");
    }
    delay(3000);
}



/*
-------------------- CONTOH IMPLEMENTASI  --------------------

1. Inisialisasi Bluetooth dengan nama perangkat
ucfg.initBLE("NamaPerangkatBLE");

2. Membuat konfigurasi awal initConfig(parameter, nilai, deskripsi, tipe data)
ucfg.initConfig("parameter1", "nilai1", "Deskripsi Parameter 1", "string");
ucfg.initConfig("parameter2", "123", "Deskripsi Parameter 2", "integer");
ucfg.initConfig("parameter3", "true", "Deskripsi Parameter 3", "boolean");

3. Mengambil semua konfigurasi yang ada dalam bentuk JSON
String konfigurasiJSON = ucfg.getConfig();

4. Menyimpan data JSON ke Preferences
String dataBaru = "{\"parameter\":\"nilaiBaru\"}";
ucfg.saveToPreferences("configBaru", dataBaru);

5. Membaca data JSON dari Preferences
String dataDariPreferences = ucfg.readFromPreferences("configBaru");
Serial.println("Data dari Preferences:");
Serial.println(dataDariPreferences);

6. Membersihkan Preferences
ucfg.clearPreferences();

7. Mengambil atau membuat UUID baru
String serviceUUID = ucfg.getOrCreateUUID("serviceUUID");
String characteristicUUID = ucfg.getOrCreateUUID("characteristicUUID");


8. Mengirimkan data konfigurasi lewat Bluetooth
if (ucfg.isDeviceConnected()) {
    ucfg.sendConfig();
} else {
    //logic jika tidak ada yang terhubung
}

9. Menerapkan pengaturan dari data JSON
String konfigurasiBaru = "{\"parameter1\":\"nilaiBaru1\",\"parameter4\":\"nilaiBaru4\"}";
ucfg.applySettings(konfigurasiBaru);

10. Mengecek apakah perangkat BLE sudah terkoneksi
if (ucfg.isDeviceConnected()) {
    Serial.println("Perangkat terkoneksi.");
} else {
    Serial.println("Perangkat tidak terkoneksi.");
}

------------------------------------------------------------------------------------------
*/