import 'package:flutter/material.dart';

class AuthenticationPage extends StatefulWidget {
  final Future<bool> Function(String) onPinEntered;

  AuthenticationPage({required this.onPinEntered});

  @override
  _AuthenticationPageState createState() => _AuthenticationPageState();
}

class _AuthenticationPageState extends State<AuthenticationPage> {
  final TextEditingController _pinController = TextEditingController();
  String _errorMessage = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Authentication")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Enter 6-digit PIN",
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (_errorMessage.isNotEmpty)
              Text(
                _errorMessage,
                style: const TextStyle(color: Colors.red),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _pinController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: "******",
              ),
              maxLength: 6,
              obscureText: true,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                letterSpacing: 16,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                if (_pinController.text.length == 6) {
                  bool isCorrect = await widget.onPinEntered(_pinController.text);

                  if (isCorrect) {
                    Navigator.pop(context);
                  } else {
                    setState(() {
                      _errorMessage = "Incorrect PIN. Please try again.";
                    });
                  }
                } else {
                  setState(() {
                    _errorMessage = "Please enter a 6-digit PIN.";
                  });
                }
              },
              child: const Text("Submit"),
            ),
          ],
        ),
      ),
    );
  }
}
