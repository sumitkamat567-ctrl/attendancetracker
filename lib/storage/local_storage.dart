import 'package:hive_flutter/hive_flutter.dart';
import '../models/subject.dart';
import '../models/timetable_slot.dart';
import '../models/attendance_action.dart';

class LocalStorage {
  static const subjectBox = 'subjects';
  static const timetableBox = 'timetable';
  static const actionBox = 'actions';
  static const settingsBoxKey = 'settings';

  // We make this static so main.dart and onboarding can access it directly
  static late Box settingsBox;

  // ───────────────── SETTINGS KEYS ─────────────────
  static const String keyTargetAttendance = 'targetAttendance';
  static const String keyNotificationsEnabled = 'notificationsEnabled';
  static const String keyClassroomMode = 'classroomMode';
  static const String keyLowAttendanceAlerts = 'lowAttendanceAlerts';
  static const String keyAlarmPermissionRequested = 'alarmPermissionRequested';

  // ───────────────── GETTERS ─────────────────
  static double get targetAttendance =>
      settingsBox.get(keyTargetAttendance, defaultValue: 75.0);

  static bool get notificationsEnabled =>
      settingsBox.get(keyNotificationsEnabled, defaultValue: true);

  static bool get classroomMode =>
      settingsBox.get(keyClassroomMode, defaultValue: true);

  static bool get lowAttendanceAlerts =>
      settingsBox.get(keyLowAttendanceAlerts, defaultValue: true);

  static bool get alarmPermissionRequested =>
      settingsBox.get(keyAlarmPermissionRequested, defaultValue: false);

  // ───────────────── SETTERS ─────────────────
  static Future<void> setTargetAttendance(double value) async {
    await settingsBox.put(keyTargetAttendance, value);
  }

  static Future<void> setNotificationsEnabled(bool value) async {
    await settingsBox.put(keyNotificationsEnabled, value);
  }

  static Future<void> setClassroomMode(bool value) async {
    await settingsBox.put(keyClassroomMode, value);
  }

  static Future<void> setLowAttendanceAlerts(bool value) async {
    await settingsBox.put(keyLowAttendanceAlerts, value);
  }

  static Future<void> setAlarmPermissionRequested(bool value) async {
    await settingsBox.put(keyAlarmPermissionRequested, value);
  }

  static Future<void> init() async {
    await Hive.initFlutter();

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(SubjectAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(TimetableSlotAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(AttendanceActionAdapter());
    }

    await Hive.openBox<Subject>(subjectBox);
    await Hive.openBox<TimetableSlot>(timetableBox);
    await Hive.openBox<AttendanceAction>(actionBox);

    // Open and assign the settings box
    settingsBox = await Hive.openBox(settingsBoxKey);
  }
}
