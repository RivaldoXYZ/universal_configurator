import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

class DeviceScreen extends StatefulWidget {
  final BluetoothDevice device;

  const DeviceScreen({Key? key, required this.device}) : super(key: key);

  @override
  DeviceScreenState createState() => DeviceScreenState();
}

class DeviceScreenState extends State<DeviceScreen> {
  List<ConfigParameter> configParameters = [];
  BluetoothCharacteristic? targetCharacteristic;
  bool isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    connectToDevice();
  }

  void dispose() {
    resetState(); // Reset state sebelum disconnect
    widget.device.disconnect();
    super.dispose();
  }

  void resetState() {
    setState(() {
      configParameters = [];
      targetCharacteristic = null;
      isAuthenticated = false;
    });
  }

  Future<void> connectToDevice() async {
    try {
      await widget.device.connect();
      promptForPin();
    } catch (e) {
      showSnackbar("Failed to connect to device: $e", Colors.red);
      resetState(); // Reset state jika gagal koneksi
    }
  }

  Future<void> promptForPin() async {
    TextEditingController pinController = TextEditingController();
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text("Enter PIN"),
          content: TextField(
            controller: pinController,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 4,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: "PIN",
              hintText: "Enter a 4-digit PIN",
              counterText: "",
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.device.disconnect();
                Navigator.of(context).pop();
              },
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                if (pinController.text == "1234") {
                  setState(() => isAuthenticated = true);
                  Navigator.of(context).pop();
                  discoverServicesAndReadData();
                } else {
                  showSnackbar("Invalid PIN. Try again.", Colors.red);
                }
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  Future<void> discoverServicesAndReadData() async {
    if (!isAuthenticated) return;
    try {
      List<BluetoothService> services = await widget.device.discoverServices();
      for (var service in services) {
        for (var characteristic in service.characteristics) {
          if (characteristic.properties.read) {
            List<int> value = await characteristic.read();
            String data = String.fromCharCodes(value);
            print("Received BLE Data: $data");

            // Memastikan data tidak kosong sebelum parsing
            if (data.isEmpty) {
              showSnackbar("Received data is empty.", Colors.red);
              continue; // Lewati iterasi ini
            }

            // Parsing JSON data
            try {
              var parsedData = jsonDecode(data); // Parse JSON string menjadi Map
              print("Parsed Config Data: $parsedData");

              // Mengubah JSON data menjadi list ConfigParameter
              List<ConfigParameter> configList = parseConfig(parsedData);
              setState(() {
                configParameters = configList;
                targetCharacteristic = characteristic; // Menyimpan karakteristik untuk menulis data
              });
            } catch (e) {
            }
          }
        }
      }
      if (configParameters.isEmpty) {
        showSnackbar("No valid JSON data received.", Colors.orange);
      }
    } catch (e) {
      showSnackbar("Error discovering services: $e", Colors.red);
    }
  }
  List<ConfigParameter> parseConfig(Map<String, dynamic> jsonData) {
    try {
      if (jsonData.isEmpty) {
        showSnackbar("Received data is empty.", Colors.red);
        return [];
      }

      return jsonData.entries.map((entry) {
        return ConfigParameter(
          key: entry.key,
          value: entry.value['value'] ?? '',
          type: entry.value['type'] ?? '',
          desc: entry.value['description'] ?? '',
        );
      }).toList();
    } catch (e) {
      print("Error parsing JSON: $e");
      showSnackbar("Error parsing JSON data.", Colors.red);
      return [];
    }
  }

  void showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Device Configuration"),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              widget.device.name,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: isAuthenticated
                ? (configParameters.isNotEmpty
                ? buildConfigForm()
                : const Center(child: CircularProgressIndicator()))
                : const Center(
              child: Text(
                "Authenticate to access data",
                style: TextStyle(fontSize: 18),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () {
                if (targetCharacteristic != null) {
                  updateData();
                } else {
                  showSnackbar("No characteristic to update data.", Colors.orange);
                }
              },
              child: const Text("Update Data"),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildConfigForm() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: ListView.builder(
        itemCount: configParameters.length,
        itemBuilder: (context, index) {
          final param = configParameters[index];
          TextEditingController controller = TextEditingController(text: param.value);

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      param.desc,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: controller,
                      decoration: InputDecoration(
                        labelText: 'Value',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey[200],
                      ),
                      onChanged: (newValue) {
                        param.value = newValue; // Mengubah nilai parameter
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Data Type: ${param.type}",
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> updateData() async {
    try {
      Map<String, dynamic> jsonData = {
        for (var param in configParameters)
          param.key: {
            'value': param.value,
            'type': param.type,
            'description': param.desc,
          },
      };
      String updatedData = jsonEncode(jsonData);
      print("Sending updated data: $updatedData");
      await targetCharacteristic?.write(utf8.encode(updatedData));
      showSnackbar("Data updated successfully.", Colors.green);
    } catch (e) {
      showSnackbar("Failed to update data: $e", Colors.red);
    }
  }
}

class ConfigParameter {
  String key;
  String value;
  String type;
  String desc;

  ConfigParameter({
    required this.key,
    required this.value,
    required this.type,
    required this.desc,
  });

  factory ConfigParameter.fromJson(Map<String, dynamic> json) {
    return ConfigParameter(
      key: json['key'] ?? '',
      value: json['value'] ?? '',
      type: json['type'] ?? '',
      desc: json['description'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'value': value,
      'type': type,
      'description': desc,
    };
  }
}