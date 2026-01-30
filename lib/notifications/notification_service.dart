import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz.initializeTimeZones();
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(initSettings);
  }

  // ================= 1. IMMEDIATE LOW ATTENDANCE ALERT =================
  // Restored this method to fix your compiler errors
  static Future<void> showLowAttendance({
    required int id,
    required String subjectName,
    required double percent,
  }) async {
    await _plugin.show(
      id,
      'Attendance Alert ⚠️',
      '$subjectName attendance is ${percent.toStringAsFixed(1)}%. Attend upcoming classes to reach 75%.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'attendance_channel',
          'Attendance Alerts',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  // ================= 2. 30-MIN PRE-CLASS ALERT (Logic Fixed) =================
  /// Schedules a reminder 30 minutes before class, ONLY if attendance < 80%
  static Future<void> scheduleClassReminder({
    required int id,
    required String subjectName,
    required double currentAttendance,
    required DateTime classStartTime,
  }) async {
    // Logic: Only schedule if attendance is less than 80%
    if (currentAttendance >= 80.0) return;

    // Logic: Calculate 30 minutes before (e.g., 9:00 AM -> 8:30 AM)
    final alertTime = classStartTime.subtract(const Duration(minutes: 30));

    // Safety check: Don't schedule for a time that already passed
    if (alertTime.isBefore(DateTime.now())) return;

    final scheduledTime = tz.TZDateTime.from(alertTime, tz.local);

    await _plugin.zonedSchedule(
      id,
      'Class Starts Soon: $subjectName',
      'Attendance is low (${currentAttendance.toStringAsFixed(1)}%). Don\'t miss this class!',
      scheduledTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'class_reminders',
          'Class Reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // Repeats daily at this time
    );
  }

  static Future<void> cancel(int id) async {
    await _plugin.cancel(id);
  }
}