import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    // Initialize timezone
    tz.initializeTimeZones();

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

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
        print('Notification tapped: ${response.payload}');
      },
    );

    // Request permissions
    await _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    // For Android 13+ (API level 33+)
    if (await Permission.scheduleExactAlarm.isDenied) {
      await Permission.scheduleExactAlarm.request();
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
            sound: const RawResourceAndroidNotificationSound('water_drop'),
            playSound: true,
            enableVibration: true,
            styleInformation: BigTextStyleInformation(body),
          ),
          iOS: const DarwinNotificationDetails(
            sound: 'water_drop.aiff',
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
      
      print('Scheduled notification ID: $notificationId for day $dayIndex at $hour:$minute');
    }
  }

  Future<void> _scheduleSingleReminder(
    int id,
    String title,
    String body,
    int hour,
    int minute,
  ) async {
    await _notifications.zonedSchedule(
      id,
      title,
      body,
      _nextInstanceOfTime(hour, minute),
      NotificationDetails(
        android: AndroidNotificationDetails(
          'water_reminder_channel',
          'Water Reminders',
          channelDescription: 'Notifications for water intake reminders',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          sound: const RawResourceAndroidNotificationSound('water_drop'),
          playSound: true,
          enableVibration: true,
          styleInformation: BigTextStyleInformation(body),
        ),
        iOS: const DarwinNotificationDetails(
          sound: 'water_drop.aiff',
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

    // Calculate days until target day
    // dayOfWeek: 0=Sunday, 1=Monday, etc.
    int currentWeekday = scheduledDate.weekday % 7; // Convert to 0=Sunday format
    int daysUntilTarget = (dayOfWeek - currentWeekday) % 7;

    if (daysUntilTarget == 0 && scheduledDate.isBefore(now)) {
      daysUntilTarget = 7; // Schedule for next week if time has passed today
    }

    scheduledDate = scheduledDate.add(Duration(days: daysUntilTarget));
    return scheduledDate;
  }

  Future<void> cancelNotification(int id) async {
    // Cancel the base notification and all day-specific ones
    await _notifications.cancel(id);
    for (int i = 0; i < 7; i++) {
      await _notifications.cancel(id + i);
    }
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  // Show immediate notification (for testing)
  Future<void> showImmediateNotification({
    required int id,
    required String title,
    required String body,
  }) async {
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
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }
}