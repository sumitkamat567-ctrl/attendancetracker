import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/timetable_slot.dart';
import '../models/subject.dart';
import '../status/subject_history_page.dart';

class StatusPage extends StatelessWidget {
  const StatusPage({super.key});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now().weekday;

    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: SafeArea(
        child: ValueListenableBuilder(
          valueListenable: Hive.box<TimetableSlot>('timetable').listenable(),
          builder: (context, Box<TimetableSlot> timetableBox, _) {
            final todaySlots =
            timetableBox.values.where((s) => s.weekday == today).toList();

            if (todaySlots.isEmpty) {
              return _EmptyToday();
            }

            final subjectBox = Hive.box<Subject>('subjects');
            final todaySubjects = todaySlots
                .map((s) => subjectBox.get(s.subjectId))
                .whereType<Subject>()
                .toList();

            final lowestAttendance = todaySubjects.isEmpty
                ? 100.0
                : todaySubjects
                .map((s) => s.percentage)
                .reduce((a, b) => a < b ? a : b);

            final quote = _quoteForToday(
              lowestAttendance: lowestAttendance,
              totalClasses: todaySubjects.length,
            );

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(),
                  const SizedBox(height: 16),

                  // Quote
                  Text(
                    quote,
                    style: GoogleFonts.bricolageGrotesque(
                      fontSize: 18,
                      height: 1.4,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Metrics
                  _TodayMetrics(
                    total: todaySubjects.length,
                    lowestAttendance: lowestAttendance,
                  ),

                  const SizedBox(height: 24),

                  Text(
                    "Today's Classes",
                    style: GoogleFonts.bricolageGrotesque(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Expanded(
                    child: ListView.separated(
                      itemCount: todaySlots.length,
                      separatorBuilder: (_, __) =>
                      const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final slot = todaySlots[index];
                        final subject =
                        subjectBox.get(slot.subjectId);
                        if (subject == null) return const SizedBox();

                        return _ClassTile(
                          subject: subject,
                          slot: slot,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    SubjectHistoryPage(subject: subject),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /* ───────── QUOTE LOGIC ───────── */

  String _quoteForToday({
    required double lowestAttendance,
    required int totalClasses,
  }) {
    if (totalClasses == 0) {
      return "No classes today. Take the time to rest and reset.";
    }

    if (lowestAttendance < 60) {
      return "Today matters. Missing even one class now can push recovery further away.";
    }

    if (lowestAttendance < 75) {
      return "You’re close to the edge. Attending today keeps you in control.";
    }

    return "You’re doing well. Showing up today keeps your momentum strong.";
  }
}

/* ───────────────── HEADER ───────────────── */

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text(
      "Today",
      style: GoogleFonts.bricolageGrotesque(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    );
  }
}

/* ───────────────── EMPTY STATE ───────────────── */

class _EmptyToday extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.event_available,
              size: 80, color: Colors.white54),
          const SizedBox(height: 16),
          Text(
            "No classes today",
            style: GoogleFonts.bricolageGrotesque(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Use the day to recharge.",
            style: GoogleFonts.bricolageGrotesque(
              color: Colors.white38,
            ),
          ),
        ],
      ),
    );
  }
}

/* ───────────────── METRICS ───────────────── */

class _TodayMetrics extends StatelessWidget {
  final int total;
  final double lowestAttendance;

  const _TodayMetrics({
    required this.total,
    required this.lowestAttendance,
  });

  @override
  Widget build(BuildContext context) {
    final riskText = lowestAttendance < 75 ? "At Risk" : "Safe";

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _metric("Classes", total.toString()),
          _metric(
            "Lowest %",
            lowestAttendance.toStringAsFixed(1),
          ),
          _metric("Status", riskText),
        ],
      ),
    );
  }

  Widget _metric(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.bricolageGrotesque(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
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

/* ───────────────── CLASS TILE ───────────────── */

class _ClassTile extends StatelessWidget {
  final Subject subject;
  final TimetableSlot slot;
  final VoidCallback onTap;

  const _ClassTile({
    required this.subject,
    required this.slot,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isRisk = subject.percentage < 75;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1B1B1B),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Icon(
              Icons.class_,
              color: isRisk ? Colors.redAccent : Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subject.name,
                    style: GoogleFonts.bricolageGrotesque(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${slot.startTime} – ${slot.endTime}",
                    style: GoogleFonts.bricolageGrotesque(
                      color: Colors.white38,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              "${subject.percentage.toStringAsFixed(0)}%",
              style: GoogleFonts.bricolageGrotesque(
                fontWeight: FontWeight.w600,
                color: isRisk ? Colors.redAccent : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
