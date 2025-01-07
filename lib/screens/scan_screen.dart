  import 'dart:async';
  import 'package:flutter/material.dart';
  import 'package:flutter_blue_plus/flutter_blue_plus.dart';
  import 'device_screen.dart';
  import '../utils/snackbar.dart';
  import '../widgets/scan_result_tile.dart';

  class ScanScreen extends StatefulWidget {
    const ScanScreen({super.key});

    @override
    State<ScanScreen> createState() => _ScanScreenState();
  }

  class _ScanScreenState extends State<ScanScreen> {
    List<BluetoothDevice> _systemDevices = [];
    List<ScanResult> _scanResults = [];
    final List<String> _connectedDevices = [];
    bool _isScanning = false;
    bool _isConnecting = false;
    String _searchQuery = "";

    late StreamSubscription<List<ScanResult>> _scanResultsSubscription;
    late StreamSubscription<bool> _isScanningSubscription;

    @override
    void initState() {
      super.initState();
      loadConnectedDevices();
      _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
        setState(() {
          _scanResults = results
              .where((result) => !_connectedDevices.contains(result.device.remoteId.str))
              .toList();
        });
      }, onError: (e) {
        Snackbar.show(ABC.b, "Scan Error: $e", success: false);
      });

      _isScanningSubscription = FlutterBluePlus.isScanning.listen((state) {
        setState(() {
          _isScanning = state;
        });
      });
    }

    Future<void> loadConnectedDevices() async {
      try {
        _systemDevices = FlutterBluePlus.connectedDevices;
        setState(() {
          _connectedDevices.clear();
          _connectedDevices.addAll(_systemDevices.map((device) => device.remoteId.str));
        });
      } catch (e) {
      }
    }

    @override
    void dispose() {
      _scanResultsSubscription.cancel();
      _isScanningSubscription.cancel();
      super.dispose();
    }

    Future<void> onScanPressed() async {
      try {
        await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
      } catch (e) {
        Snackbar.show(ABC.b, "Scan Error: $e", success: false);
      }
    }

    Future<void> onStopPressed() async {
      try {
        await FlutterBluePlus.stopScan();
      } catch (e) {
        Snackbar.show(ABC.b, "Stop Scan Error: $e", success: false);
      }
    }

    Future<void> onConnectPressed(BluetoothDevice device) async {
      setState(() {
        _isConnecting = true;
      });
      if (!device.isConnected) {
        try {
          await device.connect();
          Snackbar.show(ABC.c, "Connect: Success", success: true);
          setState(() {
            if (!_connectedDevices.contains(device.remoteId.str)) {
              _connectedDevices.add(device.remoteId.str);
            }
            _scanResults.removeWhere((result) => result.device.remoteId.str == device.remoteId.str);
          });
          await loadConnectedDevices();
        } catch (e) {
          Snackbar.show(ABC.c, "Connect Error: $e", success: false);
        } finally {
          setState(() {
            _isConnecting = false;
          });
        }
      }
    }

    Future<void> onDisconnectPressed(BluetoothDevice device) async {
      try {
        await device.disconnect();
        setState(() {
          _connectedDevices.removeWhere((id) => id == device.remoteId.str);
        });
        Snackbar.show(ABC.b, "Disconnected from ${device.remoteId.str}", success: true);
      } catch (e) {
        Snackbar.show(ABC.c, "Disconnect Error: $e", success: false);
      }
    }

    Future<void> onRefresh() async {
      await loadConnectedDevices();
    }

    List<Widget> _buildConnectedDeviceTiles() {
      return _systemDevices.map((device) {
        return ListTile(
          title: Text(device.remoteId.str),
          tileColor: Colors.green[100],
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => DeviceScreen(device: device),
            ));
          },
          trailing: ElevatedButton(
            onPressed: () => onDisconnectPressed(device),
            child: const Text('DISCONNECT'),
          ),
        );
      }).toList();
    }

    List<Widget> _buildScanResultTiles(BuildContext context) {
      return _scanResults.where((result) {
        return result.device.platformName.toLowerCase().contains(_searchQuery.toLowerCase());
      }).map((r) {
        return ScanResultTile(
          result: r,
          onTap: () => onConnectPressed(r.device),
          onDisconnectPressed: () => onDisconnectPressed(r.device),
          isConnecting: _isConnecting,
        );
      }).toList();
    }

    Widget buildScanButton(BuildContext context) {
      return FloatingActionButton(
        onPressed: _isScanning ? onStopPressed : onScanPressed,
        backgroundColor: _isScanning ? Colors.red : Colors.blue,
        child: _isScanning
            ? SizedBox(
          width: 23.0,
          height: 23.0,
          child: CircularProgressIndicator(color: Colors.white),
        )
            : Icon(Icons.search),
      );
    }

    Widget buildHeader(BuildContext context) {
      return Container(
        height: 100,
        color: Colors.blue,
        padding: const EdgeInsets.only(top: 50, bottom: 16),
        child: const Center(
          child: Text(
            'Universal Configurator BLE',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    Widget buildFooter(BuildContext context) {
      return Container(
        color: Colors.grey,
        padding: const EdgeInsets.symmetric(vertical: 10),
        width: double.infinity,
        child: const Text(
          'Copyright © TA Kelompok 04 - MMS',
          style: TextStyle(
            fontSize: 14,
            color: Colors.black,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    @override
    Widget build(BuildContext context) {
      return ScaffoldMessenger(
        key: Snackbar.snackBarKeyB,
        child: Scaffold(
          body: Column(
            children: [
              buildHeader(context),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  decoration: const InputDecoration(labelText: 'Search Devices'),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
              Expanded(
                child: ListView(
                  children: [
                    if (_systemDevices.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text('Connected Devices', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ..._buildConnectedDeviceTiles(),
                    if (_scanResults.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text('Available Devices', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ..._buildScanResultTiles(context),
                  ],
                ),
              ),
              buildFooter(context),
            ],
          ),
          floatingActionButton: Container(
            margin: const EdgeInsets.only(bottom: 30),
            child: buildScanButton(context),
          ),
        ),
      );
    }
  }