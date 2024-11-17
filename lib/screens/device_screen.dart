import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter/services.dart';



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


class DeviceScreen extends StatefulWidget {
  final BluetoothDevice device;

  const DeviceScreen({super.key, required this.device});

  @override
  DeviceScreenState createState() => DeviceScreenState();
}

class DeviceScreenState extends State<DeviceScreen> {
  List<ConfigParameter> configParameters = [];
  BluetoothCharacteristic? targetCharacteristic;
  bool isAuthenticated = false; // Flag to check PIN authentication

  @override
  void initState() {
    super.initState();
    connectToDevice();
  }

  Future<void> connectToDevice() async {
    try {
      print("Connecting to device...");
      await widget.device.connect();
      print("Connected to device.");
      // Prompt for PIN authentication
      promptForPin();
    } catch (e) {
      print("Error connecting to device: $e");
      showSnackbar("Failed to connect to device: $e", Colors.red);
    }
  }

  Future<void> promptForPin() async {
    TextEditingController pinController = TextEditingController();
    await showDialog(
      context: context,
      barrierDismissible: false, // Prevent closing the dialog without action
      builder: (context) {
        return AlertDialog(
          title: const Text("Enter PIN"),
          content: TextField(
            controller: pinController,
            obscureText: true, // Hide PIN input
            keyboardType: TextInputType.number,
            maxLength: 4, // Limit to 4 characters
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly, // Only allow numeric input
            ],
            decoration: const InputDecoration(
              labelText: "PIN",
              hintText: "Enter a 4-digit PIN", // Hint for the user
              counterText: "", // Remove character counter
              border: OutlineInputBorder(), // Add a border for better UI
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                widget.device.disconnect(); // Disconnect if user cancels
                Navigator.of(context).pop(); // Go back to previous screen
              },
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                String enteredPin = pinController.text;

                // Ensure PIN has exactly 4 digits
                if (enteredPin.length != 4) {
                  showSnackbar("PIN must be 4 digits.", Colors.red);
                  return;
                }

                // Validate PIN value
                if (enteredPin == "1234") { // Replace "1234" with your desired PIN
                  setState(() {
                    isAuthenticated = true;
                  });
                  Navigator.of(context).pop(); // Close the dialog
                  discoverServicesAndReadData(); // Proceed to discover services
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
    if (!isAuthenticated) return; // Prevent reading data if not authenticated
    try {
      print("Discovering services...");
      List<BluetoothService> services = await widget.device.discoverServices();

      for (var service in services) {
        print("Service UUID: ${service.uuid}");

        for (var characteristic in service.characteristics) {
          print("  Checking characteristic UUID: ${characteristic.uuid}");

          // Ensure the characteristic has read property
          if (characteristic.properties.read) {
            List<int> value = await characteristic.read();
            String data = String.fromCharCodes(value);

            // Verify if data is JSON
            if (data.trim().startsWith("{") && data.trim().endsWith("}")) {
              print("  JSON characteristic found: ${characteristic.uuid}");
              targetCharacteristic = characteristic; // Save characteristic
              setState(() {
                configParameters = parseConfig(data);
              });
              return; // Exit after finding JSON characteristic
            }
          }
        }
      }

      showSnackbar("No JSON characteristic found.", Colors.orange);
    } catch (e) {
      print("Error discovering services: $e");
      showSnackbar("Error discovering services: $e", Colors.red);
    }
  }

  List<ConfigParameter> parseConfig(String jsonString) {
    try {
      Map<String, dynamic> jsonData = jsonDecode(jsonString);
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
      return [];
    }
  }

  void showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Device Configuration"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => discoverServicesAndReadData(),
          ),
        ],
      ),
      body: isAuthenticated
          ? (configParameters.isNotEmpty
          ? buildConfigForm()
          : const Center(child: CircularProgressIndicator()))
          : const Center(
        child: Text(
          "Authenticate to access data",
          style: TextStyle(fontSize: 18),
        ),
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
                        param.value = newValue;
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

  @override
  void dispose() {
    widget.device.disconnect();
    super.dispose();
  }
}
