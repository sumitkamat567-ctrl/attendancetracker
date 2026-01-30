import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/timetable_slot.dart';
import '../models/subject.dart';
import 'add_course_page.dart';

class TimetablePage extends StatelessWidget {
  const TimetablePage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ValueListenableBuilder(
        valueListenable: Hive.box<TimetableSlot>('timetable').listenable(),
        builder: (context, Box<TimetableSlot> timetableBox, _) {
          if (timetableBox.isEmpty) {
            return _emptyState(context);
          }

          return _timetableList(context, timetableBox);
        },
      ),
    );
  }

  // ================= EMPTY STATE =================

  Widget _emptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "My Timetable",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const Spacer(),

          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.schedule, size: 90, color: Colors.green),
              SizedBox(height: 20),
              Text(
                "No timetable found",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                "Add courses to build your schedule",
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),

          const Spacer(),
          _addCourseButton(context),
        ],
      ),
    );
  }

  // ================= TIMETABLE LIST =================

  Widget _timetableList(BuildContext context, Box<TimetableSlot> timetableBox) {
    final subjectBox = Hive.box<Subject>('subjects');
    final slots = timetableBox.values.toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "My Timetable",
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

                return _dismissibleTile(
                  context,
                  slot,
                  subject?.name ?? "Unknown",
                );
              },
            ),
          ),

          _addCourseButton(context),
        ],
      ),
    );
  }

  // ================= DISMISSIBLE TILE =================

  Widget _dismissibleTile(
      BuildContext context,
      TimetableSlot slot,
      String subjectName,
      ) {
    return Dismissible(
      key: ValueKey(slot.key),
      direction: DismissDirection.endToStart,
      background: _deleteBackground(),
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) => _deleteSlot(slot),
      child: _courseTile(subjectName, slot),
    );
  }

  // ================= COURSE TILE =================

  Widget _courseTile(String name, TimetableSlot slot) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1B),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.book, color: Colors.green),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "${_weekdayName(slot.weekday)} • ${slot.startTime} - ${slot.endTime}",
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================= DELETE BACKGROUND =================

  Widget _deleteBackground() {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      decoration: BoxDecoration(
        color: Colors.red.shade700,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(
        Icons.delete,
        color: Colors.white,
        size: 28,
      ),
    );
  }

  // ================= CONFIRM DELETE =================

  Future<bool> _confirmDelete(BuildContext context) async {
    return await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: const Color(0xFF1B1B1B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Delete course?",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "This will remove the course from your timetable.",
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade800,
                      ),
                      onPressed: () => Navigator.pop(sheetContext, false),
                      child: const Text("Cancel"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      onPressed: () => Navigator.pop(sheetContext, true),
                      child: const Text("Delete"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    ) ??
        false;
  }


  // ================= DELETE LOGIC =================

  void _deleteSlot(TimetableSlot slot) {
    final subjectBox = Hive.box<Subject>('subjects');
    final timetableBox = Hive.box<TimetableSlot>('timetable');

    // delete subject only if no other slots use it
    final stillUsed = timetableBox.values.any(
          (s) => s.subjectId == slot.subjectId && s.key != slot.key,
    );

    if (!stillUsed) {
      subjectBox.delete(slot.subjectId);
    }

    slot.delete();
  }

  // ================= ADD COURSE BUTTON =================

  Widget _addCourseButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AddCoursePage(),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text("Add Course"),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          padding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  // ================= HELPERS =================

  static String _weekdayName(int day) {
    switch (day) {
      case 1:
        return "Monday";
      case 2:
        return "Tuesday";
      case 3:
        return "Wednesday";
      case 4:
        return "Thursday";
      case 5:
        return "Friday";
      case 6:
        return "Saturday";
      case 7:
        return "Sunday";
      default:
        return "";
    }
  }
}
