import 'dart:async';
import 'dart:io';
import 'package:shimmer/shimmer.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import '../models/subject.dart';
import '../models/timetable_slot.dart';
import '../models/detected_class.dart';
import '../storage/timetable_engine.dart';
import 'timetable_ocr_service.dart';

class TimetableImagePreviewPage extends StatefulWidget {
  final File imageFile;
  const TimetableImagePreviewPage({super.key, required this.imageFile});

  @override
  State<TimetableImagePreviewPage> createState() =>
      _TimetableImagePreviewPageState();
}



/* ───────────────── PAGE ───────────────── */

class _TimetableImagePreviewPageState
    extends State<TimetableImagePreviewPage> {
  bool _isProcessing = false;
  List<DetectedClass> _detectedClasses = [];

  /* AI loading text */
  final List<String> _aiMessages = [
    "Analyzing timetable",
    "Reading class structure",
    "Identifying subjects",
    "Matching time slots",
    "Applying finishing touches",
  ];
  int _currentMessageIndex = 0;
  Timer? _messageTimer;

  /* ───────────────── OCR ───────────────── */

  Future<void> _runOCR() async {
    setState(() => _isProcessing = true);
    _startAIMessages();

    try {
      final results = await TimetableOCRService.extractClasses(widget.imageFile);
      setState(() => _detectedClasses = results);
    } catch (e) {
      debugPrint("OCR Error: $e");
    } finally {
      _stopAIMessages();
      setState(() => _isProcessing = false);
    }
  }

  /* ───────────────── AI TEXT LOOP ───────────────── */

  void _startAIMessages() {
    _messageTimer?.cancel();
    _currentMessageIndex = 0;
    _messageTimer = Timer.periodic(
      const Duration(milliseconds: 1200),
          (_) {
        if (!_isProcessing) return;
        setState(() {
          _currentMessageIndex =
              (_currentMessageIndex + 1) % _aiMessages.length;
        });
      },
    );
  }

  void _stopAIMessages() {
    _messageTimer?.cancel();
    _messageTimer = null;
  }

  /* ───────────────── UI ───────────────── */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(),

            _ImageStrip(image: widget.imageFile),

            Expanded(
              child: _isProcessing
                  ? _AILoadingSection(
                message:
                _aiMessages[_currentMessageIndex],
              )
                  : _detectedClasses.isEmpty
                  ? _EmptyState()
                  : _DetectedList(
                items: _detectedClasses,
                onEdit: _editClass,
                onDelete: _deleteClass,
              ),
            ),

            _BottomActions(
              isProcessing: _isProcessing,
              hasResults: _detectedClasses.isNotEmpty,
              onExtract: _runOCR,
              onFinalize: _importAndFinalize,
            ),
          ],
        ),
      ),
    );
  }

  /* ───────────────── ACTIONS ───────────────── */

  void _deleteClass(int index) {
    setState(() {
      _detectedClasses.removeAt(index);
    });
  }

  void _editClass(int index) async {
    final result = await showModalBottomSheet<DetectedClass>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditDialog(initial: _detectedClasses[index]),
    );

    if (result != null) {
      setState(() {
        _detectedClasses[index] = result;
      });
    }
  }

  Future<void> _importAndFinalize() async {
    if (_detectedClasses.isEmpty) return;

    final subjectBox = Hive.box<Subject>('subjects');
    final engine = TimetableEngine();

    // Mapping to avoid duplicate subjects
    final Map<String, String> nameToId = {};

    for (final item in _detectedClasses) {
      final name = item.subject.trim();
      if (name.isEmpty) continue;

      String? subjectId = nameToId[name.toLowerCase()];

      if (subjectId == null) {
        // Double check Hive if it exists already
        final existingSubject = subjectBox.values.firstWhere(
          (s) => s.name.toLowerCase() == name.toLowerCase(),
          orElse: () => Subject(id: "", name: ""),
        );

        if (existingSubject.id.isNotEmpty) {
          subjectId = existingSubject.id;
        } else {
          subjectId = DateTime.now().millisecondsSinceEpoch.toString() +
              nameToId.length.toString();
          subjectBox.put(subjectId, Subject(id: subjectId, name: name));
        }
        nameToId[name.toLowerCase()] = subjectId;
      }

      engine.addSlot(
        TimetableSlot(
          subjectId: subjectId,
          weekday: item.weekday,
          startTime: item.startTime,
          endTime: item.endTime,
        ),
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Timetable imported successfully!")),
    );

    Navigator.pop(context); // Return to timetable page
  }
}

