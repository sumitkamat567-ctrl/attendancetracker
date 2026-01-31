class DetectedClass {
  final int weekday; // 1 = Mon ... 5 = Fri
  final String startTime;
  final String endTime;
  final String subject;
  final double confidence;

  DetectedClass({
    required this.weekday,
    required this.startTime,
    required this.endTime,
    required this.subject,
    required this.confidence,
  });
}
