import 'dart:math';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static final _random = Random();

  /* ───────────────── FUN MESSAGE POOLS ───────────────── */

  // 🔴 Critical - when attendance is dangerously low
  static const _criticalTitles = [
    '🚨 SOS: Attendance Emergency',
    '😬 Houston, we have a problem',
    '⚠️ Red Alert!',
    '🆘 Attendance needs CPR',
    '📉 This ain\'t it chief',
  ];

  static const _criticalBodies = [
    '{subject} at {percent}% — you\'re in the danger zone fr fr',
    '{subject} dropped to {percent}%. Time to lock in bestie 🔒',
    'Your {subject} attendance ({percent}%) said "📉". Don\'t let it flop!',
    '{subject} is at {percent}% and that\'s lowkey concerning ngl',
    'Bro {subject} is at {percent}%... attendance arc when? 💀',
  ];

  // 🟡 Warning - attendance slipping
  static const _warningTitles = [
    '👀 Quick heads up',
    '📊 Attendance check',
    '🤔 Just a thought...',
    '💭 Friendly reminder',
    '📝 Note to self',
  ];

  static const _warningBodies = [
    '{subject} at {percent}% — not bad but could be better!',
    'Your {subject} attendance is giving "{percent}%" energy rn',
    '{subject} ({percent}%) needs a little love, maybe attend the next one?',
    'POV: {subject} is at {percent}% and wants you back 🥺',
    '{subject} attendance arc loading... currently at {percent}%',
  ];

  // 🟢 Recovery - when attendance improves
  static const _recoveryTitles = [
    '🎉 W moment!',
    '👑 Slay!',
    '✨ Glow up alert',
    '🔥 You\'re on fire!',
    '💪 Main character energy',
  ];

  static const _recoveryBodies = [
    '{subject} is back at {percent}%! That\'s the spirit ✨',
    'You brought {subject} back to {percent}%! Ate and left no crumbs 💅',
    '{subject} redemption arc complete — {percent}% and thriving!',
    'The {subject} comeback story we needed: {percent}%! 🏆',
    'From struggling to {percent}% in {subject}? Iconic behavior only 👏',
  ];

  // ⏰ Class reminder - urgent (below target)
  static const _urgentReminderTitles = [
    '🏃 {subject} in {mins} min!',
    '⏰ {mins} mins to {subject}!',
    '📚 {subject} calling in {mins}!',
    '🎯 {subject} — {mins} min heads up',
    '⚡ Quick! {subject} in {mins}',
  ];

  static const _urgentReminderBodies = [
    'At {percent}% rn — this class could be the plot twist 📈',
    'Currently {percent}%... every class counts, let\'s get this bread 🍞',
    '{percent}% attendance needs this class fr, don\'t ghost it 👻',
    'Your attendance ({percent}%) is asking you to show up today',
    'Skipping = 📉 Attending = 📈 Choose wisely bestie',
  ];

  // ⏰ Class reminder - chill (on track)
  static const _chillReminderTitles = [
    '📖 {subject} soon!',
    '🔔 {subject} in {mins}',
    '✨ {subject} starting',
    '📚 Time for {subject}',
    '🎓 {subject} awaits',
  ];

  static const _chillReminderBodies = [
    'You\'re at {percent}% — keep the streak going! 🔥',
    'Sitting pretty at {percent}%, let\'s maintain that energy ✨',
    '{percent}% and thriving! See you there? 👋',
    'Your {percent}% attendance is giving consistent king/queen vibes 👑',
    'Another day, another slay — {percent}% and counting!',
  ];

  // 🧪 Test notification
  static const _testTitles = [
    '✅ Notifications unlocked!',
    '🔔 We\'re connected!',
    '✨ All systems go!',
    '🎉 You\'re all set!',
  ];

  static const _testBodies = [
    'You\'ll get friendly reminders 10 & 3 mins before class. No spam, promise! 🤝',
    'Hazri will ping you before classes. We keep it minimal and useful 💯',
    'Class reminders activated! We\'ll only bug you when it matters ✨',
    'Your attendance guardian is ready! Expect helpful nudges, not chaos 😌',
  ];

  /* ───────────────── HELPER ───────────────── */

  static String _pick(List<String> options) =>
      options[_random.nextInt(options.length)];

  static String _format(String template,
      {String? subject, String? percent, String? mins}) {
    return template
        .replaceAll('{subject}', subject ?? '')
        .replaceAll('{percent}', percent ?? '')
        .replaceAll('{mins}', mins ?? '');
  }

  /* ───────────────── INIT ───────────────── */

  static Future<void> init() async {
    tz.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(initSettings);

    // Request notification permissions for Android 13+
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // Request exact alarm permission for scheduled notifications
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestExactAlarmsPermission();
  }

  /* ───────────────── CHANNELS ───────────────── */

  static const _criticalChannel = AndroidNotificationDetails(
    'attendance_critical',
    'Critical Attendance Alerts',
    channelDescription: 'Important alerts when attendance is at risk',
    importance: Importance.high,
    priority: Priority.high,
    icon: '@mipmap/ic_launcher',
  );

  static const _classReminderChannel = AndroidNotificationDetails(
    'class_reminder',
    'Class Reminders',
    channelDescription: 'Reminders before your classes start',
    importance: Importance.high,
    priority: Priority.high,
    icon: '@mipmap/ic_launcher',
  );

  static const _gentleChannel = AndroidNotificationDetails(
    'attendance_gentle',
    'Attendance Reminders',
    channelDescription: 'Helpful reminders without being intrusive',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
    icon: '@mipmap/ic_launcher',
  );

  static const _positiveChannel = AndroidNotificationDetails(
    'attendance_positive',
    'Attendance Progress',
    channelDescription: 'Positive feedback for improvement',
    importance: Importance.low,
    priority: Priority.low,
    icon: '@mipmap/ic_launcher',
  );

  /* ───────────────── CORE ALERTS ───────────────── */

  /// 🔴 Critical warning — fires ONCE per drop
  static Future<void> showCriticalLowAttendance({
    required int id,
    required String subjectName,
    required double percent,
  }) async {
    final percentStr = percent.toStringAsFixed(0);
    await _plugin.show(
      id,
      _pick(_criticalTitles),
      _format(_pick(_criticalBodies),
          subject: subjectName, percent: percentStr),
      const NotificationDetails(android: _criticalChannel),
    );
  }

  /// 🟡 Gentle nudge — should be rate-limited by caller
  static Future<void> showGentleReminder({
    required int id,
    required String subjectName,
    required double percent,
  }) async {
    final percentStr = percent.toStringAsFixed(0);
    await _plugin.show(
      id,
      _pick(_warningTitles),
      _format(_pick(_warningBodies), subject: subjectName, percent: percentStr),
      const NotificationDetails(android: _gentleChannel),
    );
  }

  /// 🔵🟢 Positive reinforcement — fires ONCE on recovery
  static Future<void> showRecoveryPraise({
    required int id,
    required String subjectName,
    required double percent,
  }) async {
    final percentStr = percent.toStringAsFixed(0);
    await _plugin.show(
      id,
      _pick(_recoveryTitles),
      _format(_pick(_recoveryBodies),
          subject: subjectName, percent: percentStr),
      const NotificationDetails(android: _positiveChannel),
    );
  }

  /* ───────────────── PRE-CLASS REMINDERS (3 & 10 MIN) ───────────────── */

  /// ⏰ Schedule reminder before class
  static Future<void> scheduleClassReminder({
    required int id,
    required String subjectName,
    required double percent,
    required DateTime classStartTime,
    required int minutesBefore,
    required double targetAttendance,
  }) async {
    final reminderTime =
        classStartTime.subtract(Duration(minutes: minutesBefore));

    if (reminderTime.isBefore(DateTime.now())) return;

    final tzTime = tz.TZDateTime.from(reminderTime, tz.local);

    // Customize message based on attendance status
    String title;
    String body;
    final percentStr = percent.toStringAsFixed(0);
    final minsStr = minutesBefore.toString();

    if (percent < targetAttendance) {
      // Below target - urgent but fun tone
      title = _format(_pick(_urgentReminderTitles),
          subject: subjectName, mins: minsStr);
      body = _format(_pick(_urgentReminderBodies), percent: percentStr);
    } else {
      // On track - chill reminder
      title = _format(_pick(_chillReminderTitles),
          subject: subjectName, mins: minsStr);
      body = _format(_pick(_chillReminderBodies), percent: percentStr);
    }

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzTime,
      NotificationDetails(
        android: percent < targetAttendance
            ? _criticalChannel
            : _classReminderChannel,
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// 🔔 Show immediate test notification
  static Future<void> showTestNotification() async {
    await _plugin.show(
      9999,
      _pick(_testTitles),
      _pick(_testBodies),
      const NotificationDetails(android: _classReminderChannel),
    );
  }

  /* ───────────────── UTILS ───────────────── */

  static Future<void> cancel(int id) async {
    await _plugin.cancel(id);
  }

  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  /// Get pending notifications count
  static Future<int> getPendingCount() async {
    final pending = await _plugin.pendingNotificationRequests();
    return pending.length;
  }
}
