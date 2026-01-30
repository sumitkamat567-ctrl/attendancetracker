import 'package:hive/hive.dart';

part 'subject.g.dart';

@HiveType(typeId: 0)
class Subject extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  int totalClasses;

  @HiveField(3)
  int presentClasses;

  // ✅ NEW: low attendance warning flag
  @HiveField(4)
  bool warnedLowAttendance;

  Subject({
    required this.id,
    required this.name,
    this.totalClasses = 0,
    this.presentClasses = 0,
    this.warnedLowAttendance = false,
  });

  double get percentage {
    if (totalClasses == 0) return 0.0;
    return (presentClasses / totalClasses) * 100;
  }
}
