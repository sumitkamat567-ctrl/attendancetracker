import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/timetable_slot.dart';
import '../models/subject.dart';
// Ensure this path matches where you saved the history page file
import '../history/attendance_history_page.dart';

class StatusPage extends StatelessWidget {
  const StatusPage({super.key});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now().weekday;

    return SafeArea(
      child: ValueListenableBuilder(
        valueListenable: Hive.box<TimetableSlot>('timetable').listenable(),
        builder: (context, Box<TimetableSlot> box, _) {
          final todaySlots =
          box.values.where((s) => s.weekday == today).toList();

          if (todaySlots.isEmpty) {
            return _emptyToday(context);
          }

          return _todayList(context, todaySlots);
        },
      ),
    );
  }

  // ================= EMPTY =================

  Widget _emptyToday(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.event_available, size: 90, color: Colors.green),
          const SizedBox(height: 20),
          const Text(
            "No classes today",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            "Enjoy your free time 😌",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // ================= TODAY LIST =================

  Widget _todayList(BuildContext context, List<TimetableSlot> slots) {
    final subjectBox = Hive.box<Subject>('subjects');

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Today",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.separated(
              itemCount: slots.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final slot = slots[index];
                final subject = subjectBox.get(slot.subjectId);

                if (subject == null) return const SizedBox();

                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        // FIXED: Changed AttendanceHistoryPage to SubjectHistoryPage
                        builder: (_) => SubjectHistoryPage(subject: subject),
                      ),
                    );
                  },
                  child: _classTile(subject.name, slot),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _classTile(String name, TimetableSlot slot) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1B),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.class_, color: Colors.green),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                "${slot.startTime} - ${slot.endTime}",
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }
}