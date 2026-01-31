import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/timetable_slot.dart';
import '../models/subject.dart';
import 'add_course_page.dart';
import 'timetable_actions_page.dart';
import 'timetable_image_preview_page.dart';

class TimetablePage extends StatefulWidget {
  const TimetablePage({super.key});

  @override
  State<TimetablePage> createState() => _TimetablePageState();
}

class _TimetablePageState extends State<TimetablePage> {
  final ImagePicker _picker = ImagePicker();

  /* ───────────────── IMAGE PICKER ───────────────── */

  Future<void> _pickTimetableImage() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );

    if (image == null || !mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            TimetableImagePreviewPage(imageFile: File(image.path)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: SafeArea(
        child: ValueListenableBuilder(
          valueListenable:
          Hive.box<TimetableSlot>('timetable').listenable(),
          builder: (context, Box<TimetableSlot> timetableBox, _) {
            if (timetableBox.isEmpty) {
              return _EmptyState(onScan: _pickTimetableImage);
            }
            return _TimetableList(
              timetableBox: timetableBox,
              onScan: _pickTimetableImage,
            );
          },
        ),
      ),
    );
  }
}

/* ───────────────── HEADER ───────────────── */

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Timetable",
              style: GoogleFonts.bricolageGrotesque(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              "Your weekly class schedule",
              style: GoogleFonts.bricolageGrotesque(
                fontSize: 13,
                color: Colors.white38,
              ),
            ),
          ],
        ),
        const Spacer(),
        IconButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TimetableActionsPage()),
            );
          },
          icon: const Icon(Icons.auto_awesome),
          color: Colors.white,
          tooltip: "Manage classes",
        ),
      ],
    );
  }
}

/* ───────────────── EMPTY STATE ───────────────── */

class _EmptyState extends StatelessWidget {
  final VoidCallback onScan;

  const _EmptyState({required this.onScan});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const _Header(),
          const Spacer(),
          Icon(
            Icons.auto_awesome,
            size: 84,
            color: Colors.white24,
          ),
          const SizedBox(height: 20),
          Text(
            "No timetable added yet",
            style: GoogleFonts.bricolageGrotesque(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Add courses manually or scan your timetable.",
            textAlign: TextAlign.center,
            style: GoogleFonts.bricolageGrotesque(
              color: Colors.white38,
            ),
          ),
          const Spacer(),
          _ScanButton(onScan: onScan),
          const SizedBox(height: 12),
          const _AddCourseButton(),
        ],
      ),
    );
  }
}

/* ───────────────── TIMETABLE LIST ───────────────── */

class _TimetableList extends StatelessWidget {
  final Box<TimetableSlot> timetableBox;
  final VoidCallback onScan;

  const _TimetableList({
    required this.timetableBox,
    required this.onScan,
  });

  @override
  Widget build(BuildContext context) {
    final subjectBox = Hive.box<Subject>('subjects');
    final slots = timetableBox.values.toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        children: [
          const _Header(),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 20),
              children: [
                const _SwipeHint(),
                const SizedBox(height: 16),
                ...List.generate(slots.length, (index) {
                  final slot = slots[index];
                  final subject = subjectBox.get(slot.subjectId);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _DismissibleTile(
                      slot: slot,
                      subjectName: subject?.name ?? "Unknown",
                    ),
                  );
                }),
              ],
            ),
          ),
          Row(
            children: [
              Expanded(child: _ScanButton(onScan: onScan)),
              const SizedBox(width: 12),
              _ClearButton(onClear: () => _confirmClear(context)),
            ],
          ),
          const SizedBox(height: 12),
          const _AddCourseButton(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _confirmClear(BuildContext context) async {
    final clear = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: const Color(0xFF1C1C1C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _ClearSheet(),
    );

    if (clear == true) {
      Hive.box<TimetableSlot>('timetable').clear();
      // Also clean up subjects that are no longer used by any slots
      // (This is handled by the slot delete logic usually, but for a global clear we can just clear it if user wants or just keep it)
    }
  }
}

class _ClearButton extends StatelessWidget {
  final VoidCallback onClear;
  const _ClearButton({required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFF6B6B).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFF6B6B).withValues(alpha: 0.2)),
      ),
      child: IconButton(
        onPressed: onClear,
        icon: const Icon(Icons.delete_sweep_outlined, color: Color(0xFFFF6B6B)),
        tooltip: "Clear all classes",
      ),
    );
  }
}

class _ClearSheet extends StatelessWidget {
  const _ClearSheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Clear all classes?",
            style: GoogleFonts.bricolageGrotesque(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "This will permanently delete your entire timetable.",
            style: GoogleFonts.bricolageGrotesque(
              color: Colors.white38,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text("Cancel"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B6B),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text("Clear All"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/* ───────────────── COURSE TILE ───────────────── */

class _DismissibleTile extends StatelessWidget {
  final TimetableSlot slot;
  final String subjectName;

  const _DismissibleTile({
    required this.slot,
    required this.subjectName,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(slot.key),
      direction: DismissDirection.horizontal,
      background: _EditBackground(),
      secondaryBackground: _DeleteBackground(),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Edit
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddCoursePage(existingSlot: slot),
            ),
          );
          return false; // Don't dismiss
        } else {
          // Delete
          return await _confirmDelete(context);
        }
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          _deleteSlot(slot);
        }
      },
      child: _CourseTile(slot: slot, name: subjectName),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    return await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: const Color(0xFF1C1C1C),
      shape: const RoundedRectangleBorder(
        borderRadius:
        BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _DeleteSheet(),
    ) ??
        false;
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
}

class _CourseTile extends StatelessWidget {
  final TimetableSlot slot;
  final String name;

  const _CourseTile({required this.slot, required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1B),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white38,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.bricolageGrotesque(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "${_weekdayName(slot.weekday)} • ${slot.startTime} – ${slot.endTime}",
                  style: GoogleFonts.bricolageGrotesque(
                    fontSize: 13,
                    color: Colors.white38,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* ───────────────── DELETE UI ───────────────── */

class _DeleteBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 24),
      decoration: BoxDecoration(
        color: const Color(0xFFFF6B6B),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Icon(Icons.delete_outline, color: Colors.white),
    );
  }
}

class _EditBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.only(left: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF4ECDC4),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Icon(Icons.edit_outlined, color: Colors.white),
    );
  }
}

class _DeleteSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Remove course?",
            style: GoogleFonts.bricolageGrotesque(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "This will remove the course from your timetable.",
            style: GoogleFonts.bricolageGrotesque(
              color: Colors.white38,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () =>
                      Navigator.pop(context, false),
                  child: const Text("Cancel"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                  ),
                  onPressed: () =>
                      Navigator.pop(context, true),
                  child: const Text("Remove"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/* ───────────────── BUTTONS ───────────────── */

class _ScanButton extends StatelessWidget {
  final VoidCallback onScan;
  const _ScanButton({required this.onScan});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onScan,
        icon: const Icon(Icons.camera_alt),
        label: const Text("Scan Timetable Image"),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white38),
          padding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class _AddCourseButton extends StatelessWidget {
  const _AddCourseButton();

  @override
  Widget build(BuildContext context) {
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
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class _SwipeHint extends StatelessWidget {
  const _SwipeHint();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.swipe, size: 14, color: Colors.white12),
        const SizedBox(width: 8),
        Text(
          "Swipe right to edit • Left to delete",
          style: GoogleFonts.bricolageGrotesque(
            fontSize: 11,
            color: Colors.white12,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

/* ───────────────── HELPERS ───────────────── */

String _weekdayName(int day) {
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
