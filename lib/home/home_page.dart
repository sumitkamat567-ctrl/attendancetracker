import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/subject.dart';
import '../status/subject_history_page.dart';
import '../notifications/notification_service.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ValueListenableBuilder(
        valueListenable: Hive.box<Subject>('subjects').listenable(),
        builder: (context, Box<Subject> subjectBox, _) {
          final subjects = subjectBox.values.toList();

          // 🔔 CHECK & TRIGGER NOTIFICATIONS
          _checkLowAttendance(subjects);

          final overallPercent = _calculateOverall(subjects);

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Hello",
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 30),

                _overallCard(overallPercent),
                const SizedBox(height: 30),

                _coursesSection(context, subjects),
              ],
            ),
          );
        },
      ),
    );
  }

  // ================= NOTIFICATION LOGIC =================

  void _checkLowAttendance(List<Subject> subjects) {
    for (final subject in subjects) {
      if (subject.totalClasses == 0) continue;

      final percent = subject.percentage;

      // ⚠ BELOW 75% → NOTIFY ONCE
      if (percent < 75 && !subject.warnedLowAttendance) {
        NotificationService.showLowAttendance(
          id: subject.hashCode,
          subjectName: subject.name,
          percent: percent, // ✅ correct
        );


        subject.warnedLowAttendance = true;
        subject.save();
      }

      // ✅ ABOVE 75% → RESET WARNING
      if (percent >= 75 && subject.warnedLowAttendance) {
        subject.warnedLowAttendance = false;
        subject.save();
      }
    }
  }

  // ================= OVERALL CARD =================

  Widget _overallCard(double percent) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1B),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Overall Attendance",
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Text(
            "${percent.toStringAsFixed(1)}%",
            style: TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.bold,
              color: percent == 0
                  ? Colors.grey
                  : percent >= 75
                  ? Colors.green
                  : Colors.red,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            percent == 0
                ? "No attendance recorded yet"
                : "Keep tracking your classes",
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // ================= COURSES SECTION =================

  Widget _coursesSection(BuildContext context, List<Subject> subjects) {
    if (subjects.isEmpty) {
      return const Expanded(
        child: Center(
          child: Text(
            "No courses added",
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Your Courses",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                "${subjects.length} Total",
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Expanded(
            child: ListView.separated(
              itemCount: subjects.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final subject = subjects[index];

                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SubjectHistoryPage(subject: subject),
                      ),
                    );
                  },
                  child: _courseTile(subject),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ================= COURSE TILE =================

  Widget _courseTile(Subject subject) {
    final total = subject.totalClasses;
    final present = subject.presentClasses;
    final absent = total - present;
    final percent = total == 0 ? 0.0 : subject.percentage;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1B),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            subject.name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "$present / $total classes attended",
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 12),

          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : percent / 100,
              minHeight: 8,
              backgroundColor: Colors.grey.shade800,
              valueColor: AlwaysStoppedAnimation(
                percent >= 75
                    ? Colors.green
                    : percent == 0
                    ? Colors.grey
                    : Colors.red,
              ),
            ),
          ),

          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${percent.toStringAsFixed(1)}%",
                style: TextStyle(
                  color: percent >= 75
                      ? Colors.green
                      : percent == 0
                      ? Colors.grey
                      : Colors.red,
                ),
              ),
              Text(
                "$absent missed",
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ================= OVERALL CALC =================

  double _calculateOverall(List<Subject> subjects) {
    int total = 0;
    int present = 0;

    for (final s in subjects) {
      total += s.totalClasses;
      present += s.presentClasses;
    }

    if (total == 0) return 0.0;
    return (present / total) * 100;
  }
}
