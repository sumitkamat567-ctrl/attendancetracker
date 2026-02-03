import 'dart:async';
import 'dart:io';
import 'package:shimmer/shimmer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import '../models/subject.dart';
import '../models/timetable_slot.dart';
import '../models/detected_class.dart';
import '../storage/timetable_engine.dart';
import 'timetable_ocr_service.dart';
import '../notifications/reminder_service.dart';

class TimetableImagePreviewPage extends StatefulWidget {
  final File imageFile;
  const TimetableImagePreviewPage({super.key, required this.imageFile});

  @override
  State<TimetableImagePreviewPage> createState() =>
      _TimetableImagePreviewPageState();
}

class _TimetableImagePreviewPageState extends State<TimetableImagePreviewPage> {
  bool _isProcessing = false;
  List<DetectedClass> _detectedClasses = [];

  final List<String> _aiMessages = [
    "Analyzing structure",
    "Reading class data",
    "Identifying subjects",
    "Matching time slots",
    "Surgical precision applied",
  ];
  int _currentMessageIndex = 0;
  Timer? _messageTimer;

  /* ───────────────── LOGIC (UNTOUCHED) ───────────────── */

  Future<void> _runOCR() async {
    HapticFeedback.mediumImpact();
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

  void _startAIMessages() {
    _messageTimer?.cancel();
    _currentMessageIndex = 0;
    _messageTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      if (!_isProcessing) return;
      setState(() {
        _currentMessageIndex = (_currentMessageIndex + 1) % _aiMessages.length;
      });
    });
  }

  void _stopAIMessages() {
    _messageTimer?.cancel();
    _messageTimer = null;
  }

  void _deleteClass(int index) {
    HapticFeedback.selectionClick();
    setState(() => _detectedClasses.removeAt(index));
  }

  void _editClass(int index) async {
    HapticFeedback.lightImpact();
    final result = await showModalBottomSheet<DetectedClass>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditDialog(initial: _detectedClasses[index]),
    );
    if (result != null) setState(() => _detectedClasses[index] = result);
  }

  Future<void> _importAndFinalize() async {
    HapticFeedback.heavyImpact();
    final subjectBox = Hive.box<Subject>('subjects');
    final engine = TimetableEngine();
    final Map<String, String> nameToId = {};

    for (final item in _detectedClasses) {
      final name = item.subject.trim();
      if (name.isEmpty) continue;
      String? subjectId = nameToId[name.toLowerCase()];
      if (subjectId == null) {
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
      engine.addSlot(TimetableSlot(
        subjectId: subjectId,
        weekday: item.weekday,
        startTime: item.startTime,
        endTime: item.endTime,
      ));
    }
    
    // 🔔 Reschedule all reminders
    await ReminderService.rescheduleAll();
    
    if (!mounted) return;
    Navigator.pop(context);
  }

  /* ───────────────── UI (ENHANCED) ───────────────── */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      body: SafeArea(
        child: Column(
          children: [
            _Header(),
            _ImageStrip(image: widget.imageFile),
            Expanded(
              child: _isProcessing
                  ? _AILoadingSection(message: _aiMessages[_currentMessageIndex])
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
}

/* ───────────────── COMPONENTS ───────────────── */

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Vision Import",
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -1,
                ),
              ),
              Text(
                "Review detected class schedules",
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 14,
                  color: Colors.white38,
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded, color: Colors.white24),
          ),
        ],
      ),
    );
  }
}

class _ImageStrip extends StatelessWidget {
  final File image;
  const _ImageStrip({required this.image});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Container(
        height: 100,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          image: DecorationImage(
            image: FileImage(image),
            fit: BoxFit.cover,
            opacity: 0.2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            color: Colors.black.withValues(alpha: 0.3),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  "REFERENCE SOURCE",
                  style: GoogleFonts.bricolageGrotesque(
                    fontSize: 10,
                    color: Colors.white38,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DetectedList extends StatelessWidget {
  final List<DetectedClass> items;
  final ValueChanged<int> onEdit, onDelete;
  const _DetectedList({required this.items, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF818CF8).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    item.subject.isNotEmpty ? item.subject[0].toUpperCase() : "?",
                    style: GoogleFonts.bricolageGrotesque(
                      color: const Color(0xFF818CF8),
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.subject,
                      style: GoogleFonts.bricolageGrotesque(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${_dayName(item.weekday)}  •  ${item.startTime} - ${item.endTime}",
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        color: Colors.white38,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              _confidenceBadge(item.confidence),
              const SizedBox(width: 8),
              _CircleAction(icon: Icons.edit_rounded, onTap: () => onEdit(index)),
              const SizedBox(width: 4),
              _CircleAction(icon: Icons.delete_outline_rounded, onTap: () => onDelete(index), isDestructive: true),
            ],
          ),
        );
      },
    );
  }
}

class _CircleAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDestructive;
  const _CircleAction({required this.icon, required this.onTap, this.isDestructive = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: isDestructive ? Colors.red.withValues(alpha: 0.4) : Colors.white24, size: 18),
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  final bool isProcessing, hasResults;
  final VoidCallback onExtract, onFinalize;
  const _BottomActions({required this.isProcessing, required this.hasResults, required this.onExtract, required this.onFinalize});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [const Color(0xFF121212).withValues(alpha: 0), const Color(0xFF121212)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!hasResults || isProcessing)
            _MainButton(
              label: isProcessing ? "Neural Scanning..." : "Scan Timetable",
              icon: Icons.auto_awesome,
              onTap: onExtract,
              isLoading: isProcessing,
              isPrimary: true,
            )
          else
            _MainButton(
              label: "Finalize & Save",
              icon: Icons.check_circle_rounded,
              onTap: onFinalize,
              isPrimary: true,
            ),
        ],
      ),
    );
  }
}