/* ───────────────── COMPONENTS ───────────────── */

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Review timetable",
            style: GoogleFonts.bricolageGrotesque(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Check and adjust detected classes",
            style: GoogleFonts.bricolageGrotesque(
              fontSize: 14,
              color: Colors.white38,
            ),
          ),
        ],
      ),
    );
  }
}

/* ───────────────── IMAGE STRIP (FIXED) ───────────────── */

class _ImageStrip extends StatelessWidget {
  final File image;
  const _ImageStrip({required this.image});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1C),
          borderRadius: BorderRadius.circular(22),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Center(
            child: Image.file(
              image,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}

/* ───────────────── AI LOADING ───────────────── */

class _AILoadingSection extends StatelessWidget {
  final String message;
  const _AILoadingSection({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AnimatedAIText(text: message),
          const SizedBox(height: 20),
          ...List.generate(3, (_) => const _ShimmerCard()),
        ],
      ),
    );
  }
}

class _AnimatedAIText extends StatefulWidget {
  final String text;
  const _AnimatedAIText({required this.text});

  @override
  State<_AnimatedAIText> createState() => _AnimatedAITextState();
}

class _AnimatedAITextState extends State<_AnimatedAIText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;

  String _oldText = "";

  @override
  void initState() {
    super.initState();

    _oldText = widget.text;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );

    _fade = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant _AnimatedAIText oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.text != widget.text) {
      _oldText = oldWidget.text;
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 26, // 🔒 locks layout height (no jumps)
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          // Old text (fades out)
          FadeTransition(
            opacity: ReverseAnimation(_fade),
            child: Text(
              _oldText,
              style: _style(),
            ),
          ),

          // New text (fades in)
          FadeTransition(
            opacity: _fade,
            child: Text(
              widget.text,
              style: _style(),
            ),
          ),
        ],
      ),
    );
  }

  TextStyle _style() {
    return GoogleFonts.bricolageGrotesque(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: Colors.white70,
      letterSpacing: 0.3,
    );
  }
}

class _ShimmerCard extends StatelessWidget {
  const _ShimmerCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Shimmer.fromColors(
        baseColor: const Color(0xFF1C1C1C),
        highlightColor: const Color(0xFF2F2F2F),
        period: const Duration(milliseconds: 1400),
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _ShimmerText extends StatefulWidget {
  final String text;
  const _ShimmerText({required this.text});

  @override
  State<_ShimmerText> createState() => _ShimmerTextState();
}

class _ShimmerTextState extends State<_ShimmerText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return ShaderMask(
          shaderCallback: (rect) {
            return LinearGradient(
              begin: Alignment(-1 + 2 * _controller.value, 0),
              end: Alignment(1 + 2 * _controller.value, 0),
              colors: const [
                Colors.white24,
                Colors.white70,
                Colors.white24,
              ],
            ).createShader(rect);
          },
          child: Text(
            widget.text,
            style: GoogleFonts.bricolageGrotesque(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }
}

/* ───────────────── DETECTED LIST ───────────────── */

class _DetectedList extends StatelessWidget {
  final List<DetectedClass> items;
  final ValueChanged<int> onEdit;
  final ValueChanged<int> onDelete;

  const _DetectedList({
    required this.items,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = items[index];

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1C),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    item.subject.characters.first,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.subject,
                            style: GoogleFonts.bricolageGrotesque(
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        _confidenceBadge(item.confidence), // ✅ HERE
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${_dayName(item.weekday)} • ${item.startTime}–${item.endTime}",
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 13,
                        color: Colors.white38,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.white54),
                onPressed: () => onEdit(index),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: Colors.white38),
                onPressed: () => onDelete(index),
              ),
            ],
          ),
        );
      },
    );
  }
}

/* ───────────────── BOTTOM ACTIONS ───────────────── */

