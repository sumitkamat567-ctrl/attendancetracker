import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/subject.dart';
import '../models/timetable_slot.dart';
import '../storage/timetable_engine.dart';
import '../notifications/reminder_service.dart';

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
      int h = int.parse(parts[0]);
      final m = int.parse(parts[1].split(' ')[0]);
      if (t.contains("PM") && h != 12) h += 12;
      if (t.contains("AM") && h == 12) h = 0;
      return TimeOfDay(hour: h, minute: m);
    } catch (e) {
      return const TimeOfDay(hour: 9, minute: 0);
    }
  }

  void _openTimePicker(bool isStart) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.98),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) {
        return _SymmetricJogPickerOverlay(
          initialTime: isStart ? _start : _end,
          onConfirm: (newTime) {
            setState(() {
              if (isStart) {
                _start = newTime;
              } else {
                _end = newTime;
              }
            });
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Column(
          children: [
            _MinimalHeader(isEditing: widget.existingSlot != null),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 32),
                    _CourseNameField(controller: _nameController),
                    const SizedBox(height: 48),
                    _SectionLabel("Schedule"),
                    const SizedBox(height: 16),
                    _HorizonDaySelector(
                      selectedDay: _weekday,
                      onChanged: (v) => setState(() => _weekday = v),
                    ),
                    const SizedBox(height: 48),
                    _SectionLabel("Time Interval"),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _TimeDisplayBox(label: "FROM", time: _start, onTap: () => _openTimePicker(true))),
                        const SizedBox(width: 16),
                        Expanded(child: _TimeDisplayBox(label: "UNTIL", time: _end, onTap: () => _openTimePicker(false))),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            _ActionFooter(
              onSave: _saveCourse,
              label: widget.existingSlot != null ? "Update Entry" : "Create Entry",
            ),
          ],
        ),
      ),
    );
  }

  void _saveCourse() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      HapticFeedback.vibrate();
      return;
    }
    HapticFeedback.mediumImpact();
    final subjectBox = Hive.box<Subject>('subjects');

    if (widget.existingSlot != null) {
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
      ReminderService.rescheduleAll();
    } else {
      // 🔗 Link to existing subject if same name found (case-insensitive)
      String? subjectId;
      for (var s in subjectBox.values) {
        if (s.name.toLowerCase() == name.toLowerCase()) {
          subjectId = s.id;
          break;
        }
      }

      if (subjectId == null) {
        subjectId = DateTime.now().millisecondsSinceEpoch.toString();
        subjectBox.put(subjectId, Subject(id: subjectId, name: name));
      }

      TimetableEngine().addSlot(TimetableSlot(
        subjectId: subjectId,
        weekday: _weekday,
        startTime: _start.format(context),
        endTime: _end.format(context),
      ));
      ReminderService.rescheduleAll();
    }
    Navigator.pop(context);
  }
}

/* ───────────────── SYMMETRIC JOG PICKER OVERLAY ───────────────── */

class _SymmetricJogPickerOverlay extends StatefulWidget {
  final TimeOfDay initialTime;
  final ValueChanged<TimeOfDay> onConfirm;

  const _SymmetricJogPickerOverlay({required this.initialTime, required this.onConfirm});

  @override
  State<_SymmetricJogPickerOverlay> createState() => _SymmetricJogPickerOverlayState();
}

class _SymmetricJogPickerOverlayState extends State<_SymmetricJogPickerOverlay> {
  late int hour, minute;
  late DayPeriod period;

