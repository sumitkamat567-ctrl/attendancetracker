import 'package:hive/hive.dart';

import '../models/subject.dart';
import '../models/attendance_action.dart';
import '../notifications/notification_service.dart';
import 'local_storage.dart';

class AttendanceEngine {
  final Box<Subject> _subjects = Hive.box<Subject>('subjects');
  final Box<AttendanceAction> _actions = Hive.box<AttendanceAction>('actions');

  /* ───────────────── MARK / REPLACE ATTENDANCE ───────────────── */

  void markAttendance({
    required String subjectId,
    required bool present,
    DateTime? date,
  }) {
    final subject = _subjects.get(subjectId);
    if (subject == null) return;

    final actionDate = date ?? DateTime.now();

    AttendanceAction? existing;
    for (final a in _actions.values) {
      if (a.subjectId == subjectId && _sameDay(a.date, actionDate)) {
        existing = a;
        break;
      }
    }

    final prevPercent = subject.percentage;

    // Remove existing record (replace logic)
    if (existing != null) {
      _actions.delete(existing.key);

      subject.totalClasses = (subject.totalClasses - 1).clamp(0, 9999);

      if (existing.wasPresent) {
        subject.presentClasses = (subject.presentClasses - 1).clamp(0, 9999);
      }
    }

    // Apply new attendance
    subject.totalClasses += 1;
    if (present) subject.presentClasses += 1;
    subject.save();

    _actions.add(
      AttendanceAction(
        subjectId: subjectId,
        date: actionDate,
        wasPresent: present,
      ),
    );

    final newPercent = subject.percentage;

    _handleNotifications(
      subject: subject,
      prevPercent: prevPercent,
      newPercent: newPercent,
    );
  }

  /* ───────────────── CLEAR SPECIFIC DATE ───────────────── */

  void clearAttendanceForDate({
    required String subjectId,
    required DateTime date,
  }) {
    AttendanceAction? target;

    for (final a in _actions.values) {
      if (a.subjectId == subjectId && _sameDay(a.date, date)) {
        target = a;
        break;
      }
    }

    if (target == null) return;

    final subject = _subjects.get(subjectId);
    if (subject == null) return;

    // Reverse counts
    subject.totalClasses = (subject.totalClasses - 1).clamp(0, 9999);

    if (target.wasPresent) {
      subject.presentClasses = (subject.presentClasses - 1).clamp(0, 9999);
    }

    subject.save();
    _actions.delete(target.key);
  }

  /* ───────────────── GLOBAL UNDO (LAST ACTION) ───────────────── */

  void undoLastAction() {
    if (_actions.isEmpty) return;

    final last = _actions.getAt(_actions.length - 1);
    if (last == null) return;

    final subject = _subjects.get(last.subjectId);
    if (subject == null) return;

    subject.totalClasses = (subject.totalClasses - 1).clamp(0, 9999);

    if (last.wasPresent) {
      subject.presentClasses = (subject.presentClasses - 1).clamp(0, 9999);
    }

    subject.save();
    _actions.deleteAt(_actions.length - 1);
  }

  /* ───────────────── NOTIFICATIONS ───────────────── */

  void _handleNotifications({
    required Subject subject,
    required double prevPercent,
    required double newPercent,
  }) {
    // Skip if low attendance alerts are disabled
    if (!LocalStorage.lowAttendanceAlerts) return;

    final target = LocalStorage.targetAttendance;
    final criticalThreshold = target - 15; // 15% below target is critical

    // 🔴 Critical zone (target - 15%)
    if (newPercent < criticalThreshold && prevPercent >= criticalThreshold) {
      NotificationService.showCriticalLowAttendance(
        id: subject.hashCode,
        subjectName: subject.name,
        percent: newPercent,
      );
      subject.warnedLowAttendance = true;
      subject.save();
      return;
    }

    // 🟡 Warning zone (below target but not critical)
    if (newPercent >= criticalThreshold &&
        newPercent < target &&
        prevPercent >= target) {
      NotificationService.showGentleReminder(
        id: subject.hashCode,
        subjectName: subject.name,
        percent: newPercent,
      );
      subject.warnedLowAttendance = true;
      subject.save();
      return;
    }

    // 🟢 Recovery (back above target)
    if (newPercent >= target && prevPercent < target) {
      NotificationService.showRecoveryPraise(
        id: subject.hashCode + 999,
        subjectName: subject.name,
        percent: newPercent,
      );
      subject.warnedLowAttendance = false;
      subject.save();
    }
  }

  /* ───────────────── HELPERS ───────────────── */

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
