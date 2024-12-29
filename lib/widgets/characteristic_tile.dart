import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import "descriptor_tile.dart";

class CharacteristicTile extends StatelessWidget {
  final BluetoothCharacteristic characteristic;
  final List<DescriptorTile> descriptorTiles;
  final VoidCallback onRead; // Read callback
  final Function(String) onWrite; // Write callback

  const CharacteristicTile({
    super.key,
    required this.characteristic,
    required this.descriptorTiles,
    required this.onRead, // Accept read callback
    required this.onWrite, // Accept write callback
  });

  Widget buildReadButton(BuildContext context) {
    return TextButton(
      onPressed: onRead,
      child: const Text("Read"), // Call the passed onRead callback
    );
  }

  Widget buildWriteButton(BuildContext context) {
    return TextButton(
      child: const Text("Write"),
      onPressed: () {
        // Here you can implement a dialog to get input for the write action
        // For simplicity, we'll just write a static string
        onWrite("Hello from Flutter!"); // Example value to write
      },
    );
  }

  Widget buildButtonRow(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        buildReadButton(context),
        buildWriteButton(context),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text('Characteristic: ${characteristic.uuid.toString()}'),
      subtitle: buildButtonRow(context),
    );
  }
}
