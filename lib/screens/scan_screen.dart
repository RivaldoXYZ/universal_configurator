import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'device_screen.dart';
import '../utils/snackbar.dart';
import '../widgets/scan_result_tile.dart';
import 'Security.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  List<BluetoothDevice> _systemDevices = [];
  List<ScanResult> _scanResults = [];
  final List<String> _connectedDevices = []; // Track connected devices
  bool _isScanning = false;

  late StreamSubscription<List<ScanResult>> _scanResultsSubscription;
  late StreamSubscription<bool> _isScanningSubscription;

  @override
  void initState() {
    super.initState();

    _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
      setState(() {
        _scanResults = results; // Show all scan results
      });
      print("Scan Results: ${_scanResults.length} devices found");
    }, onError: (e) {
      Snackbar.show(ABC.b, prettyException("Scan Error:", e), success: false);
    });

    _isScanningSubscription = FlutterBluePlus.isScanning.listen((state) {
      setState(() {
        _isScanning = state;
      });
    });
  }

  @override
  void dispose() {
    _scanResultsSubscription.cancel();
    _isScanningSubscription.cancel();
    super.dispose();
  }

  Future<void> onScanPressed() async {
    try {
      _systemDevices = await FlutterBluePlus.systemDevices;
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
    } catch (e) {
      Snackbar.show(ABC.b, prettyException("Scan Error:", e), success: false);
    }
  }

  Future<void> onStopPressed() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (e) {
      Snackbar.show(ABC.b, prettyException("Stop Scan Error:", e), success: false);
    }
  }

  Future<void> onConnectPressed(BluetoothDevice device) async {
    if (!await device.isConnected) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => AuthenticationPage(
            onPinEntered: (pin) async {
              if (pin == "123456") { // Customize PIN as needed
                try {
                  await device.connect();
                  Snackbar.show(ABC.c, "Connect: Success", success: true);

                  setState(() {
                    if (!_connectedDevices.contains(device.remoteId.str)) {
                      _connectedDevices.add(device.remoteId.str);
                    }
                  });

                  await onRefresh();
                  return true;
                } catch (e) {
                  Snackbar.show(ABC.c, prettyException("Connect Error:", e), success: false);
                  return false;
                }
              } else {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Snackbar.show(ABC.c, "Incorrect PIN, please try again.", success: false);
                });
                return false;
              }
            },
          ),
        ),
      );
    } else {
      setState(() {
        if (!_connectedDevices.contains(device.remoteId.str)) {
          _connectedDevices.add(device.remoteId.str);
        }
      });
      await onRefresh();
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
      Snackbar.show(ABC.c, prettyException("Disconnect Error:", e), success: false);
    }
  }

  Future<void> onRefresh() async {
    if (!_isScanning) {
      onScanPressed();
    }
    await Future.delayed(const Duration(milliseconds: 500));

    setState(() {
      _connectedDevices.retainWhere((id) {
        return _systemDevices.any((device) => device.remoteId.str == id);
      });
    });
  }

  List<Widget> _buildConnectedDeviceTiles() {
    return _systemDevices.where((device) {
      return _connectedDevices.contains(device.remoteId.str);
    }).map((device) {
      return ListTile(
        title: Text(device.remoteId.str),
        subtitle: const Text('Connected'),
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
    return _scanResults.map((r) {
      return ScanResultTile(
        result: r,
        onTap: () => onConnectPressed(r.device),
        onDisconnectPressed: () => onDisconnectPressed(r.device),
      );
    }).toList();
  }

  Widget buildScanButton(BuildContext context) {
    return FloatingActionButton(
      onPressed: _isScanning ? onStopPressed : onScanPressed,
      backgroundColor: _isScanning ? Colors.red : Colors.blue,
      child: Icon(_isScanning ? Icons.search_off : Icons.search),
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
            Expanded(
              child: RefreshIndicator(
                onRefresh: onRefresh,
                child: ListView(
                  children: [
                    ..._buildConnectedDeviceTiles(),
                    ..._buildScanResultTiles(context),
                  ],
                ),
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
