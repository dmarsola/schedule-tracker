import 'package:flutter/material.dart';

class GestureWrapper extends StatefulWidget {
  final Widget child;
  final String gestureType; // 'longpress' or 'multitap'
  final int requiredTaps;
  final VoidCallback onTrigger;

  const GestureWrapper({
    super.key,
    required this.child,
    required this.gestureType,
    required this.requiredTaps,
    required this.onTrigger,
  });

  @override
  State<GestureWrapper> createState() => _GestureWrapperState();
}

class _GestureWrapperState extends State<GestureWrapper> {
  int tapCount = 0;
  DateTime lastTap = DateTime.now();

  void _handleTap() {
    final now = DateTime.now();
    if (now.difference(lastTap).inMilliseconds > 1000) tapCount = 0;
    lastTap = now;
    tapCount++;

    if (tapCount >= widget.requiredTaps) {
      tapCount = 0;
      widget.onTrigger();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.gestureType == 'multitap') {
      return GestureDetector(
        onTap: _handleTap,
        child: widget.child,
      );
    } else {
      return GestureDetector(
        onLongPress: widget.onTrigger,
        child: widget.child,
      );
    }
  }
}
