import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/subject.dart';
import '../models/timetable_slot.dart';
import '../storage/timetable_engine.dart';

class AddCoursePage extends StatefulWidget {
  final TimetableSlot? existingSlot;
  const AddCoursePage({super.key, this.existingSlot});

  @override
  State<AddCoursePage> createState() => _AddCoursePageState();
}

class _AddCoursePageState extends State<AddCoursePage> {
  final TextEditingController _nameController = TextEditingController();

  int _weekday = DateTime.monday;
  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 10, minute: 0);

  @override
  void initState() {
    super.initState();
    if (widget.existingSlot != null) {
      final slot = widget.existingSlot!;
      final subject = Hive.box<Subject>('subjects').get(slot.subjectId);
      _nameController.text = subject?.name ?? "";
      _weekday = slot.weekday;
      _start = _parseTime(slot.startTime);
      _end = _parseTime(slot.endTime);
    }
  }

  TimeOfDay _parseTime(String t) {
    try {
      final parts = t.split(':');
      final h = int.parse(parts[0]);
      final m = int.parse(parts[1].split(' ')[0]);
      return TimeOfDay(hour: h, minute: m);
    } catch (e) {
      return const TimeOfDay(hour: 9, minute: 0);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.existingSlot != null;
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(isEditing: isEditing),
              const SizedBox(height: 28),

              _SectionLabel("Course name"),
              const SizedBox(height: 8),
              _CourseNameField(controller: _nameController),

              const SizedBox(height: 28),

              _SectionLabel("Day"),
              const SizedBox(height: 12),
              _WeekdaySelector(
                value: _weekday,
                onChanged: (v) => setState(() => _weekday = v),
              ),

              const SizedBox(height: 28),

              _SectionLabel("Time"),
              const SizedBox(height: 12),
              _TimeRow(
                label: "Start",
                time: _start,
                onPick: (t) => setState(() => _start = t),
              ),
              const SizedBox(height: 10),
              _TimeRow(
                label: "End",
                time: _end,
                onPick: (t) => setState(() => _end = t),
              ),

              const Spacer(),

              _SaveButton(
                onPressed: _saveCourse,
                label: isEditing ? "Update course" : "Save course",
              ),
            ],
          ),
        ),
      ),
    );
  }

  /* ───────────────── SAVE ───────────────── */

  void _saveCourse() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final subjectBox = Hive.box<Subject>('subjects');

    if (widget.existingSlot != null) {
      // Update
      final slot = widget.existingSlot!;
      final subject = subjectBox.get(slot.subjectId);
      if (subject != null) {
        subject.name = name;
        subject.save();
      }
      slot.weekday = _weekday;
      slot.startTime = _start.format(context);
      slot.endTime = _end.format(context);
      slot.save();
    } else {
      // Create
      final subjectId = DateTime.now().millisecondsSinceEpoch.toString();
      subjectBox.put(
        subjectId,
        Subject(id: subjectId, name: name),
      );

      TimetableEngine().addSlot(
        TimetableSlot(
          subjectId: subjectId,
          weekday: _weekday,
          startTime: _start.format(context),
          endTime: _end.format(context),
        ),
      );
    }

    Navigator.pop(context);
  }
}

/* ───────────────── UI COMPONENTS ───────────────── */

class _Header extends StatelessWidget {
  final bool isEditing;
  const _Header({required this.isEditing});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              padding: EdgeInsets.zero,
              alignment: Alignment.centerLeft,
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
            ),
            Text(
              isEditing ? "Edit course" : "Add course",
              style: GoogleFonts.bricolageGrotesque(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          isEditing ? "Update your class timing" : "Set up when and what you attend",
          style: GoogleFonts.bricolageGrotesque(
            fontSize: 14,
            color: Colors.white38,
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.bricolageGrotesque(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.white54,
      ),
    );
  }
}

class _CourseNameField extends StatelessWidget {
  final TextEditingController controller;
  const _CourseNameField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textCapitalization: TextCapitalization.words,
      style: GoogleFonts.bricolageGrotesque(
        color: Colors.white,
        fontSize: 16,
      ),
      decoration: InputDecoration(
        hintText: "e.g. Mathematics",
        hintStyle: GoogleFonts.bricolageGrotesque(
          color: Colors.white24,
        ),
        filled: true,
        fillColor: const Color(0xFF1C1C1C),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

/* ───────────────── WEEKDAY SELECTOR ───────────────── */

class _WeekdaySelector extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _WeekdaySelector({
    required this.value,
    required this.onChanged,
  });

  static const days = [
    "Mon",
    "Tue",
    "Wed",
    "Thu",
    "Fri",
    "Sat",
    "Sun"
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: List.generate(7, (i) {
          final dayValue = i + 1;
          final selected = dayValue == value;

          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(dayValue),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    days[i],
                    style: GoogleFonts.bricolageGrotesque(
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? Colors.black
                          : Colors.white54,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/* ───────────────── TIME ROW ───────────────── */

class _TimeRow extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final ValueChanged<TimeOfDay> onPick;

  const _TimeRow({
    required this.label,
    required this.time,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: time,
        );
        if (picked != null) onPick(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1C),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: GoogleFonts.bricolageGrotesque(
                color: Colors.white54,
              ),
            ),
            const Spacer(),
            Text(
              time.format(context),
              style: GoogleFonts.bricolageGrotesque(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ───────────────── SAVE BUTTON ───────────────── */

class _SaveButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;
  const _SaveButton({required this.onPressed, required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
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
    );
  }
}
