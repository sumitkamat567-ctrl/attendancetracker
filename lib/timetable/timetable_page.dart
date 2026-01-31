import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../models/timetable_slot.dart';
import '../models/subject.dart';
import 'add_course_page.dart';
import 'timetable_image_preview_page.dart';

class TimetablePage extends StatefulWidget {
  const TimetablePage({super.key});

  @override
  State<TimetablePage> createState() => _TimetablePageState();
}

class _TimetablePageState extends State<TimetablePage> {
  final ImagePicker _picker = ImagePicker();

  // ================= IMAGE PICKER =================

  Future<void> _pickTimetableImage() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );

    if (image == null || !mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TimetableImagePreviewPage(
          imageFile: File(image.path),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ValueListenableBuilder(
        valueListenable: Hive.box<TimetableSlot>('timetable').listenable(),
        builder: (context, Box<TimetableSlot> timetableBox, _) {
          if (timetableBox.isEmpty) {
            return _emptyState();
          }
          return _timetableList(timetableBox);
        },
      ),
    );
  }

  // ================= EMPTY STATE =================

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          const Spacer(),

          Column(
            children: const [
              Icon(Icons.schedule, size: 90, color: Colors.green),
              SizedBox(height: 20),
              Text(
                "No timetable found",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                "Add courses or scan timetable image",
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),

          const Spacer(),
          _scanTimetableButton(),
          const SizedBox(height: 12),
          _addCourseButton(),
        ],
      ),
    );
  }

  // ================= TIMETABLE LIST =================

  Widget _timetableList(Box<TimetableSlot> timetableBox) {
    final subjectBox = Hive.box<Subject>('subjects');
    final slots = timetableBox.values.toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          const SizedBox(height: 20),

          Expanded(
            child: ListView.separated(
              itemCount: slots.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final slot = slots[index];
                final subject = subjectBox.get(slot.subjectId);

                return _dismissibleTile(
                  slot,
                  subject?.name ?? "Unknown",
                );
              },
            ),
          ),

          _scanTimetableButton(),
          const SizedBox(height: 12),
          _addCourseButton(),
        ],
      ),
    );
  }

  // ================= HEADER =================

  Widget _header() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          "My Timetable",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        IconButton(
          icon: const Icon(Icons.upload_file, color: Colors.green),
          tooltip: "Upload timetable image",
          onPressed: _pickTimetableImage,
        ),
      ],
    );
  }

  // ================= COURSE TILE =================

  Widget _dismissibleTile(TimetableSlot slot, String subjectName) {
    return Dismissible(
      key: ValueKey(slot.key),
      direction: DismissDirection.endToStart,
      background: _deleteBackground(),
      confirmDismiss: (_) => _confirmDelete(),
      onDismissed: (_) => _deleteSlot(slot),
      child: _courseTile(subjectName, slot),
    );
  }

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

  // ================= DELETE =================

  Widget _deleteBackground() {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      decoration: BoxDecoration(
        color: Colors.red.shade700,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(Icons.delete, color: Colors.white, size: 28),
    );
  }

  Future<bool> _confirmDelete() async {
    return await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: const Color(0xFF1B1B1B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Delete course?",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text("Cancel"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text("Delete"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    ) ?? false;
  }

  void _deleteSlot(TimetableSlot slot) {
    final subjectBox = Hive.box<Subject>('subjects');
    final timetableBox = Hive.box<TimetableSlot>('timetable');

    final stillUsed = timetableBox.values.any(
          (s) => s.subjectId == slot.subjectId && s.key != slot.key,
    );

    if (!stillUsed) {
      subjectBox.delete(slot.subjectId);
    }

    slot.delete();
  }

  // ================= BUTTONS =================

  Widget _addCourseButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddCoursePage()),
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

  Widget _scanTimetableButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _pickTimetableImage,
        icon: const Icon(Icons.camera_alt, color: Colors.green),
        label: const Text(
          "Scan Timetable Image",
          style: TextStyle(color: Colors.green),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.all(16),
          side: const BorderSide(color: Colors.green),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  // ================= HELPERS =================

  static String _weekdayName(int day) {
    const days = [
      "",
      "Monday",
      "Tuesday",
      "Wednesday",
      "Thursday",
      "Friday",
      "Saturday",
      "Sunday"
    ];
    return days[day];
  }
}
