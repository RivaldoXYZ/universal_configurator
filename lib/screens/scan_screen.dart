import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'device_screen.dart';
import '../utils/snackbar.dart';
import '../widgets/scan_result_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';
  
  class ScanScreen extends StatefulWidget {
    const ScanScreen({super.key});
  
    @override
    State<ScanScreen> createState() => _ScanScreenState();
  }
  
  class _ScanScreenState extends State<ScanScreen> {
    List<BluetoothDevice> _systemDevices = [];
    List<ScanResult> _scanResults = [];
    final List<String> _previouslyConnectedDevices = [];
    final List<String> _connectedDevices = [];
    bool _isScanning = false;
    String _searchQuery = "";
  
    final Map<String, bool> _deviceConnectingStatus = {};
  
    late StreamSubscription<List<ScanResult>> _scanResultsSubscription;
    late StreamSubscription<bool> _isScanningSubscription;

    @override
    void initState() {
      super.initState();
      loadPreviouslyConnectedDevices();
      _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
        setState(() {
          _scanResults = results.where((result) {
            return !_previouslyConnectedDevices.contains(result.device.remoteId.str);
          }).toList();
        });
      }, onError: (e) {
        Snackbar.show(context as ABC, "Scan Error: $e", success: false);
      });

      _isScanningSubscription = FlutterBluePlus.isScanning.listen((state) {
        setState(() {
          _isScanning = state;
        });
      });
    }

    Future<void> loadPreviouslyConnectedDevices() async {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final connectedDevices = FlutterBluePlus.connectedDevices;

      setState(() {
        _previouslyConnectedDevices.clear();

        // Tambahkan perangkat yang sebelumnya terhubung dari SharedPreferences
        _previouslyConnectedDevices.addAll(prefs.getStringList('previouslyConnectedDevices') ?? []);

        // Tambahkan perangkat yang saat ini terhubung jika belum ada
        for (var device in connectedDevices) {
          if (!_previouslyConnectedDevices.contains(device.remoteId.str)) {
            _previouslyConnectedDevices.add(device.remoteId.str);
          }
        }
      });
    }
  
    Future<void> savePreviouslyConnectedDevices() async {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('previouslyConnectedDevices', _previouslyConnectedDevices);
    }
  
    Future<void> resetPreviouslyConnectedDevices() async {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove('previouslyConnectedDevices');
      setState(() {
        _previouslyConnectedDevices.clear();
      });
      Snackbar.show(ABC.b, "All previously connected devices have been reset", success: true);
    }
  
    Future<void> loadConnectedDevices() async {
      try {
        _systemDevices = FlutterBluePlus.connectedDevices;
        setState(() {
          _connectedDevices.clear();
          _connectedDevices.addAll(_systemDevices.map((device) => device.remoteId.str));
        });
      } catch (e) {
        Snackbar.show(ABC.b, "Error loading connected devices: $e", success: false);
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
        _deviceConnectingStatus[device.remoteId.str] = true;
      });
  
      try {
        await device.connect();
        Snackbar.show(ABC.c, "Connect: Success", success: true);
        setState(() {
          if (!_connectedDevices.contains(device.remoteId.str)) {
            _connectedDevices.add(device.remoteId.str);
          }
          if (!_previouslyConnectedDevices.contains(device.remoteId.str)) {
            _previouslyConnectedDevices.add(device.remoteId.str);
          }
          _scanResults.removeWhere((result) => result.device.remoteId.str == device.remoteId.str);
        });
        await savePreviouslyConnectedDevices();
        await loadConnectedDevices();
      } catch (e) {
        Snackbar.show(ABC.c, "Connect Error: $e", success: false);
      } finally {
        setState(() {
          _deviceConnectingStatus[device.remoteId.str] = false;
        });
      }
    }
  
    Future<void> onDisconnectPressed(BluetoothDevice device) async {
      try {
        await device.disconnect();
        setState(() {
          _connectedDevices.removeWhere((id) => id == device.remoteId.str);
        });
        Snackbar.show(ABC.b, "Disconnected from ${device.remoteId.str}", success: true);
  
        await loadConnectedDevices();
      } catch (e) {
        Snackbar.show(ABC.c, "Disconnect Error: $e", success: false);
      }
    }
  
    Future<void> onRefresh() async {
      await loadConnectedDevices();
    }

    List<Widget> _buildPreviouslyConnectedDeviceTiles() {
      return _previouslyConnectedDevices.map((deviceId) {
        // Cari apakah perangkat ditemukan di hasil scan
        ScanResult? matchedResult;
        for (var result in _scanResults) {
          if (result.device.remoteId.str == deviceId) {
            matchedResult = result;
            break; // berhenti setelah menemukan perangkat
          }
        }

        // Periksa apakah perangkat saat ini terhubung
        final isConnected = FlutterBluePlus.connectedDevices.any((device) => device.remoteId.str == deviceId);

        // Tentukan nama perangkat
        final deviceName = matchedResult?.device.platformName.isNotEmpty == true
            ? matchedResult!.device.platformName
            : "Unknown Device";

        // Tentukan status perangkat
        final status = matchedResult == null
            ? 'Not Ready'
            : (isConnected ? 'Connected' : 'Available');

        return ListTile(
          title: Text(deviceName),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(deviceId), // Device ID
              Text( // Status
                status,
                style: TextStyle(
                  color: status == 'Connected'
                      ? Colors.blue
                      : (status == 'Available' ? Colors.green : Colors.grey),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          tileColor: Colors.grey[200],
          trailing: ElevatedButton(
            onPressed: matchedResult != null && !isConnected
                ? () => onConnectPressed(matchedResult!.device)
                : null, // Disable tombol jika perangkat tidak tersedia atau terhubung
            child: const Text('Connect'),
          ),
        );
      }).toList();
    }

    List<Widget> _buildConnectedDeviceTiles() {
      return _systemDevices.map((device) {
        String deviceName = device.platformName.isNotEmpty ? device.platformName : device.remoteId.str;
        return ListTile(
          title: Text(deviceName),
          subtitle: Text(device.remoteId.toString()),
          tileColor: Colors.green[100],
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => DeviceScreen(device: device),
                  ));
                },
                icon: const Icon(
                  Icons.settings,
                  color: Colors.white,
                ),
                label: const Text(''),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[400],
                  padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => onDisconnectPressed(device),
                icon: const Icon(
                  Icons.bluetooth_disabled,
                  color: Colors.white,
                ),
                label: const Text(''),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[400],
                  padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList();
    }

    List<Widget> _buildScanResultTiles(BuildContext context) {
      return _scanResults.where((result) {
        final deviceName = result.device.platformName.isNotEmpty
            ? result.device.platformName
            : result.device.remoteId.str;
        return deviceName.toLowerCase().contains(_searchQuery.toLowerCase());
      }).map((r) {
        return ScanResultTile(
          result: r,
          onTap: () => onConnectPressed(r.device),
          onDisconnectPressed: () => onDisconnectPressed(r.device),
          isConnecting: _deviceConnectingStatus[r.device.remoteId.str] ?? false,
        );
      }).toList();
    }
  
    Widget buildScanButton(BuildContext context) {
      return FloatingActionButton(
        onPressed: _isScanning ? onStopPressed : onScanPressed,
        backgroundColor: _isScanning ? Colors.red : Colors.blue,
        child: _isScanning
            ? const SizedBox(
          width: 23.0,
          height: 23.0,
          child: CircularProgressIndicator(color: Colors.white),
        )
            : const Icon(Icons.search),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Search Devices',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
              Expanded(
                child: _systemDevices.isEmpty && _scanResults.isEmpty
                    ? const Center(
                  child: Text(
                    'No devices found \n Please ensure your devices are discoverable and try again.',
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                    textAlign: TextAlign.center,
                  ),
                )
                    : ListView(
                  children: [
                    if (_systemDevices.isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text('Connected Devices', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ..._buildConnectedDeviceTiles(),
                    if (_previouslyConnectedDevices.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Previously Connected Devices',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            TextButton.icon(
                              onPressed: resetPreviouslyConnectedDevices,
                              icon: const Icon(Icons.refresh, size: 18),
                              label: const Text(
                                'Reset',
                                style: TextStyle(fontSize: 14),
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ..._systemDevices.map((device) {
                      final isConnecting = _deviceConnectingStatus[device.remoteId.str] ?? false;
                      return ListTile(
                        title: Text(device.platformName.isNotEmpty ? device.platformName : 'Unknown Device'),
                        subtitle: Text(device.remoteId.str),
                        trailing: isConnecting
                            ? const CircularProgressIndicator()
                            : ElevatedButton(
                          onPressed: () => onDisconnectPressed(device),
                          child: const Text('Disconnect'),
                        ),
                      );
                    }),
                    ..._buildPreviouslyConnectedDeviceTiles(),
                    if (_scanResults.isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.all(8.0),
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