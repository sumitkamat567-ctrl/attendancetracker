import 'package:hive_flutter/hive_flutter.dart';

import '../models/subject.dart';
import '../models/timetable_slot.dart';
import '../models/attendance_action.dart';

class LocalStorage {
  static const subjectBox = 'subjects';
  static const timetableBox = 'timetable';
  static const actionBox = 'actions';

  static Future<void> init() async {
    await Hive.initFlutter();

    // ✅ Register adapters safely (ONLY ONCE)
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(SubjectAdapter());
    }

    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(TimetableSlotAdapter());
    }

    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(AttendanceActionAdapter());
    }

    // ✅ Open boxes safely
    await Hive.openBox<Subject>(subjectBox);
    await Hive.openBox<TimetableSlot>(timetableBox);
    await Hive.openBox<AttendanceAction>(actionBox);
  }
}
