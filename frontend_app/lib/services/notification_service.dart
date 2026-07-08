import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'smart_warehouse_channel',
    'Smart Warehouse',
    description: 'Notifications for Smart Warehouse app',
    importance: Importance.high,
  );

  Future<void> init() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(_safeLocalLocation());

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(initSettings);

    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(_channel);
  }

  Future<void> requestPermissionIfNeeded() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
  }

  Future<void> showNow({
    required int id,
    required String title,
    required String body,
  }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'smart_warehouse_channel',
        'Smart Warehouse',
        channelDescription: 'Notifications for Smart Warehouse app',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    await _plugin.show(id, title, body, details);
  }

  Future<void> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'smart_warehouse_channel',
        'Smart Warehouse',
        channelDescription: 'Notifications for Smart Warehouse app',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancel(int id) => _plugin.cancel(id);

  tz.Location _safeLocalLocation() {
    if (kIsWeb) return tz.getLocation('UTC');
    try {
      return tz.getLocation('Asia/Bangkok');
    } catch (_) {
      return tz.getLocation('UTC');
    }
  }
}
