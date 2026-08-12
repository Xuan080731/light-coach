import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class MealReminderService {
  MealReminderService._();

  static final MealReminderService instance = MealReminderService._();
  static const _channelId = 'meal_log_reminders';
  static const _channelName = '餐點紀錄提醒';
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  var _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezone.identifier));
    } catch (_) {
      // UTC is a safe fallback if a device cannot report an IANA timezone.
    }
    await _notifications.initialize(
        settings: const InitializationSettings(
            android: AndroidInitializationSettings('ic_notification')));
    _initialized = true;
  }

  Future<bool> requestPermission() async {
    await initialize();
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? true;
  }

  Future<void> scheduleDaily({required int hour, required int minute}) async {
    await initialize();
    final now = tz.TZDateTime.now(tz.local);
    var next =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!next.isAfter(now)) {
      final tomorrow = now.add(const Duration(days: 1));
      next = tz.TZDateTime(
          tz.local, tomorrow.year, tomorrow.month, tomorrow.day, hour, minute);
    }
    await _notifications.zonedSchedule(
      id: _notificationId(hour, minute),
      title: '記錄今天的餐點',
      body: '花一分鐘補上今天吃了什麼，讓熱量摘要更準確。',
      scheduledDate: next,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: '提醒使用者記錄每日餐點',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: 'ic_notification',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'meal_log',
    );
  }

  Future<void> cancelDaily({required int hour, required int minute}) async {
    await initialize();
    await _notifications.cancel(id: _notificationId(hour, minute));
  }

  static int _notificationId(int hour, int minute) => 1000 + hour * 60 + minute;
}
