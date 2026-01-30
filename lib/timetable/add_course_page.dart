import 'package:flutter/material.dart';

import 'package:hive/hive.dart';

import '../models/subject.dart';
import '../models/timetable_slot.dart';
import '../storage/timetable_engine.dart';

class AddCoursePage extends StatefulWidget {
  const AddCoursePage({super.key});

  @override
  State<AddCoursePage> createState() => _AddCoursePageState();
}

class _AddCoursePageState extends State<AddCoursePage> {
  final TextEditingController _nameController = TextEditingController();

  int _weekday = DateTime.monday;
  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 10, minute: 0);

  @override
  void dispose() {
    _nameController.dispose(); // ✅ prevent memory leak
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Course"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _courseNameField(),
            const SizedBox(height: 20),

            _weekdayPicker(),
            const SizedBox(height: 20),

            _timePicker("Start Time", _start, (t) {
              setState(() => _start = t);
            }),
            _timePicker("End Time", _end, (t) {
              setState(() => _end = t);
            }),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveCourse,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text("Save Course"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- UI helpers ----------

  Widget _courseNameField() {
    return TextField(
      controller: _nameController,
      textCapitalization: TextCapitalization.words,
      decoration: const InputDecoration(
        labelText: "Course Name",
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _weekdayPicker() {
    return DropdownButtonFormField<int>(
      value: _weekday,
      decoration: const InputDecoration(
        labelText: "Day",
        border: OutlineInputBorder(),
      ),
      items: const [
        DropdownMenuItem(value: 1, child: Text("Monday")),
        DropdownMenuItem(value: 2, child: Text("Tuesday")),
        DropdownMenuItem(value: 3, child: Text("Wednesday")),
        DropdownMenuItem(value: 4, child: Text("Thursday")),
        DropdownMenuItem(value: 5, child: Text("Friday")),
        DropdownMenuItem(value: 6, child: Text("Saturday")),
        DropdownMenuItem(value: 7, child: Text("Sunday")),
      ],
      onChanged: (value) {
        if (value != null) {
          setState(() => _weekday = value);
        }
      },
    );
  }

  Widget _timePicker(
      String label,
      TimeOfDay time,
      ValueChanged<TimeOfDay> onPick,
      ) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: Text(time.format(context)),
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: time,
        );
        if (picked != null) {
          onPick(picked);
        }
      },
    );
  }

  // ---------- Save logic ----------

  void _saveCourse() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final subjectId = DateTime.now().millisecondsSinceEpoch.toString();
 // ✅ unique, safe ID

    final subjectBox = Hive.box<Subject>('subjects');
    subjectBox.put(
      subjectId,
      Subject(
        id: subjectId,
        name: name,
      ),
    );

    TimetableEngine().addSlot(
      TimetableSlot(
        subjectId: subjectId,
        weekday: _weekday,
        startTime: _start.format(context),
        endTime: _end.format(context),
      ),
    );

    Navigator.pop(context); // go back to timetable
  }
}
