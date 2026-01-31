import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class TimetableImagePreviewPage extends StatefulWidget {
  final File imageFile;
  const TimetableImagePreviewPage({super.key, required this.imageFile});

  @override
  State<TimetableImagePreviewPage> createState() => _TimetableImagePreviewPageState();
}

class DetectedClass {
  int weekday; // 1 = Mon, 7 = Sun
  String startTime;
  String endTime;
  String subject;

  DetectedClass({
    required this.weekday,
    required this.startTime,
    required this.endTime,
    required this.subject,
  });
}

class _TimetableImagePreviewPageState extends State<TimetableImagePreviewPage> {
  bool _isProcessing = false;
  List<DetectedClass> _detectedClasses = [];

  // ================= 1. REFINED GRID OCR LOGIC =================

  Future<void> _runOCR() async {
    setState(() => _isProcessing = true);
    final inputImage = InputImage.fromFile(widget.imageFile);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final RecognizedText text = await recognizer.processImage(inputImage);
      List<DetectedClass> results = [];

      int? currentDay;
      // Pre-defined time slots from your timetable image
      final List<String> timeSlots = [
        "08:00-09:00", "09:00-10:00", "10:00-11:00", "11:00-12:00",
        "12:00-01:00", "01:00-02:00", "02:00-03:00", "03:00-04:00",
        "04:00-05:00", "05:00-06:00"
      ];

      final dayMap = {'mo': 1, 'tu': 2, 'we': 3, 'th': 4, 'fr': 5, 'sa': 6, 'su': 7};

      for (TextBlock block in text.blocks) {
        for (TextLine line in block.lines) {
          String raw = line.text.trim().toLowerCase();

          // Update current day context
          for (var entry in dayMap.entries) {
            if (raw == entry.key || raw.startsWith('${entry.key} ')) {
              currentDay = entry.value;
            }
          }

          // Detect Subject Names (Filtering out metadata/room numbers)
          // Subjects like "PCT", "MATH", "DSP", "DEC" are usually 2-10 chars
          if (currentDay != null && raw.length >= 2) {
            bool isNoise = raw.contains('bt etc') || raw.startsWith('c1') || raw.contains('w.e.f');
            bool isTime = raw.contains(':');

            if (!isNoise && !isTime && raw.length < 20) {
              // We assign it to a default slot or attempt to find the nearest time in the block
              results.add(DetectedClass(
                weekday: currentDay,
                startTime: "09:00",
                endTime: "10:00",
                subject: line.text.trim().toUpperCase(),
              ));
            }
          }
        }
      }

      setState(() => _detectedClasses = results);
    } catch (e) {
      debugPrint("OCR Error: $e");
    } finally {
      recognizer.close();
      setState(() => _isProcessing = false);
    }
  }

  // ================= 2. ENHANCED EDIT DIALOG (With Day/Time) =================

  void _editClass(int index) {
    final item = _detectedClasses[index];
    final TextEditingController subjectCtrl = TextEditingController(text: item.subject);
    final TextEditingController startCtrl = TextEditingController(text: item.startTime);
    final TextEditingController endCtrl = TextEditingController(text: item.endTime);
    int selectedDay = item.weekday;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Edit Schedule"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: subjectCtrl, decoration: const InputDecoration(labelText: "Subject")),
                const SizedBox(height: 10),
                DropdownButton<int>(
                  value: selectedDay,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 1, child: Text("Monday")),
                    DropdownMenuItem(value: 2, child: Text("Tuesday")),
                    DropdownMenuItem(value: 3, child: Text("Wednesday")),
                    DropdownMenuItem(value: 4, child: Text("Thursday")),
                    DropdownMenuItem(value: 5, child: Text("Friday")),
                    DropdownMenuItem(value: 6, child: Text("Saturday")),
                    DropdownMenuItem(value: 7, child: Text("Sunday")),
                  ],
                  onChanged: (val) => setDialogState(() => selectedDay = val!),
                ),
                Row(
                  children: [
                    Expanded(child: TextField(controller: startCtrl, decoration: const InputDecoration(labelText: "Start"))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: endCtrl, decoration: const InputDecoration(labelText: "End"))),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _detectedClasses[index] = DetectedClass(
                    weekday: selectedDay,
                    startTime: startCtrl.text,
                    endTime: endCtrl.text,
                    subject: subjectCtrl.text,
                  );
                });
                Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
          ],
        ),
      ),
    );
  }

  // ================= 3. UI BUILDER =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Preview Timetable")),
      body: Column(
        children: [
          SizedBox(
            height: 180,
            width: double.infinity,
            child: Image.file(widget.imageFile, fit: BoxFit.contain),
          ),
          if (_isProcessing) const LinearProgressIndicator(),
          Expanded(
            child: _detectedClasses.isEmpty
                ? const Center(child: Text("Tap Extract to find subjects"))
                : ListView.builder(
              itemCount: _detectedClasses.length,
              itemBuilder: (context, index) {
                final item = _detectedClasses[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.deepPurple,
                      child: Text(item.weekday.toString(), style: const TextStyle(color: Colors.white)),
                    ),
                    title: Text(item.subject, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("${_getDayName(item.weekday)} | ${item.startTime} - ${item.endTime}"),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _editClass(index),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.all(16)),
                    onPressed: _isProcessing ? null : _runOCR,
                    child: const Text("Extract Text (OCR)", style: TextStyle(color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _detectedClasses.isEmpty ? null : () { /* Next step */ },
                    child: const Text("Continue"),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getDayName(int day) {
    return ["", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][day];
  }
}