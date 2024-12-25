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
  bool isUpdating = false;

  @override
  void initState() {
    super.initState();
    connectToDevice();
    widget.device.state.listen((state) {
      if (state == BluetoothDeviceState.disconnected) {
        setState(() => isAuthenticated = false);
        showSnackbar("Device disconnected.", Colors.red);
      }
    });
  }

  Future<void> resetConfiguration() async {
    if (!isAuthenticated || targetCharacteristic == null) {
      showSnackbar("Device not connected or authenticated.", Colors.red);
      return;
    }
    try {
      await targetCharacteristic?.write(utf8.encode('RESET_CONFIG'));
      showSnackbar("Configuration reset command sent.", Colors.green);
    } catch (e) {
      showSnackbar("Failed to send reset command: $e", Colors.red);
    }
  }

  Future<void> connectToDevice() async {
    try {
      await widget.device.connect();
      promptForPin();
    } catch (e) {
      showSnackbar("Failed to connect to device: $e", Colors.red);
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
            if (data.trim().startsWith("[") && data.trim().endsWith("]")) {
              targetCharacteristic = characteristic;
              setState(() => configParameters = parseConfig(data));
              return;
            }
          }
        }
      }
      showSnackbar("No JSON characteristic found.", Colors.orange);
    } catch (e) {
      showSnackbar("Error discovering services: $e", Colors.red);
    }
  }

  List<ConfigParameter> parseConfig(String jsonString) {
    try {
      List<dynamic> jsonArray = jsonDecode(jsonString);
      return jsonArray.map((entry) {
        return ConfigParameter(
          key: entry['key'] ?? '',
          value: entry['value']?.toString() ?? '',
          type: entry['type']?.toString() ?? '',
          desc: entry['description']?.toString() ?? '',
        );
      }).toList();
    } catch (e) {
      showSnackbar("Failed to parse configuration: $e", Colors.red);
      return [];
    }
  }

  bool isValidValue(String value, String type) {
    switch (type.toLowerCase()) {
      case 'int':
        return int.tryParse(value) != null;
      case 'double':
        return double.tryParse(value) != null;
      default:
        return value.isNotEmpty;
    }
  }

  void showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  Future<void> updateData() async {
    setState(() => isUpdating = true);
    try {
      String updatedData =
      jsonEncode(configParameters.map((param) => param.toJson()).toList());
      await targetCharacteristic?.write(utf8.encode(updatedData));
      showSnackbar("Data updated successfully.", Colors.green);
    } catch (e) {
      showSnackbar("Failed to update data: $e", Colors.red);
    } finally {
      setState(() => isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Device Configuration"),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: buildConnectionStatus(),
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: isUpdating ? null : () => updateData(),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(150, 50),
                  ),
                  child: isUpdating
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Update Data"),
                ),
                ElevatedButton(
                  onPressed: isUpdating ? null : () => resetConfiguration(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    minimumSize: const Size(150, 50),
                  ),
                  child: const Text("Reset Configuration"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildConnectionStatus() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("Status: ", style: TextStyle(fontSize: 16)),
        isAuthenticated
            ? const Text("Connected",
            style: TextStyle(color: Colors.green, fontSize: 16))
            : const Text("Disconnected",
            style: TextStyle(color: Colors.red, fontSize: 16)),
      ],
    );
  }

  Widget buildConfigForm() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: ListView.builder(
        itemCount: configParameters.length,
        itemBuilder: (context, index) {
          final param = configParameters[index];
          TextEditingController controller =
          TextEditingController(text: param.value);

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
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18),
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
                        if (isValidValue(newValue, param.type)) {
                          param.value = newValue;
                        } else {
                          showSnackbar(
                              "Invalid value for ${param.key}.", Colors.orange);
                        }
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
