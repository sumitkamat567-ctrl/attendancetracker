import 'package:hive/hive.dart';

part 'timetable_slot.g.dart';

@HiveType(typeId: 1)
class TimetableSlot extends HiveObject {
  @HiveField(0)
  String subjectId;

  @HiveField(1)
  int weekday; // 1 = Monday, 7 = Sunday

  @HiveField(2)
  String startTime;

  @HiveField(3)
  String endTime;

  TimetableSlot({
    required this.subjectId,
    required this.weekday,
    required this.startTime,
    required this.endTime,
  });
}
