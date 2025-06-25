import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:schedule_tracker/providers/gesture_settings.dart';
import 'package:schedule_tracker/screens/parent_section.dart';
import 'package:schedule_tracker/screens/pin.dart';
import 'package:schedule_tracker/widgets/gesture_wrapper.dart';

class SecretAccessWidget extends StatelessWidget {
  final Widget child;
  final storage = FlutterSecureStorage();

  SecretAccessWidget({super.key, required this.child});

  Future<void> _tryAccess(BuildContext context) async {
    final pin = await storage.read(key: 'secret_pin');
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => pin == null ? PinScreen() : ParentSection(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<GestureSettings>(context);
    return GestureWrapper(
      gestureType: settings.gestureType,
      requiredTaps: settings.requiredTaps,
      onTrigger: () => _tryAccess(context),
      child: child,
    );
  }
}
