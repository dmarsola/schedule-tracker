import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'package:schedule_tracker/providers/gesture_settings.dart';
import 'package:schedule_tracker/widgets/access_secret.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'services/notification.dart';

import 'constants/icons.dart';
import 'services/storage.dart';
import 'styles/general.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().init();
  await Permission.camera.request();
  await Permission.notification.request();

  if (Platform.isAndroid) {
    final channel = MethodChannel('com.example.schedule_tracker/exact_alarm');
    try {
      final result = await channel.invokeMethod<bool>('openExactAlarmSettings');
      // TODO: handle if result == false
    } on PlatformException {
      // TODO: handle exception
    }
  }
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  MyApp({super.key});

  final storage = StorageService();

  Future<Widget> _getInitialScreen() async {
    final data = await storage.loadData();
    if (data != null) {
      return ChangeNotifierProvider(
        create: (_) => GestureSettings(),
        child: ScheduleScreen(scheduleData: data),
      );
    } else {
      return QRScannerScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Schedule QR Scanner',
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.primary,
        ),
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: AppColors.textColor),
        ),
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
  final FlutterTts flutterTts = FlutterTts();

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

  Widget _buildVisualIndicator({required bool isStart}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isStart) Icon(Icons.flag, color: AppColors.shadowColor),
          Container(
            width: 160,
            height: 6,
            margin: EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          if (!isStart) Icon(Icons.flag, color: AppColors.shadowColor),
        ],
      ),
    );
  }

  Future _speak(String text) async {
    await flutterTts.setSpeechRate(0.5);
    await flutterTts.setPitch(1.0);
    await flutterTts.setVolume(1.0);
    await flutterTts.speak(text);
  }

  Widget _buildDividerText(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 16,
            fontStyle: FontStyle.italic,
            color: Colors.grey[600],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF9FAFB),
      appBar: AppBar(
        title: SecretAccessWidget(
          child: Text("Your Schedule"),
        ),
        backgroundColor: Color(0xFF81C784),
        elevation: 0,
      ),
      body: ListView.builder(
        itemCount: schedule.length + 2, // top + bottom indicators
        itemBuilder: (context, index) {
          if (index == 0) return _buildVisualIndicator(isStart: true);
          if (index == schedule.length + 1)
            return _buildVisualIndicator(isStart: false);

          final item = schedule[index - 1];
          final iconName = item['icon'];

          return Container(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  iconName != null && iconMap[iconName] != null
                      ? iconMap[iconName]
                      : iconMap['default'],
                  size: 28,
                  color: Color(0xFF4CAF50),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    item['label'],
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.volume_up, color: Colors.blueGrey),
                  onPressed: () => _speak(item['label']),
                  tooltip: 'Read Aloud',
                ),
                Switch(
                  value: toggles[index - 1],
                  onChanged: (val) => setState(() => toggles[index - 1] = val),
                  activeColor: Color(0xFF81C784),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
  // @override
  // Widget build(BuildContext context) {
  //   return Scaffold(
  //     appBar: AppBar(title: Text("Your Schedule")),
  //     body: ListView.builder(
  //       itemCount: schedule.length,
  //       itemBuilder: (context, index) {
  //         final item = schedule[index];
  //         final iconName = item['icon'];
  //         return ListTile(
  //           leading: iconName != null && iconMap[iconName] != null
  //               ? Icon(iconMap[iconName])
  //               : Icon(iconMap['default']),
  //           title: Text(item['label'], style: TextStyle(fontSize: 18)),
  //           trailing: Switch(
  //             value: toggles[index],
  //             onChanged: (val) => setState(() => toggles[index] = val),
  //           ),
  //         );
  //       },
  //     ),
  //   );
  // }
}