class _BottomActions extends StatelessWidget {
  final bool isProcessing;
  final bool hasResults;
  final VoidCallback onExtract;
  final VoidCallback onFinalize;

  const _BottomActions({
    required this.isProcessing,
    required this.hasResults,
    required this.onExtract,
    required this.onFinalize,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isProcessing ? null : onExtract,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Text(
                isProcessing ? "Extracting…" : "Extract classes",
                style: GoogleFonts.bricolageGrotesque(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          if (hasResults) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onFinalize,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2A2A2A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Text(
                  "Finalize & import",
                  style: GoogleFonts.bricolageGrotesque(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "You can edit later",
              style: GoogleFonts.bricolageGrotesque(
                fontSize: 12,
                color: Colors.white38,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/* ───────────────── HELPERS ───────────────── */

String _dayName(int d) =>
    ["", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][d];


class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        "Tap “Extract classes” to begin",
        style: GoogleFonts.bricolageGrotesque(
          fontSize: 14,
          color: Colors.white38,
        ),
      ),
    );
  }
}
Widget _confidenceBadge(double confidence) {
  final percent = (confidence * 100).round();

  Color color;
  if (percent >= 85) {
    color = Colors.white;
  } else if (percent >= 65) {
    color = const Color(0xFFFFC857); // soft amber
  } else {
    color = const Color(0xFFFF6B6B); // muted red
  }

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Text(
      "$percent%",
      style: GoogleFonts.bricolageGrotesque(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    ),
  );
}

/* ───────────────── EDIT DIALOG ───────────────── */

class _EditDialog extends StatefulWidget {
  final DetectedClass initial;
  const _EditDialog({required this.initial});

  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  late TextEditingController _nameController;
  late int _weekday;
  late String _start;
  late String _end;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initial.subject);
    _weekday = widget.initial.weekday;
    _start = widget.initial.startTime;
    _end = widget.initial.endTime;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                "Edit Class",
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white54),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _FieldLabel("Subject Name"),
          TextField(
            controller: _nameController,
            style: GoogleFonts.bricolageGrotesque(color: Colors.white),
            decoration: _inputDecoration("e.g. Mathematics"),
          ),
          const SizedBox(height: 20),
          _FieldLabel("Day"),
          _WeekdayRow(
            value: _weekday,
            onChanged: (v) => setState(() => _weekday = v),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FieldLabel("Starts"),
                    _TimePicker(
                      value: _start,
                      onChanged: (v) => setState(() => _start = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FieldLabel("Ends"),
                    _TimePicker(
                      value: _end,
                      onChanged: (v) => setState(() => _end = v),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () {
                Navigator.pop(
                  context,
                  DetectedClass(
                    weekday: _weekday,
                    startTime: _start,
                    endTime: _end,
                    subject: _nameController.text.trim(),
                    confidence: 1.0, // Manual edit -> max confidence
                  ),
                );
              },
              child: Text(
                "Save Changes",
                style: GoogleFonts.bricolageGrotesque(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel(this.label);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: GoogleFonts.bricolageGrotesque(
          fontSize: 12,
          color: Colors.white38,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _WeekdayRow extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _WeekdayRow({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final days = ["M", "T", "W", "T", "F", "S", "S"];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final dayValue = i + 1;
        final selected = dayValue == value;
        return GestureDetector(
          onTap: () => onChanged(dayValue),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: selected ? Colors.white : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                days[i],
                style: GoogleFonts.bricolageGrotesque(
                  fontWeight: FontWeight.bold,
                  color: selected ? Colors.black : Colors.white54,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _TimePicker extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _TimePicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final parts = value.split(':');
        final initial = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 9,
          minute: int.tryParse(parts[1].substring(0, 2)) ?? 0,
        );

        final picked = await showTimePicker(
          context: context,
          initialTime: initial,
        );

        if (picked != null) {
          final h = picked.hour.toString().padLeft(2, '0');
          final m = picked.minute.toString().padLeft(2, '0');
          onChanged("$h:$m");
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time, size: 16, color: Colors.white38),
            const SizedBox(width: 8),
            Text(
              value,
              style: GoogleFonts.bricolageGrotesque(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