class _MainButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isLoading, isPrimary;
  const _MainButton({required this.label, required this.icon, required this.onTap, this.isLoading = false, this.isPrimary = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        height: 60,
        width: double.infinity,
        decoration: BoxDecoration(
          color: isPrimary ? Colors.white : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(20),
          boxShadow: isPrimary ? [BoxShadow(color: Colors.white.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 10))] : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
            else
              Icon(icon, color: isPrimary ? Colors.black : Colors.white, size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.bricolageGrotesque(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: isPrimary ? Colors.black : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AILoadingSection extends StatelessWidget {
  final String message;
  const _AILoadingSection({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AnimatedAIText(text: message),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 3,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, __) => const _ShimmerCard(),
            ),
          ),
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

class _AnimatedAITextState extends State<_AnimatedAIText> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant _AnimatedAIText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: Text(
        widget.text,
        style: GoogleFonts.bricolageGrotesque(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white70),
      ),
    );
  }
}

class _ShimmerCard extends StatelessWidget {
  const _ShimmerCard();
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF1E1E1E),
      highlightColor: const Color(0xFF2C2C2C),
      child: Container(
        height: 80,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        "Tap “Scan Timetable” to begin",
        style: GoogleFonts.bricolageGrotesque(fontSize: 14, color: Colors.white24),
      ),
    );
  }
}

Widget _confidenceBadge(double confidence) {
  final percent = (confidence * 100).round();
  Color color = percent >= 85 ? const Color(0xFF34C759) : (percent >= 65 ? const Color(0xFFFFCC00) : const Color(0xFFFF3B30));
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
    child: Text("$percent%", style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
  );
}

String _dayName(int d) => ["", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][d];

/* ───────────────── EDIT DIALOG (FIXED UNDERLINES) ───────────────── */

class _EditDialog extends StatefulWidget {
  final DetectedClass initial;
  const _EditDialog({required this.initial});
  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  late TextEditingController _nameController;
  late int _weekday;
  late String _start, _end;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initial.subject);
    _weekday = widget.initial.weekday;
    _start = widget.initial.startTime;
    _end = widget.initial.endTime;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        decoration: const BoxDecoration(color: Color(0xFF1C1C1C), borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Edit Entry", style: GoogleFonts.bricolageGrotesque(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                _CircleAction(icon: Icons.close_rounded, onTap: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 24),
            _FieldLabel("Subject Name"),
            TextField(
              controller: _nameController,
              style: GoogleFonts.bricolageGrotesque(color: Colors.white),
              decoration: _inputDecoration("Subject name..."),
            ),
            const SizedBox(height: 20),
            _FieldLabel("Weekday"),
            _WeekdayRow(value: _weekday, onChanged: (v) => setState(() => _weekday = v)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_FieldLabel("Starts"), _TimePicker(value: _start, onChanged: (v) => setState(() => _start = v))])),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_FieldLabel("Ends"), _TimePicker(value: _end, onChanged: (v) => setState(() => _end = v))])),
              ],
            ),
            const SizedBox(height: 32),
            _MainButton(
              label: "Save Changes",
              icon: Icons.check_rounded,
              isPrimary: true,
              onTap: () => Navigator.pop(context, DetectedClass(weekday: _weekday, startTime: _start, endTime: _end, subject: _nameController.text.trim(), confidence: 1.0)),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white10),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.03),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel(this.label);
  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(label, style: GoogleFonts.bricolageGrotesque(fontSize: 12, color: Colors.white24, fontWeight: FontWeight.w700, letterSpacing: 0.5)));
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
            width: 42, height: 42,
            decoration: BoxDecoration(color: selected ? Colors.white : Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(12)),
            child: Center(child: Text(days[i], style: GoogleFonts.bricolageGrotesque(fontWeight: FontWeight.w800, color: selected ? Colors.black : Colors.white24))),
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
        final picked = await showTimePicker(context: context, initialTime: TimeOfDay(hour: int.tryParse(parts[0]) ?? 9, minute: int.tryParse(parts[1].substring(0, 2)) ?? 0));
        if (picked != null) onChanged("${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}");
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(16)),
        child: Row(children: [const Icon(Icons.access_time_filled_rounded, size: 16, color: Colors.white24), const SizedBox(width: 8), Text(value, style: GoogleFonts.jetBrainsMono(color: Colors.white, fontWeight: FontWeight.w500))]),
      ),
    );
  }
}