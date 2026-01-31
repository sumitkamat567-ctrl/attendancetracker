import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  /* ───────────────── INIT ───────────────── */

  static Future<void> init() async {
    tz.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(initSettings);
  }

  /* ───────────────── CHANNELS ───────────────── */

  static const _criticalChannel = AndroidNotificationDetails(
    'attendance_critical',
    'Critical Attendance Alerts',
    channelDescription: 'Important alerts when attendance is at risk',
    importance: Importance.high,
    priority: Priority.high,
  );

  static const _gentleChannel = AndroidNotificationDetails(
    'attendance_gentle',
    'Attendance Reminders',
    channelDescription: 'Helpful reminders without being intrusive',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  static const _positiveChannel = AndroidNotificationDetails(
    'attendance_positive',
    'Attendance Progress',
    channelDescription: 'Positive feedback for improvement',
    importance: Importance.low,
    priority: Priority.low,
  );

  /* ───────────────── CORE ALERTS ───────────────── */

  /// 🔴 Critical warning — fires ONCE per drop
  static Future<void> showCriticalLowAttendance({
    required int id,
    required String subjectName,
    required double percent,
  }) async {
    await _plugin.show(
      id,
      'Attendance at Risk ⚠️',
      '$subjectName is at ${percent.toStringAsFixed(1)}%. '
          'You may not be eligible if this continues.',
      const NotificationDetails(android: _criticalChannel),
    );
  }

  /// 🟡 Gentle nudge — should be rate-limited by caller
  static Future<void> showGentleReminder({
    required int id,
    required String subjectName,
    required double percent,
  }) async {
    await _plugin.show(
      id,
      'Attendance Reminder',
      '$subjectName is currently at ${percent.toStringAsFixed(1)}%. '
          'Attending the next few classes can help.',
      const NotificationDetails(android: _gentleChannel),
    );
  }

  /// 🔵🟢 Positive reinforcement — fires ONCE on recovery
  static Future<void> showRecoveryPraise({
    required int id,
    required String subjectName,
    required double percent,
  }) async {
    await _plugin.show(
      id,
      'Nice work 👏',
      '$subjectName attendance is back to ${percent.toStringAsFixed(1)}%. '
          'You’re on track now.',
      const NotificationDetails(android: _positiveChannel),
    );
  }

  /* ───────────────── PRE-CLASS REMINDER ───────────────── */

  /// ⏰ Smart reminder before class (only when unsafe)
  static Future<void> schedulePreClassReminder({
    required int id,
    required String subjectName,
    required double percent,
    required DateTime classStartTime,
  }) async {
    if (percent >= 80) return;

    final reminderTime =
    classStartTime.subtract(const Duration(minutes: 30));

    if (reminderTime.isBefore(DateTime.now())) return;

    final tzTime = tz.TZDateTime.from(reminderTime, tz.local);

    await _plugin.zonedSchedule(
      id,
      'Upcoming Class: $subjectName',
      'Attendance is at ${percent.toStringAsFixed(1)}%. '
          'This class can help you recover.',
      tzTime,
      const NotificationDetails(android: _gentleChannel),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /* ───────────────── UTILS ───────────────── */

  static Future<void> cancel(int id) async {
    await _plugin.cancel(id);
  }

  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
