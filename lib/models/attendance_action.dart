import 'package:hive/hive.dart';

part 'attendance_action.g.dart';

@HiveType(typeId: 2)
class AttendanceAction extends HiveObject {
  @HiveField(0)
  final String subjectId;

  @HiveField(1)
  final DateTime date;

  @HiveField(2)
  final bool wasPresent;

  AttendanceAction({
    required this.subjectId,
    required this.date,
    required this.wasPresent,
  });
}
