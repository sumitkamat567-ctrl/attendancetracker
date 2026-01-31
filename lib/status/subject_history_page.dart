
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

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
  late final PageController _pageController;
  late final DateTime _baseMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _baseMonth = DateTime(now.year, now.month);
    _pageController = PageController(initialPage: 1000);
  }

  DateTime _monthForIndex(int index) =>
      DateTime(_baseMonth.year, _baseMonth.month + (index - 1000));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: SafeArea(
        child: ValueListenableBuilder(
          valueListenable:
          Hive.box<AttendanceAction>('actions').listenable(),
          builder: (_, Box<AttendanceAction> box, __) {
            return PageView.builder(
              controller: _pageController,
              itemBuilder: (context, index) {
                final month = _monthForIndex(index);
                final actions = box.values
                    .where((a) =>
                a.subjectId == widget.subject.id &&
                    a.date.year == month.year &&
                    a.date.month == month.month)
                    .toList();

                return _MonthView(
                  subject: widget.subject,
                  month: month,
                  actions: actions,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/* ───────────────── MONTH VIEW ───────────────── */

class _MonthView extends StatelessWidget {
  final Subject subject;
  final DateTime month;
  final List<AttendanceAction> actions;

  const _MonthView({
    required this.subject,
    required this.month,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final present = actions.where((a) => a.wasPresent).length;
    final absent = actions.where((a) => !a.wasPresent).length;
    final total = actions.length;

    return Column(
      children: [
        _AnimatedHeader(month: month),
        const SizedBox(height: 16),
        const _WeekHeader(),
        const SizedBox(height: 12),
        _CalendarGrid(
          month: month,
          actions: actions,
          subject: subject,
        ),
        const Spacer(),
        _MetricsCard(
          present: present,
          absent: absent,
          total: total,
        ),
        const SizedBox(height: 12),
        const _CalendarNotes(),
        const SizedBox(height: 24),
      ],
    );
  }
}

/* ───────────────── HEADER ───────────────── */

class _AnimatedHeader extends StatelessWidget {
  final DateTime month;
  const _AnimatedHeader({required this.month});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final isCurrentMonth =
        today.year == month.year && today.month == month.month;

    final displayDay = isCurrentMonth ? today.day : 1;
    final weekday =
    ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    [DateTime(month.year, month.month, displayDay).weekday - 1];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: Text(
              displayDay.toString(),
              key: ValueKey(displayDay),
              style: GoogleFonts.bricolageGrotesque(
                fontSize: 88,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1,
              ),
            ),
          ),
          Row(
            children: [
              Text(
                "${_monthName(month.month).toUpperCase()} ${month.year}",
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 18,
                  letterSpacing: 1.2,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  weekday,
                  key: ValueKey(weekday),
                  style: GoogleFonts.bricolageGrotesque(
                    fontSize: 16,
                    color: Colors.white54,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/* ───────────────── WEEK HEADER ───────────────── */

class _WeekHeader extends StatelessWidget {
  const _WeekHeader();

  @override
  Widget build(BuildContext context) {
    const days = ["M", "T", "W", "T", "F", "S", "S"];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: days
            .map(
              (d) => Expanded(
            child: Center(
              child: Text(
                d,
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white38,
                ),
              ),
            ),
          ),
        )
            .toList(),
      ),
    );
  }
}

/* ───────────────── CALENDAR GRID ───────────────── */

class _CalendarGrid extends StatelessWidget {
  final DateTime month;
  final List<AttendanceAction> actions;
  final Subject subject;

  const _CalendarGrid({
    required this.month,
    required this.actions,
    required this.subject,
  });

  @override
  Widget build(BuildContext context) {
    final daysInMonth =
    DateUtils.getDaysInMonth(month.year, month.month);
    final firstWeekday =
        DateTime(month.year, month.month, 1).weekday;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: daysInMonth + firstWeekday - 1,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
        ),
        itemBuilder: (context, index) {
          if (index < firstWeekday - 1) return const SizedBox();

          final day = index - firstWeekday + 2;
          final date = DateTime(month.year, month.month, day);

          AttendanceAction? record;
          for (final a in actions) {
            if (a.date.day == day) {
              record = a;
              break;
            }
          }

          final isPresent = record?.wasPresent == true;
          final isAbsent = record?.wasPresent == false;

          final bgColor = isPresent
              ? Colors.white
              : isAbsent
              ? Colors.redAccent
              : Colors.white12;

          final textColor =
          isPresent ? Colors.black : Colors.white;

          return GestureDetector(
            onTap: () => _showEditDialog(context, date, record, subject),
            child: Container(
              alignment: Alignment.center,
              decoration:
              BoxDecoration(shape: BoxShape.circle, color: bgColor),
              child: Text(
                day.toString(),
                style: GoogleFonts.bricolageGrotesque(
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showEditDialog(
      BuildContext context,
      DateTime date,
      AttendanceAction? record,
      Subject subject,
      ) {
    showDialog(
      context: context,
      builder: (_) => _EditDialog(
        date: date,
        record: record,
        subject: subject,
      ),
    );
  }
}

/* ───────────────── METRICS CARD ───────────────── */

class _MetricsCard extends StatelessWidget {
  final int present;
  final int absent;
  final int total;

  const _MetricsCard({
    required this.present,
    required this.absent,
    required this.total,
  });

  double get percentage =>
      total == 0 ? 0 : (present / total) * 100;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _metric("Present", present.toString(), Colors.white),
          _metric("Absent", absent.toString(), Colors.redAccent),
          _metric(
            "Attendance",
            "${percentage.toStringAsFixed(1)}%",
            percentage >= 75 ? Colors.white : Colors.redAccent,
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value, Color color) {
    return Column(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: Text(
            value,
            key: ValueKey(value),
            style: GoogleFonts.bricolageGrotesque(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: GoogleFonts.bricolageGrotesque(
            fontSize: 12,
            color: Colors.white38,
          ),
        ),
      ],
    );
  }
}

/* ───────────────── NOTES / HINTS ───────────────── */

class _CalendarNotes extends StatelessWidget {
  const _CalendarNotes();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          Text(
            "White is used for presence to keep it neutral — attending is expected, not rewarded. "
                "Red highlights absence because missing classes has a stronger impact.",
            textAlign: TextAlign.center,
            style: GoogleFonts.bricolageGrotesque(
              fontSize: 12,
              color: Colors.white38,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Tip: Swipe left or right to change the month.",
            style: GoogleFonts.bricolageGrotesque(
              fontSize: 12,
              color: Colors.white24,
            ),
          ),
        ],
      ),
    );
  }
}

/* ───────────────── EDIT DIALOG ───────────────── */

class _EditDialog extends StatelessWidget {
  final DateTime date;
  final AttendanceAction? record;
  final Subject subject;

  const _EditDialog({
    required this.date,
    required this.record,
    required this.subject,
  });

  @override
  Widget build(BuildContext context) {
    final status = record == null
        ? "Not marked"
        : record!.wasPresent
        ? "Present"
        : "Absent";

    final statusColor = record == null
        ? Colors.white38
        : record!.wasPresent
        ? Colors.white
        : Colors.redAccent;

    return Dialog(
      backgroundColor: const Color(0xFF1C1C1C),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // DATE
            Text(
              date.day.toString(),
              style: GoogleFonts.bricolageGrotesque(
                fontSize: 52,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),

            // STATUS
            Text(
              status,
              style: GoogleFonts.bricolageGrotesque(
                fontSize: 14,
                color: statusColor,
              ),
            ),

            const SizedBox(height: 24),

            // PRESENT BUTTON
            _actionButton(
              context: context,
              label: "Mark Present",
              gradient: const LinearGradient(
                colors: [Colors.white, Color(0xFFEDEDED)],
              ),
              textColor: Colors.black,
              onTap: () {
                AttendanceEngine().markAttendance(
                  subjectId: subject.id,
                  present: true,
                  date: date,
                );
                Navigator.pop(context);
              },
            ),

            const SizedBox(height: 12),

            // ABSENT BUTTON
            _actionButton(
              context: context,
              label: "Mark Absent",
              gradient: const LinearGradient(
                colors: [Color(0xFFFF6A6A), Color(0xFFE84545)],
              ),
              textColor: Colors.white,
              onTap: () {
                AttendanceEngine().markAttendance(
                  subjectId: subject.id,
                  present: false,
                  date: date,
                );
                Navigator.pop(context);
              },
            ),

            if (record != null) ...[
              const SizedBox(height: 12),

              // CLEAR BUTTON (SECONDARY)
              _actionButton(
                context: context,
                label: "Clear Mark",
                gradient: const LinearGradient(
                  colors: [Color(0xFF2A2A2A), Color(0xFF1F1F1F)],
                ),
                textColor: Colors.white70,
                onTap: () {
                  AttendanceEngine().clearAttendanceForDate(
                    subjectId: subject.id,
                    date: date,
                  );
                  Navigator.pop(context);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required BuildContext context,
    required String label,
    required Gradient gradient,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
        ),
        child: TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: textColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.bricolageGrotesque(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/* ───────────────── HELPERS ───────────────── */

String _monthName(int m) => const [
  "January",
  "February",
  "March",
  "April",
  "May",
  "June",
  "July",
  "August",
  "September",
  "October",
  "November",
  "December"
][m - 1];
