import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

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

      // ✅ HARD FIX: set local timezone explicitly to Nepal
      // (Remove this line only if you want true device timezone via a plugin)
      tz.setLocalLocation(tz.getLocation('Asia/Kathmandu'));
      debugPrint('✅ tz.local set to: Asia/Kathmandu');

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

      if (Platform.isIOS) {
        final iosPlugin = _notifications.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        await iosPlugin?.requestPermissions(alert: true, badge: true, sound: true);
      }

      debugPrint(
        'Android 12+: If scheduled notifications don’t fire, enable Special Access → Alarms & reminders for this app.',
      );
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
        importance: Importance.high,
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

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// DAILY reminder at hour:minute (activeDays ignored; kept for compatibility)
  Future<void> scheduleWaterReminder({
    required int baseId,
    required String title,
    required String body,
    required int hour,
    required int minute,
    Set<int>? activeDays, // ignored (daily only)
  }) async {
    if (!_isInitialized) await initialize();

    await cancelByBaseId(baseId);

    final scheduledDate = _nextInstanceOfTime(hour, minute);

    await _notifications.zonedSchedule(
      baseId,
      title,
      body,
      scheduledDate,
      _details(body),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // ✅ daily repeat
    );

    debugPrint(
      '✅ Scheduled DAILY id=$baseId at $hour:${minute.toString().padLeft(2, '0')} -> '
      '$scheduledDate (tz.local=${tz.local.name})',
    );
  }

  Future<void> cancelByBaseId(int baseId) async {
    try {
      await _notifications.cancel(baseId);
      debugPrint('✓ Cancelled id=$baseId');
    } catch (e) {
      debugPrint('❌ Cancel error id=$baseId: $e');
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
