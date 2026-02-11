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
      // ---- Timezone init ----
      tzdata.initializeTimeZones();
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Kathmandu'));
        debugPrint('✅ tz.local set to: Asia/Kathmandu');
      } catch (e) {
        debugPrint('⚠️ Could not set tz to Asia/Kathmandu: $e. Using UTC.');
        tz.setLocalLocation(tz.UTC);
      }

      // ---- Init settings ----
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

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

      // ---- IMPORTANT for Android 8+ : create channel explicitly ----
      if (Platform.isAndroid) {
        final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

        await androidPlugin?.createNotificationChannel(
          const AndroidNotificationChannel(
            'water_reminder_channel',
            'Water Reminders',
            description: 'Notifications for water intake reminders',
            importance: Importance.max,
            playSound: true,
          ),
        );

        // ---- IMPORTANT for Android 13+ : runtime permission via plugin ----
        // (permission_handler sometimes returns granted but still blocks)
        await androidPlugin?.requestNotificationsPermission();
      }

      _isInitialized = true;
      debugPrint('✅ Notifications initialized');

      await _requestPermissions();
    } catch (e) {
      debugPrint('❌ NotificationService init error: $e');
    }
  }

  Future<void> _requestPermissions() async {
    try {
      // Android 13+ notification permission (still request with permission_handler too)
      final notifStatus = await Permission.notification.request();
      debugPrint('🔔 Notification permission: $notifStatus');

      if (Platform.isAndroid) {
        // Android 12+ exact alarm permission (needed for exactAllowWhileIdle)
        // NOTE: This will open system prompt only on supported Android versions.
        if (await Permission.scheduleExactAlarm.isDenied) {
          final alarmStatus = await Permission.scheduleExactAlarm.request();
          debugPrint('⏰ Exact alarm permission: $alarmStatus');
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

    try {
      // Android 12/13+ best option (exact while idle)
      await _notifications.zonedSchedule(
        baseId,
        title,
        body,
        scheduledDate,
        _details(body),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // daily repeat
      );

      debugPrint(
        '✅ Scheduled DAILY id=$baseId at $hour:${minute.toString().padLeft(2, '0')} -> '
        '$scheduledDate (tz.local=${tz.local.name})',
      );
    } catch (e) {
      debugPrint('❌ Exact schedule failed, fallback to inexact: $e');

      // Fallback if exact alarms are not allowed by OEM/system settings
      await _notifications.zonedSchedule(
        baseId,
        title,
        body,
        scheduledDate,
        _details(body),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
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
