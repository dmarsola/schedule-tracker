import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Permission.camera.request();
  await Permission.notification.request();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Schedule QR Scanner',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: QRScannerScreen(),
    );
  }
}

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  _QRScannerScreenState createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  bool _scanned = false;

  void _onDetect(BarcodeCapture barcode) {
    if (_scanned) return;
    final data = barcode.barcodes.first.rawValue;
    if (data != null) {
      setState(() => _scanned = true);
      final parsed = jsonDecode(data);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ScheduleScreen(scheduleData: parsed),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Scan QR Code")),
      body: MobileScanner(onDetect: _onDetect),
    );
  }
}

class ScheduleScreen extends StatefulWidget {
  final Map<String, dynamic> scheduleData;
  const ScheduleScreen({super.key, required this.scheduleData});

  @override
  _ScheduleScreenState createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  List<Map<String, dynamic>> schedule = [];
  List<bool> toggles = [];

  final Map<String, IconData> iconMap = {
    "bed": FontAwesomeIcons.bed,
    "tooth": FontAwesomeIcons.tooth,
    "breakfast": FontAwesomeIcons.mugSaucer,
    "uniform": FontAwesomeIcons.shirt,
    "book": FontAwesomeIcons.book,
    "car": FontAwesomeIcons.car,
    "bus": FontAwesomeIcons.bus,
    "default": FontAwesomeIcons.boltLightning,
  };

  @override
  void initState() {
    super.initState();
    tz.initializeTimeZones();
    schedule = List<Map<String, dynamic>>.from(widget.scheduleData['schedule']);
    toggles = List.filled(schedule.length, false);
    _initializeNotifications();
    _scheduleNotifications();
  }

  Future<void> _initializeNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: android, iOS: ios);
    await flutterLocalNotificationsPlugin.initialize(initSettings);
  }

  void _scheduleNotifications() async {
    for (int i = 0; i < schedule.length; i++) {
      final item = schedule[i];
      if (item.containsKey('time')) {
        final timeParts = item['time'].split(':');
        final hour = int.parse(timeParts[0]);
        final minute = int.parse(timeParts[1]);
        final frequency = item['frequency'] ?? 'daily';

        final androidDetails = AndroidNotificationDetails(
          'schedule_channel',
          'Schedule Notifications',
          importance: Importance.max,
          priority: Priority.high,
        );
        final iosDetails = DarwinNotificationDetails();
        final details =
            NotificationDetails(android: androidDetails, iOS: iosDetails);

        final days = (frequency == 'weekdays')
            ? [
                DateTime.monday,
                DateTime.tuesday,
                DateTime.wednesday,
                DateTime.thursday,
                DateTime.friday
              ]
            : [
                DateTime.monday,
                DateTime.tuesday,
                DateTime.wednesday,
                DateTime.thursday,
                DateTime.friday,
                DateTime.saturday,
                DateTime.sunday
              ];

        for (final day in days) {
          final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
          tz.TZDateTime scheduledDate = tz.TZDateTime(
              tz.local, now.year, now.month, now.day, hour, minute);
          while (scheduledDate.weekday != day || scheduledDate.isBefore(now)) {
            scheduledDate = scheduledDate.add(Duration(days: 1));
          }

          await flutterLocalNotificationsPlugin.zonedSchedule(
            i * 10 + day, // unique ID
            item['label'],
            'Scheduled Task: ${item['label']}',
            scheduledDate,
            details,
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Your Schedule")),
      body: ListView.builder(
        itemCount: schedule.length,
        itemBuilder: (context, index) {
          final item = schedule[index];
          final iconName = item['icon'];
          return ListTile(
            leading: iconName != null && iconMap[iconName] != null
                ? Icon(iconMap[iconName])
                : Icon(iconMap['default']),
            title: Text(item['label'], style: TextStyle(fontSize: 18)),
            trailing: Switch(
              value: toggles[index],
              onChanged: (val) => setState(() => toggles[index] = val),
            ),
          );
        },
      ),
    );
  }
}