  @override
  void initState() {
    super.initState();
    hour = widget.initialTime.hourOfPeriod == 0 ? 12 : widget.initialTime.hourOfPeriod;
    minute = widget.initialTime.minute;
    period = widget.initialTime.period;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final dialSize = size.height * 0.7; // Large breathable dials

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Left Wheel (Hours)
          Positioned(
            left: -dialSize * 0.7,
            top: (size.height - dialSize) / 2,
            child: _SmoothDial(
              label: "HOURS",
              max: 12,
              value: hour,
              size: dialSize,
              isInverted: false, // Standard direction
              onChanged: (v) => setState(() => hour = v == 0 ? 12 : v),
            ),
          ),
          // Right Wheel (Minutes)
          Positioned(
            right: -dialSize * 0.7,
            top: (size.height - dialSize) / 2,
            child: _SmoothDial(
              label: "MINUTES",
              max: 60,
              value: minute,
              size: dialSize,
              isInverted: true, // Fixed mirroring
              onChanged: (v) => setState(() => minute = v),
            ),
          ),
          // HUD Center
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "VERTICAL SWIPE TO ROTATE",
                  style: GoogleFonts.bricolageGrotesque(
                    fontSize: 8,
                    color: Colors.white.withValues(alpha: 0.12),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  "${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}",
                  style: GoogleFonts.bricolageGrotesque(
                    fontSize: 88,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -3,
                  ),
                ),
                const SizedBox(height: 48),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _periodToggle("AM", DayPeriod.am),
                    const SizedBox(width: 12),
                    _periodToggle("PM", DayPeriod.pm),
                  ],
                ),
              ],
            ),
          ),
          // Bottom Actions
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _circularBtn(Icons.close_rounded, () => Navigator.pop(context), false),
                const SizedBox(width: 40),
                _circularBtn(Icons.check_rounded, () {
                  int finalH = hour;
                  if (period == DayPeriod.pm && hour != 12) finalH += 12;
                  if (period == DayPeriod.am && hour == 12) finalH = 0;
                  widget.onConfirm(TimeOfDay(hour: finalH, minute: minute));
                  Navigator.pop(context);
                }, true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _periodToggle(String label, DayPeriod p) {
    bool active = period == p;
    return GestureDetector(
      onTap: () => setState(() => period = p),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFBB86FC) : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(40),
        ),
        child: Text(label, style: GoogleFonts.bricolageGrotesque(color: active ? Colors.black : Colors.white24, fontWeight: FontWeight.w800, fontSize: 13)),
      ),
    );
  }

  Widget _circularBtn(IconData icon, VoidCallback tap, bool primary) {
    return GestureDetector(
      onTap: tap,
      child: Container(
        height: 68,
        width: 68,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: primary ? const Color(0xFFBB86FC) : Colors.white.withValues(alpha: 0.06),
        ),
        child: Icon(icon, color: primary ? Colors.black : Colors.white, size: 28),
      ),
    );
  }
}

class _SmoothDial extends StatefulWidget {
  final int max, value;
  final String label;
  final double size;
  final bool isInverted;
  final ValueChanged<int> onChanged;

  const _SmoothDial({
    required this.max,
    required this.value,
    required this.onChanged,
    required this.label,
    required this.size,
    required this.isInverted,
  });

  @override
  State<_SmoothDial> createState() => _SmoothDialState();
}

