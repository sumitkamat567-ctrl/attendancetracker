class TimetableParser {
  static List<ParsedSlot> parse(String text) {
    final lines = text.split('\n');

    final List<ParsedSlot> slots = [];

    for (final line in lines) {
      // Example pattern (we’ll refine later)
      if (line.contains('Monday') && line.contains('09:00')) {
        slots.add(
          ParsedSlot(
            day: 1,
            subject: 'DSP',
            start: '09:00',
            end: '10:00',
          ),
        );
      }
    }

    return slots;
  }
}

class ParsedSlot {
  final int day;
  final String subject;
  final String start;
  final String end;

  ParsedSlot({
    required this.day,
    required this.subject,
    required this.start,
    required this.end,
  });
}
