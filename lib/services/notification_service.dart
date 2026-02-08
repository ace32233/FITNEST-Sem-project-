import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  debugPrint('Background notification tapped: ${notificationResponse.payload}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  // Stable 32-bit IDs
  int stableId(String s) {
    const int fnvPrime = 16777619;
    int hash = 2166136261;
    for (final c in s.codeUnits) {
      hash ^= c;
      hash = (hash * fnvPrime) & 0xFFFFFFFF;
    }
    return hash & 0x7FFFFFFF;
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Timezone DB
      tzdata.initializeTimeZones();

      // Attempt to set local timezone from device, fallback to Kathmandu
      try {
        final String timeZoneName = DateTime.now().timeZoneName;
        tz.setLocalLocation(tz.getLocation(timeZoneName));
        debugPrint('✅ tz.local set to device timezone: $timeZoneName');
      } catch (e) {
        tz.setLocalLocation(tz.getLocation('Asia/Kathmandu'));
        debugPrint('⚠️ Falling back to default timezone: Asia/Kathmandu');
      }

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('Notification tapped: ${response.payload}');
        },
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );

      _isInitialized = true;
      debugPrint('✅ Notifications initialized');

      await _requestPermissions();
    } catch (e) {
      debugPrint('❌ NotificationService init error: $e');
    }
  }

  Future<void> _requestPermissions() async {
    try {
      final status = await Permission.notification.request();
      debugPrint('🔔 Notification permission: $status');

      if (Platform.isAndroid) {
        // Request exact alarm permission for Android 13+
        if (await Permission.scheduleExactAlarm.isDenied) {
          final alarmStatus = await Permission.scheduleExactAlarm.request();
          debugPrint('🔔 Exact alarm permission: $alarmStatus');
        }
      }

      if (Platform.isIOS) {
        final iosPlugin = _notifications.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        await iosPlugin?.requestPermissions(alert: true, badge: true, sound: true);
      }
    } catch (e) {
      debugPrint('❌ Permission request error: $e');
    }
  }

  NotificationDetails _details(String body) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'water_reminder_channel',
        'Water Reminders',
        channelDescription: 'Notifications for water intake reminders',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
        styleInformation: BigTextStyleInformation(body),
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute, {int? dayOfWeek}) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (dayOfWeek != null) {
      // Adjust to the specific day of week
      while (scheduled.weekday != dayOfWeek) {
        scheduled = scheduled.add(const Duration(days: 1));
      }
      // If it's already today and the time has passed, move to next week
      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 7));
      }
    } else {
      // Daily: if time has passed today, move to tomorrow
      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }
    }
    return scheduled;
  }

  /// Schedules a water reminder. If activeDays is null or all 7 days, schedules daily.
  /// Otherwise schedules for each specific day.
  Future<void> scheduleWaterReminder({
    required int baseId,
    required String title,
    required String body,
    required int hour,
    required int minute,
    Set<int>? activeDays,
  }) async {
    if (!_isInitialized) await initialize();

    // Cancel all previous instances for this reminder
    await cancelByBaseId(baseId);

    // If activeDays is empty, don't schedule anything
    if (activeDays != null && activeDays.isEmpty) return;

    // Determine if we should schedule as a single daily reminder or multiple weekly ones
    bool isDaily = activeDays == null || activeDays.length == 7;

    if (isDaily) {
      final scheduledDate = _nextInstanceOfTime(hour, minute);
      await _scheduleZoned(
        id: baseId,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        matchComponents: DateTimeComponents.time,
      );
      debugPrint('✅ Scheduled DAILY id=$baseId at $hour:${minute.toString().padLeft(2, '0')}');
    } else {
      for (int day in activeDays) {
        // Map 0 (Sunday) to 7 (DateTime.sunday)
        int weekday = day == 0 ? DateTime.sunday : day;
        // Use a unique ID for each day to avoid collisions
        int notificationId = baseId + weekday;
        final scheduledDate = _nextInstanceOfTime(hour, minute, dayOfWeek: weekday);

        await _scheduleZoned(
          id: notificationId,
          title: title,
          body: body,
          scheduledDate: scheduledDate,
          matchComponents: DateTimeComponents.dayOfWeekAndTime,
        );
        debugPrint('✅ Scheduled WEEKLY id=$notificationId (day $weekday) at $hour:${minute.toString().padLeft(2, '0')}');
      }
    }
  }

  Future<void> _scheduleZoned({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required DateTimeComponents matchComponents,
  }) async {
    try {
      await _notifications.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        _details(body),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: matchComponents,
      );
    } catch (e) {
      debugPrint('⚠️ Falling back to inexact schedule for id=$id: $e');
      await _notifications.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        _details(body),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: matchComponents,
      );
    }
  }

  Future<void> cancelByBaseId(int baseId) async {
    try {
      // Cancel the daily one
      await _notifications.cancel(baseId);
      // Cancel all possible weekly ones (1-7)
      for (int i = 1; i <= 7; i++) {
        await _notifications.cancel(baseId + i);
      }
      debugPrint('✓ Cancelled all notifications related to baseId=$baseId');
    } catch (e) {
      debugPrint('❌ Cancel error for baseId=$baseId: $e');
    }
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    final pending = await _notifications.pendingNotificationRequests();
    debugPrint('📋 Pending: ${pending.map((e) => e.id).toList()}');
    return pending;
  }

  Future<void> showImmediateNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_isInitialized) await initialize();
    await _notifications.show(id, title, body, _details(body));
  }
}
