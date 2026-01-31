import 'package:flutter/material.dart';
import '../models/detected_class.dart';

class DetectedClassesPage extends StatelessWidget {
  final List<DetectedClass> classes;

  const DetectedClassesPage({
    super.key,
    required this.classes,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Confirm Timetable")),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: classes.length,
        itemBuilder: (context, index) {
          final c = classes[index];
          return Card(
            color: const Color(0xFF1B1B1B),
            child: ListTile(
              leading: const Icon(Icons.check_circle, color: Colors.green),
              title: Text(
                "${_day(c.weekday)} ${c.startTime} - ${c.endTime}",
              ),
              subtitle: Text(c.subject),
            ),
          );
        },
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: () {
            Navigator.pop(context, classes);
          },
          child: const Text("Confirm & Save"),
        ),
      ),
    );
  }

  String _day(int d) {
    const days = [
      "",
      "Monday",
      "Tuesday",
      "Wednesday",
      "Thursday",
      "Friday"
    ];
    return days[d];
  }
}
