import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

class DeviceScreen extends StatefulWidget {
  final BluetoothDevice device;

  const DeviceScreen({super.key, required this.device});

  @override
  DeviceScreenState createState() => DeviceScreenState();
}

class DeviceScreenState extends State<DeviceScreen> {
  List<ConfigParameter> configParameters = [];
  Map<String, String> originalValues = {};
  BluetoothCharacteristic? targetCharacteristic;
  bool isAuthenticated = false;
  String validPin = '';
  int _connectionAttempts = 0;
  static const int maxConnectionAttempts = 3;
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    _connectToDevice();
  }

  @override
  void dispose() {
    _disconnectDevice();
    super.dispose();
  }

  Future<void> _connectToDevice() async {
    if (_connectionAttempts >= maxConnectionAttempts) {
      _showErrorDialog("Max connection attempts reached");
      return;
    }

    setState(() {
      _isConnecting = true;
      _connectionAttempts++;
    });

    try {
      await widget.device.connect(autoConnect: false, timeout: const Duration(seconds: 10));
      await _discoverServicesAndReadData();
    } catch (e) {
      _showErrorDialog("Connection failed: ${e.toString()}");
    } finally {
      setState(() => _isConnecting = false);
    }
  }

  Future<void> _discoverServicesAndReadData() async {
    try {
      List<BluetoothService> services = await widget.device.discoverServices();
      List<ConfigParameter> configList = [];

      for (var service in services) {
        for (var characteristic in service.characteristics) {
          if (characteristic.properties.read) {
            try {
              List<int> value = await characteristic.read();
              String data = String.fromCharCodes(value);

              if (data.isEmpty) continue;

              var parsedData = jsonDecode(data);
              configList = _parseConfig(parsedData);
            } catch (e) {
              continue;
            }
          }

          if (characteristic.properties.write) {
            targetCharacteristic = characteristic;
          }
        }
      }

      if (configList.isNotEmpty) {
        setState(() {
          configParameters = configList;
          validPin = configList.firstWhere((param) => param.key == "PIN").value;

          originalValues = {
            for (var param in configParameters) param.key: param.value,
          };
        });
        _promptForPin();
      } else {
        _showSnackbar("No valid JSON data received.", Colors.orange);
      }
    } catch (e) {
      _showSnackbar("Error discovering services: $e", Colors.red);
    }
  }



  Future<void> _promptForPin() async {
    TextEditingController pinController = TextEditingController();
    await _showInputDialog(
      title: "Enter PIN",
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
      onConfirm: () {
        if (pinController.text == validPin) {
          setState(() => isAuthenticated = true);
        } else {
          _showSnackbar("Invalid PIN. Try again.", Colors.red);
        }
      },
    );
  }

  List<ConfigParameter> _parseConfig(Map<String, dynamic> jsonData) {
    try {
      if (jsonData.isEmpty) {
        _showSnackbar("Received data is empty.", Colors.red);
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
      _showSnackbar("Error parsing JSON data.", Colors.red);
      return [];
    }
  }

  Future<void> updateData() async {
    if (targetCharacteristic == null) {
      _showSnackbar("No characteristic to update data.", Colors.orange);
      return;
    }

    Map<String, dynamic> jsonData = {};

    for (var param in configParameters) {
      jsonData[param.key] = {
        'value': param.value,
        'type': param.type,
        'description': param.desc,
      };
    }

    try {
      String updatedData = jsonEncode(jsonData);
      List<int> dataBytes = utf8.encode(updatedData);
      await targetCharacteristic!.write(dataBytes);

      _showSnackbar("Data updated successfully.", Colors.green);

      setState(() {
        originalValues = {
          for (var param in configParameters) param.key: param.value,
        };
      });
    } catch (e) {
      _showSnackbar("Failed to update data: $e", Colors.red);
    }
  }


  Future<void> _showInputDialog({
    required String title,
    required Widget content,
    required VoidCallback onConfirm,
  }) async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: content,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                onConfirm();
                Navigator.of(context).pop();
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  Future<void> _disconnectDevice() async {
    try {
      await widget.device.disconnect();
    } catch (_) {}
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Error"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Device Configuration")),
      body: isAuthenticated
          ? (configParameters.isNotEmpty
          ? buildConfigForm()
          : const Center(child: CircularProgressIndicator()))
          : const Center(child: Text("Authenticate to access data")),
      floatingActionButton: targetCharacteristic != null
          ? FloatingActionButton(
        onPressed: updateData,
        child: const Icon(Icons.save),
      )
          : null,
    );
  }

  Widget buildConfigForm() {
    return ListView.builder(
      itemCount: configParameters.length,
      itemBuilder: (context, index) {
        final param = configParameters[index];
        TextEditingController textController =
        TextEditingController(text: param.value);
        return ListTile(
          title: Text(param.desc),
          subtitle: Text("Value: ${param.value} (Type: ${param.type})"),
          onTap: () => _showInputDialog(
            title: "Edit ${param.desc}",
            content: TextField(
              controller: textController,
              decoration: const InputDecoration(
                labelText: "Value",
                border: OutlineInputBorder(),
              ),
            ),
            onConfirm: () {
              setState(() {
                param.value = textController.text;
                originalValues[param.key] = param.value;
              });
            },
          ),
        );
      },
    );
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
}
