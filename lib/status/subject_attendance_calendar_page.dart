import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/attendance_action.dart';

class SubjectAttendanceCalendarPage extends StatefulWidget {
  final String subjectId;
  final String subjectName;

  const SubjectAttendanceCalendarPage({
    super.key,
    required this.subjectId,
    required this.subjectName,
  });

  @override
  State<SubjectAttendanceCalendarPage> createState() =>
      _SubjectAttendanceCalendarPageState();
}

class _SubjectAttendanceCalendarPageState
    extends State<SubjectAttendanceCalendarPage> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.subjectName),
        centerTitle: true,
      ),
      body: ValueListenableBuilder(
        valueListenable: Hive.box<AttendanceAction>('actions').listenable(),
        builder: (context, Box<AttendanceAction> box, _) {
          final actions = box.values.where((a) =>
          a.subjectId == widget.subjectId &&
              a.date.year == _month.year &&
              a.date.month == _month.month).toList();

          return Column(
            children: [
              _monthSelector(),
              Expanded(child: _calendar(actions)),
            ],
          );
        },
      ),
    );
  }

  // ---------------- MONTH HEADER ----------------

  Widget _monthSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() {
                _month = DateTime(_month.year, _month.month - 1);
              });
            },
          ),
          Text(
            "${_month.month}/${_month.year}",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              setState(() {
                _month = DateTime(_month.year, _month.month + 1);
              });
            },
          ),
        ],
      ),
    );
  }

  // ---------------- CALENDAR ----------------

  Widget _calendar(List<AttendanceAction> actions) {
    final daysInMonth =
    DateUtils.getDaysInMonth(_month.year, _month.month);
    final firstWeekday =
        DateTime(_month.year, _month.month, 1).weekday;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        itemCount: daysInMonth + firstWeekday - 1,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        itemBuilder: (context, index) {
          if (index < firstWeekday - 1) {
            return const SizedBox();
          }

          final day = index - firstWeekday + 2;
          final date = DateTime(_month.year, _month.month, day);

          final record = actions.where((a) =>
          a.date.year == date.year &&
              a.date.month == date.month &&
              a.date.day == date.day);

          return _dayCell(date, record.isEmpty ? null : record.first);
        },
      ),
    );
  }

  // ---------------- DAY CELL ----------------

  Widget _dayCell(DateTime date, AttendanceAction? action) {
    Color color = Colors.grey.shade800;
    if (action != null) {
      color = action.wasPresent ? Colors.green : Colors.red;
    }

    return GestureDetector(
      onTap: () => _markForDate(date),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "${date.day}",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: action == null ? Colors.white : color,
              ),
            ),
            if (action != null)
              Text(
                action.wasPresent ? "P" : "A",
                style: TextStyle(
                  fontSize: 10,
                  color: color,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------------- MARK ATTENDANCE ----------------

  void _markForDate(DateTime date) {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("${date.day}/${date.month}/${date.year}",
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              _action("Present", Colors.green, true, date),
              _action("Absent", Colors.red, false, date),
              _action("Clear", Colors.grey, null, date),
            ],
          ),
        );
      },
    );
  }

  Widget _action(
      String text, Color color, bool? present, DateTime date) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: color),
        onPressed: () {
          final box = Hive.box<AttendanceAction>('actions');

          // remove old record for this date
          final old = box.values.firstWhere(
                (a) =>
            a.subjectId == widget.subjectId &&
                a.date.year == date.year &&
                a.date.month == date.month &&
                a.date.day == date.day,
            orElse: () => null as AttendanceAction,
          );

          if (old != null) old.delete();

          if (present != null) {
            box.add(
              AttendanceAction(
                subjectId: widget.subjectId,
                date: date,
                wasPresent: present,
              ),
            );
          }

          Navigator.pop(context);
        },
        child: Text(text),
      ),
    );
  }
}
