import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../utils/json_parser.dart';

class DeviceScreen extends StatefulWidget {
  final BluetoothDevice device;

  const DeviceScreen({Key? key, required this.device}) : super(key: key);

  @override
  _DeviceScreenState createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  BluetoothConnectionState _connectionState = BluetoothConnectionState.disconnected;
  List<ConfigParameter> configParameters = []; // Parsed JSON data

  @override
  void initState() {
    super.initState();
    widget.device.connectionState.listen((state) {
      _connectionState = state;
      if (_connectionState == BluetoothConnectionState.connected) {
        discoverServicesAndReadData(); // Proceed with reading services
      }
      setState(() {}); // Update the UI when connection state changes
    });
    connectToDevice(); // Initiate the connection process
  }

  Future<void> connectToDevice() async {
    try {
      await widget.device.connect();
      print("Connected to device.");
    } catch (e) {
      print("Error connecting to device: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to connect to device: $e")),
      );
    }
  }

  Future<void> discoverServicesAndReadData() async {
    try {
      print("Discovering services...");
      List<BluetoothService> services = await widget.device.discoverServices();
      for (var service in services) {
        for (var characteristic in service.characteristics) {
          if (characteristic.properties.read &&
              characteristic.uuid.toString() == 'abcdefab-1234-5678-1234-abcdefabcdef') {
            await readAndParseCharacteristic(characteristic);
            return;
          }
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No JSON characteristic found.")),
      );
    } catch (e) {
      print("Error discovering services: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error discovering services: $e")),
      );
    }
  }

  Future<void> readAndParseCharacteristic(BluetoothCharacteristic characteristic) async {
    try {
      List<int> value = await characteristic.read();
      String jsonString = String.fromCharCodes(value);
      configParameters = parseConfig(jsonString);
      setState(() {}); // Update the UI with parsed data
    } catch (e) {
      print("Error reading characteristic: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error reading characteristic: $e")),
      );
    }
  }

  Future<void> refreshData() async {
    await discoverServicesAndReadData();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Data refreshed!")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Device Configuration"),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: refreshData,
          ),
        ],
      ),
      body: _connectionState == BluetoothConnectionState.connected
          ? buildConfigForm()
          : Center(child: CircularProgressIndicator()),
    );
  }

  Widget buildConfigForm() {
    return ListView.builder(
      itemCount: configParameters.length,
      itemBuilder: (context, index) {
        final param = configParameters[index];
        TextEditingController controller = TextEditingController(text: param.value);

        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    param.desc,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  TextFormField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: 'Value',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (newValue) {
                      param.value = newValue; // Update the parameter value
                    },
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Type: ${param.type}",
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    widget.device.disconnect();
    super.dispose();
  }
}
