import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class GestureSettings extends ChangeNotifier {
  final _storage = FlutterSecureStorage();
  String gestureType = 'longpress';
  int requiredTaps = 5;

  GestureSettings() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    gestureType = await _storage.read(key: 'gesture_type') ?? 'longpress';
    requiredTaps =
        int.tryParse(await _storage.read(key: 'required_taps') ?? '5') ?? 5;
    notifyListeners();
  }

  Future<void> setGestureType(String type) async {
    gestureType = type;
    await _storage.write(key: 'gesture_type', value: type);
    notifyListeners();
  }

  Future<void> setRequiredTaps(int taps) async {
    requiredTaps = taps;
    await _storage.write(key: 'required_taps', value: taps.toString());
    notifyListeners();
  }
}
