import 'package:flutter/material.dart';
import '../utils/json_parser.dart';

class ConfigEditorScreen extends StatelessWidget {
  final List<ConfigParameter> configParameters;

  ConfigEditorScreen({required this.configParameters});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("ESP32 Configurator")),
      body: ListView.builder(
        itemCount: configParameters.length,
        itemBuilder: (context, index) {
          final parameter = configParameters[index];
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextFormField(
              initialValue: parameter.value,
              decoration: InputDecoration(
                labelText: parameter.desc,
                hintText: 'Enter ${parameter.type.toLowerCase()} value',
              ),
              onChanged: (value) {
                parameter.value = value;
              },
            ),
          );
        },
      ),
    );
  }
}
