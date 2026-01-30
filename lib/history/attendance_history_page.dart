import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/subject.dart';
import '../models/attendance_action.dart';
import '../storage/attendance_engine.dart';

class SubjectHistoryPage extends StatefulWidget {
  final Subject subject;

  const SubjectHistoryPage({super.key, required this.subject});

  @override
  State<SubjectHistoryPage> createState() => _SubjectHistoryPageState();
}

class _SubjectHistoryPageState extends State<SubjectHistoryPage> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    _month = DateTime(DateTime.now().year, DateTime.now().month);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.subject.name),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ValueListenableBuilder(
          valueListenable: Hive.box<AttendanceAction>('actions').listenable(),
          builder: (context, Box<AttendanceAction> box, _) {
            final actions = _subjectMonthActions(box.values.toList());

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _monthSelector(),
                  const SizedBox(height: 16),
                  _calendar(actions),
                  const SizedBox(height: 20),
                  _summary(actions),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _monthSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
        ),
        Text(
          "${_monthName(_month.month)} ${_month.year}",
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
        ),
      ],
    );
  }

  Widget _calendar(List<AttendanceAction> actions) {
    final daysInMonth = DateUtils.getDaysInMonth(_month.year, _month.month);
    final firstWeekday = DateTime(_month.year, _month.month, 1).weekday;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1B),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          _weekHeader(),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: daysInMonth + (firstWeekday - 1),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
            ),
            itemBuilder: (context, index) {
              if (index < firstWeekday - 1) return const SizedBox();

              final day = index - firstWeekday + 2;
              final date = DateTime(_month.year, _month.month, day);
              final dayActions = actions.where((a) => _sameDay(a.date, date)).toList();

              return InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _openMarkSheet(context, date),
                child: _dayCell(day, dayActions),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _dayCell(int day, List<AttendanceAction> actions) {
    final hasRecord = actions.isNotEmpty;
    final isPresent = hasRecord && actions.first.wasPresent;
    final color = hasRecord ? (isPresent ? Colors.green : Colors.red) : Colors.grey;

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: hasRecord ? color.withOpacity(0.15) : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            day.toString(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: hasRecord ? color : Colors.white,
            ),
          ),
        ),
        if (hasRecord)
          Positioned(
            bottom: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Text(
                isPresent ? "P" : "A",
                style: const TextStyle(fontSize: 6, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }

  // ... (Rest of your original SubjectHistoryPage methods: _weekHeader, _openMarkSheet, _sheetButton, _summary, _stat, _subjectMonthActions, _sameDay, _monthName)
  // [Make sure to keep the helper methods exactly as they were in your previous file]

  Widget _weekHeader() {
    const labels = ["M", "T", "W", "T", "F", "S", "S"];
    return Row(
      children: labels.map((l) => Expanded(child: Center(child: Text(l, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600))))).toList(),
    );
  }

  void _openMarkSheet(BuildContext context, DateTime date) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1B1B1B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Mark attendance for ${date.day}/${date.month}/${date.year}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _sheetButton("Present", Colors.green, true, date),
            const SizedBox(height: 10),
            _sheetButton("Absent", Colors.red, false, date),
            const SizedBox(height: 10),
            _sheetButton("Cancel", Colors.grey, null, date),
          ],
        ),
      ),
    );
  }

  Widget _sheetButton(String text, Color color, bool? present, DateTime date) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: present == null ? () => Navigator.pop(context) : () {
          AttendanceEngine().markAttendance(subjectId: widget.subject.id, present: present, date: date);
          Navigator.pop(context);
        },
        style: ElevatedButton.styleFrom(backgroundColor: color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        child: Text(text, style: const TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _summary(List<AttendanceAction> actions) {
    final present = actions.where((a) => a.wasPresent).length;
    final absent = actions.where((a) => !a.wasPresent).length;
    final total = actions.length;
    final percent = total == 0 ? 0.0 : (present / total) * 100;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(color: const Color(0xFF1B1B1B), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _stat("Present", present, Colors.green),
          _stat("Absent", absent, Colors.red),
          _stat("Attendance", "${percent.toStringAsFixed(1)}%", percent >= 75 ? Colors.green : Colors.red),
        ],
      ),
    );
  }

  Widget _stat(String label, Object value, Color color) {
    return Column(children: [
      Text(value.toString(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
    ]);
  }

  List<AttendanceAction> _subjectMonthActions(List<AttendanceAction> all) {
    return all.where((a) => a.subjectId == widget.subject.id && a.date.year == _month.year && a.date.month == _month.month).toList();
  }

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  String _monthName(int m) => ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"][m - 1];
}