import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:schedule_tracker/services/storage.dart';

class ParentSection extends StatefulWidget {
  const ParentSection({super.key});

  @override
  _ParentSectionState createState() => _ParentSectionState();
}

class _ParentSectionState extends State<ParentSection> {
  final secureStorage = FlutterSecureStorage();
  String _gesture = 'longpress';
  int _requiredTaps = 5;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final gesture =
        await secureStorage.read(key: 'gesture_type') ?? 'longpress';
    final taps =
        int.tryParse(await secureStorage.read(key: 'required_taps') ?? '5') ??
            5;
    setState(() {
      _gesture = gesture;
      _requiredTaps = taps;
    });
  }

  Future<void> _setGesture(String value) async {
    await secureStorage.write(key: 'gesture_type', value: value);
    setState(() {
      _gesture = value;
    });
  }

  Future<void> _setRequiredTaps(int value) async {
    await secureStorage.write(key: 'required_taps', value: value.toString());
    setState(() {
      _requiredTaps = value;
    });
  }

  Future<void> _removePin() async {
    await secureStorage.delete(key: 'secret_pin');
  }

  Future<void> _resetSchedule() async {
    // Using a different storage system for the schedule
    final storage = StorageService();
    await storage.deleteData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Parent Section")),
      body: ListView(
        children: [
          ListTile(
            title: Text("Remove PIN"),
            onTap: () async {
              await _removePin();
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
          ),
          ListTile(
            title: Text("Reset Schedule"),
            onTap: () async {
              await _resetSchedule();
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
          ),
          ListTile(
            title: Text("Access Gesture"),
            subtitle: Text(
                "Current: ${_gesture == 'longpress' ? 'Long Press' : 'Multi Tap'}"),
          ),
          RadioListTile(
            title: Text("Use Long Press"),
            value: 'longpress',
            groupValue: _gesture,
            onChanged: (value) => _setGesture(value as String),
          ),
          RadioListTile(
            title: Text("Use Multi Tap"),
            value: 'multitap',
            groupValue: _gesture,
            onChanged: (value) => _setGesture(value as String),
          ),
          if (_gesture == 'multitap')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: DropdownButton<int>(
                value: _requiredTaps,
                isExpanded: true,
                items: List.generate(6, (index) {
                  int val = 5 + index;
                  return DropdownMenuItem(
                    value: val,
                    child: Text("$val taps"),
                  );
                }),
                onChanged: (val) => _setRequiredTaps(val ?? 5),
              ),
            )
        ],
      ),
    );
  }
}
