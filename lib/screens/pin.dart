import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PinScreen extends StatelessWidget {
  final TextEditingController _controller = TextEditingController();
  final storage = FlutterSecureStorage();

  PinScreen({super.key});

  void _savePin(BuildContext context) async {
    if (_controller.text.length >= 4) {
      await storage.write(key: 'secret_pin', value: _controller.text);
      if (context.mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Set Parent PIN")),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(labelText: "New PIN"),
              obscureText: true,
              keyboardType: TextInputType.number,
            ),
            ElevatedButton(
              onPressed: () => _savePin(context),
              child: Text("Set PIN"),
            )
          ],
        ),
      ),
    );
  }
}
