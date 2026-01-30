import 'package:hive/hive.dart';
import '../models/timetable_slot.dart';
import '../models/subject.dart';
import 'attendance_engine.dart';

class TimetableEngine {
  final Box<TimetableSlot> _timetableBox = Hive.box('timetable');
  final Box<Subject> _subjectBox = Hive.box('subjects');

  final AttendanceEngine _attendanceEngine = AttendanceEngine();

  /// Add a class to timetable (auto-saved)
  void addSlot(TimetableSlot slot) {
    _timetableBox.add(slot);
  }

  /// Get today’s classes
  List<TimetableSlot> getTodaySlots() {
    final today = DateTime.now().weekday; // 1–7
    return _timetableBox.values
        .where((slot) => slot.weekday == today)
        .toList();
  }

  /// Called when a class ENDS
  void onClassEnded({
    required TimetableSlot slot,
    required bool? wasPresent,
  }) {
    if (wasPresent == null) {
      // Cancelled → do nothing
      return;
    }

    _attendanceEngine.markAttendance(
      subjectId: slot.subjectId,
      present: wasPresent,
    );
  }

  /// Helper: get subject name
  Subject? getSubject(String subjectId) {
    return _subjectBox.get(subjectId);
  }
}
