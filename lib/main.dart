import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'services/notification.dart';

import 'constants/icons.dart';
import 'services/storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().init();
  await Permission.camera.request();
  await Permission.notification.request();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  MyApp({super.key});

  final storage = StorageService();

  Future<Widget> _getInitialScreen() async {
    final data = await storage.loadData();
    if (data != null) {
      return ScheduleScreen(scheduleData: data);
    } else {
      return QRScannerScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Schedule QR Scanner',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: FutureBuilder<Widget>(
        future: _getInitialScreen(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(body: Center(child: CircularProgressIndicator()));
          } else if (snapshot.hasData) {
            return snapshot.data!;
          } else {
            return Scaffold(body: Center(child: Text('Something went wrong')));
          }
        },
      ),
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

  Future<void> _onDetect(BarcodeCapture barcode) async {
    final storage = StorageService();

    if (_scanned) return;
    final data = barcode.barcodes.first.rawValue;
    if (data != null) {
      setState(() => _scanned = true);
      final parsed = jsonDecode(data);
      await storage.saveData(parsed);
      // Navigator.push(
      //   context,
      //   MaterialPageRoute(
      //     builder: (context) => ScheduleScreen(scheduleData: parsed),
      //   ),
      // );
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
    // Cancel all notifications before creating new ones
    await NotificationService().cancelAllNotifications();
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
        // TODO: add more details as needed
        // final iosDetails = DarwinNotificationDetails();
        // final details =
        //     NotificationDetails(android: androidDetails, iOS: iosDetails);

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

          await NotificationService().scheduleNotification(
            id: i * 10 + day, // unique ID
            title: item['label'],
            body: 'Scheduled Task: ${item['label']}',
            scheduledTime: scheduledDate,
            // details, // TODO: implement more details as needed
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
