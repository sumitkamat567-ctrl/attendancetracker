import 'package:hive/hive.dart';
import '../models/subject.dart';
import '../models/attendance_action.dart';
import '../notifications/notification_service.dart';

class AttendanceEngine {
  final Box<Subject> _subjects = Hive.box<Subject>('subjects');
  final Box<AttendanceAction> _actions = Hive.box<AttendanceAction>('actions');

  void markAttendance({
    required String subjectId,
    required bool present,
    DateTime? date,
  }) {
    final subject = _subjects.get(subjectId);
    if (subject == null) return;

    final actionDate = date ?? DateTime.now();

    final alreadyMarked = _actions.values.any(
          (a) => a.subjectId == subjectId && _sameDay(a.date, actionDate),
    );

    if (alreadyMarked) return;

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

    // 🔔 CHECK LOW ATTENDANCE
    final percent = subject.percentage;
    // Notify if attendance drops below 75% immediately after marking
    if (percent > 0 && percent < 75) {
      NotificationService.showLowAttendance(
        id: subject.hashCode,
        subjectName: subject.name,
        percent: percent,
      );
    }
  }

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

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}