class _SmoothDialState extends State<_SmoothDial> {
  double _rotation = 0.0;
  double _cumulativeDelta = 0.0;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: (details) {
          // If isInverted is true, we flip the delta so that dragging up always increases numbers
          final double delta = widget.isInverted ? -details.primaryDelta! : details.primaryDelta!;

          setState(() => _rotation += delta * 0.007);
          _cumulativeDelta += delta;

          if (_cumulativeDelta.abs() > 10) {
            int steps = (_cumulativeDelta / 10).floor();
            int newVal = (widget.value - steps) % widget.max;
            if (newVal < 0) newVal += widget.max;

            widget.onChanged(newVal);
            HapticFeedback.selectionClick();
            _cumulativeDelta %= 10;
          }
        },
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.01),
            border: Border.all(color: Colors.white.withValues(alpha: 0.02), width: 1),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.rotate(
                angle: _rotation,
                child: CustomPaint(
                  size: Size(widget.size, widget.size),
                  painter: _SmoothDialPainter(),
                ),
              ),
              Positioned(
                left: widget.label == "HOURS" ? null : 60,
                right: widget.label == "HOURS" ? 60 : null,
                child: RotatedBox(
                  quarterTurns: widget.label == "HOURS" ? 1 : 3,
                  child: Text(
                    widget.label,
                    style: GoogleFonts.bricolageGrotesque(
                      color: const Color(0xFFBB86FC).withValues(alpha: 0.2),
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                      letterSpacing: 4,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmoothDialPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final paint = Paint()..strokeCap = StrokeCap.round;

    for (int i = 0; i < 60; i++) {
      final double angle = (i * 2 * pi / 60);
      final bool isPurple = i % 5 == 0;

      paint.color = isPurple ? const Color(0xFFBB86FC).withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.05);
      paint.strokeWidth = isPurple ? 3.0 : 1.0;

      double tickLength = isPurple ? 35 : 15;
      double start = radius - tickLength;

      canvas.drawLine(
        Offset(center.dx + start * cos(angle), center.dy + start * sin(angle)),
        Offset(center.dx + radius * cos(angle), center.dy + radius * sin(angle)),
        paint,
      );
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/* ───────────────── CORE PAGE UI COMPONENTS ───────────────── */

class _TimeDisplayBox extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;
  const _TimeDisplayBox({required this.label, required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF121212),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
        ),
        child: Column(
          children: [
            Text(label, style: GoogleFonts.bricolageGrotesque(fontSize: 9, color: Colors.white24, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            const SizedBox(height: 10),
            Text(time.format(context), style: GoogleFonts.jetBrainsMono(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _MinimalHeader extends StatelessWidget {
  final bool isEditing;
  const _MinimalHeader({required this.isEditing});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28)),
          Text(isEditing ? "EDIT COURSE" : "NEW COURSE", style: GoogleFonts.bricolageGrotesque(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1.5)),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _HorizonDaySelector extends StatelessWidget {
  final int selectedDay;
  final ValueChanged<int> onChanged;
  const _HorizonDaySelector({required this.selectedDay, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final days = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"];
    return LayoutBuilder(builder: (context, constraints) {
      double itemWidth = constraints.maxWidth / 7;
      return Stack(
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            left: (selectedDay - 1) * itemWidth,
            child: Container(width: itemWidth, height: 40, decoration: BoxDecoration(color: const Color(0xFFBB86FC).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10))),
          ),
          Row(
            children: List.generate(7, (i) {
              bool isSelected = (i + 1) == selectedDay;
              return Expanded(
                child: GestureDetector(
                  onTap: () { HapticFeedback.selectionClick(); onChanged(i + 1); },
                  child: Container(height: 40, alignment: Alignment.center, child: Text(days[i], style: GoogleFonts.bricolageGrotesque(fontSize: 11, fontWeight: isSelected ? FontWeight.w800 : FontWeight.w400, color: isSelected ? const Color(0xFFBB86FC) : Colors.white24))),
                ),
              );
            }),
          ),
        ],
      );
    });
  }
}

class _CourseNameField extends StatelessWidget {
  final TextEditingController controller;
  const _CourseNameField({required this.controller});
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      cursorColor: const Color(0xFFBB86FC),
      style: GoogleFonts.bricolageGrotesque(fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white),
      decoration: const InputDecoration(hintText: "Course Title", hintStyle: TextStyle(color: Colors.white10), border: InputBorder.none),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(text.toUpperCase(), style: GoogleFonts.bricolageGrotesque(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white10, letterSpacing: 2.5));
  }
}

class _ActionFooter extends StatelessWidget {
  final VoidCallback onSave;
  final String label;
  const _ActionFooter({required this.onSave, required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.04)))),
      child: GestureDetector(
        onTap: onSave,
        child: Container(height: 64, width: double.infinity, decoration: BoxDecoration(color: const Color(0xFFBB86FC), borderRadius: BorderRadius.circular(20)), child: Center(child: Text(label, style: GoogleFonts.bricolageGrotesque(fontWeight: FontWeight.w900, color: Colors.black, fontSize: 16)))),
      ),
    );
  }
}