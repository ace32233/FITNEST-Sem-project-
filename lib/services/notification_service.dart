import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('NotificationService already initialized');
      return;
    }

    try {
      // Initialize timezone
      tz.initializeTimeZones();
      debugPrint('Timezone initialized');

      // Android initialization settings
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS initialization settings
      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      final initialized = await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('Notification tapped: ${response.payload}');
        },
      );

      if (initialized == true) {
        debugPrint('Notifications initialized successfully');
        _isInitialized = true;
        
        // Request permissions after initialization
        await _requestPermissions();
      } else {
        debugPrint('Failed to initialize notifications');
      }
    } catch (e) {
      debugPrint('Error initializing notifications: $e');
    }
  }

  Future<void> _requestPermissions() async {
    try {
      // Request notification permission
      final notificationStatus = await Permission.notification.request();
      debugPrint('Notification permission: $notificationStatus');

      // For Android 12+ (API 31+), we need SCHEDULE_EXACT_ALARM permission
      // Note: permission_handler doesn't support this yet, so we just inform the user
      if (defaultTargetPlatform == TargetPlatform.android) {
        debugPrint('For Android 12+, ensure SCHEDULE_EXACT_ALARM is granted in system settings');
      }
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
    }
  }

  Future<void> scheduleWaterReminder({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    Set<int>? activeDays, // 0=Sunday, 1=Monday, etc.
  }) async {
    if (!_isInitialized) {
      debugPrint('NotificationService not initialized. Initializing now...');
      await initialize();
    }

    try {
      // If no active days specified, schedule for all days
      if (activeDays == null || activeDays.isEmpty) {
        await _scheduleSingleReminder(id, title, body, hour, minute);
        return;
      }

      // If all days are active, schedule a simple daily reminder
      if (activeDays.length == 7) {
        await _scheduleSingleReminder(id, title, body, hour, minute);
        return;
      }

      // For specific days, we need to schedule multiple notifications
      // Cancel any existing notification with this base ID first
      await cancelNotification(id);

      // Schedule a notification for each active day
      for (int dayIndex in activeDays) {
        final notificationId = id + dayIndex; // Unique ID per day
        final scheduledDate = _nextInstanceOfDayAndTime(dayIndex, hour, minute);
        
        await _notifications.zonedSchedule(
          notificationId,
          title,
          body,
          scheduledDate,
          NotificationDetails(
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
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
        
        debugPrint('✓ Scheduled notification ID: $notificationId for day $dayIndex at $hour:${minute.toString().padLeft(2, '0')} - ${scheduledDate.toString()}');
      }
    } catch (e) {
      debugPrint('❌ Error scheduling water reminder: $e');
      rethrow;
    }
  }

  Future<void> _scheduleSingleReminder(
    int id,
    String title,
    String body,
    int hour,
    int minute,
  ) async {
    try {
      final scheduledDate = _nextInstanceOfTime(hour, minute);
      
      await _notifications.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        NotificationDetails(
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
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      
      debugPrint('✓ Scheduled daily notification ID: $id at $hour:${minute.toString().padLeft(2, '0')} - ${scheduledDate.toString()}');
    } catch (e) {
      debugPrint('❌ Error scheduling single reminder: $e');
      rethrow;
    }
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  tz.TZDateTime _nextInstanceOfDayAndTime(int dayOfWeek, int hour, int minute) {
    tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    
    // Find the next occurrence of the specified day
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // FIXED: Correct weekday calculation
    // dayOfWeek parameter: 0=Sunday, 1=Monday, ..., 6=Saturday
    // scheduledDate.weekday: 1=Monday, 2=Tuesday, ..., 7=Sunday
    
    // Convert Flutter's weekday (1-7, Mon-Sun) to 0-6 (Sun-Sat)
    int currentWeekday = scheduledDate.weekday == 7 ? 0 : scheduledDate.weekday;
    
    // Calculate days until target day
    int daysUntilTarget = (dayOfWeek - currentWeekday + 7) % 7;

    // If it's the same day but time has passed, schedule for next week
    if (daysUntilTarget == 0 && scheduledDate.isBefore(now)) {
      daysUntilTarget = 7;
    }

    scheduledDate = scheduledDate.add(Duration(days: daysUntilTarget));
    
    debugPrint('Day calculation: current=$currentWeekday, target=$dayOfWeek, daysUntil=$daysUntilTarget');
    
    return scheduledDate;
  }

  Future<void> cancelNotification(int id) async {
    try {
      // Cancel the base notification and all day-specific ones
      await _notifications.cancel(id);
      for (int i = 0; i < 7; i++) {
        await _notifications.cancel(id + i);
      }
      debugPrint('✓ Cancelled notification ID: $id (and variants)');
    } catch (e) {
      debugPrint('❌ Error cancelling notification: $e');
    }
  }

  Future<void> cancelAllNotifications() async {
    try {
      await _notifications.cancelAll();
      debugPrint('✓ Cancelled all notifications');
    } catch (e) {
      debugPrint('❌ Error cancelling all notifications: $e');
    }
  }

  // Show immediate notification (for testing)
  Future<void> showImmediateNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      await _notifications.show(
        id,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'water_reminder_channel',
            'Water Reminders',
            channelDescription: 'Notifications for water intake reminders',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            playSound: true,
            enableVibration: true,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
      debugPrint('✓ Showed immediate notification ID: $id');
    } catch (e) {
      debugPrint('❌ Error showing immediate notification: $e');
    }
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    try {
      final pending = await _notifications.pendingNotificationRequests();
      debugPrint('📋 Pending notifications: ${pending.length}');
      for (var notification in pending) {
        debugPrint('  - ID: ${notification.id}, Title: ${notification.title}');
      }
      return pending;
    } catch (e) {
      debugPrint('❌ Error getting pending notifications: $e');
      return [];
    }
  }

  // Helper method to test notifications
  Future<void> scheduleTestNotification() async {
    final now = DateTime.now();
    await scheduleWaterReminder(
      id: 99999,
      title: 'Test Notification 🧪',
      body: 'If you see this, notifications are working!',
      hour: now.hour,
      minute: now.minute + 1,
      activeDays: {now.weekday == 7 ? 0 : now.weekday}, // Convert to 0-6 format
    );
    debugPrint('⏰ Test notification scheduled for ${now.hour}:${(now.minute + 1).toString().padLeft(2, '0')}');
  }
}