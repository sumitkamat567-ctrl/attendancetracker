import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/timetable_slot.dart';
import '../models/subject.dart';
import '../storage/attendance_engine.dart';

class StatusPage extends StatefulWidget {
  const StatusPage({super.key});

  @override
  State<StatusPage> createState() => _StatusPageState();
}

class _StatusPageState extends State<StatusPage> {
  late int _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now().weekday;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false, // For the custom dock feel
        child: ValueListenableBuilder(
          valueListenable: Hive.box<TimetableSlot>('timetable').listenable(),
          builder: (context, Box<TimetableSlot> timetableBox, _) {
            return ValueListenableBuilder(
              valueListenable: Hive.box<Subject>('subjects').listenable(),
              builder: (context, Box<Subject> subjectBox, _) {
                final daySlots = timetableBox.values
                    .where((s) => s.weekday == _selectedDay)
                    .toList();

                // Sort slots by time
                daySlots.sort((a, b) => a.startTime.compareTo(b.startTime));

                final todaySubjects = daySlots
                    .map((s) => subjectBox.get(s.subjectId))
                    .whereType<Subject>()
                    .toList();

                final lowestAttendance = todaySubjects.isEmpty
                    ? 100.0
                    : todaySubjects
                        .map((s) => s.percentage)
                        .reduce((a, b) => a < b ? a : b);

                return CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    _buildSliverHeader(),
                    SliverToBoxAdapter(
                      child: _DaySelector(
                        selectedDay: _selectedDay,
                        onChanged: (day) => setState(() => _selectedDay = day),
                      ),
                    ),
                    if (daySlots.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _EmptyState(day: _selectedDay),
                      )
                    else ...[
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        sliver: SliverToBoxAdapter(
                          child: _AttendanceInsightCard(
                            attendance: lowestAttendance,
                            count: todaySubjects.length,
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 40, 24, 16),
                          child: _SectionLabel("SCHEDULED SESSIONS"),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 140),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final slot = daySlots[index];
                              final subject = subjectBox.get(slot.subjectId);
                              if (subject == null) return const SizedBox();

                              return _StatusClassTile(
                                subject: subject,
                                slot: slot,
                              );
                            },
                            childCount: daySlots.length,
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildSliverHeader() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 15, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Status",
              style: GoogleFonts.bricolageGrotesque(
                fontSize: 40,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttendanceInsightCard extends StatelessWidget {
  final double attendance;
  final int count;

  const _AttendanceInsightCard({required this.attendance, required this.count});

  @override
  Widget build(BuildContext context) {
    final bool isCritical = attendance < 75;
    final color =
        isCritical ? const Color(0xFFFF3B30) : Theme.of(context).primaryColor;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Stack(
          children: [
            // Subtle Background Glow
            Positioned(
              top: -50,
              right: -50,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.1),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _MetricItem(
                          "LOWEST", "${attendance.toStringAsFixed(0)}%", color),
                      _MetricItem("DAILY", count.toString(), Colors.white),
                      _MetricItem(
                          "ZONE", isCritical ? "CRITICAL" : "HEALTHY", color),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(color: Colors.white10, height: 1),
                  const SizedBox(height: 20),
                  Text(
                    isCritical
                        ? "Attendance is below threshold. Attendance today is vital for subject stability."
                        : "All systems operational. Your current momentum supports future flexibility.",
                    style: GoogleFonts.bricolageGrotesque(
                      color: Colors.white38,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  final String label, value;
  final Color valueColor;
  const _MetricItem(this.label, this.value, this.valueColor);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.bricolageGrotesque(
                color: Colors.white24,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1)),
        const SizedBox(height: 6),
        Text(value,
            style: GoogleFonts.jetBrainsMono(
                color: valueColor, fontSize: 18, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _StatusClassTile extends StatelessWidget {
  final Subject subject;
  final TimetableSlot slot;

  const _StatusClassTile({required this.subject, required this.slot});

  @override
  Widget build(BuildContext context) {
    final isRisk = subject.percentage < 75;

    return GestureDetector(
      onTap: () => _showAttendanceActions(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            // Time Component
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(slot.startTime.split(' ')[0],
                    style: GoogleFonts.jetBrainsMono(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                Text(slot.startTime.contains('PM') ? 'PM' : 'AM',
                    style: GoogleFonts.bricolageGrotesque(
                        color: Colors.white24,
                        fontSize: 10,
                        fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(width: 20),
            Container(height: 40, width: 1, color: Colors.white10),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subject.name,
                    style: GoogleFonts.bricolageGrotesque(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isRisk ? const Color(0xFFFF3B30) : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Required: 75%",
                    style: GoogleFonts.bricolageGrotesque(
                        color: Colors.white24, fontSize: 12),
                  ),
                ],
              ),
            ),
            // Percentage Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isRisk
                    ? const Color(0xFFFF3B30).withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                "${subject.percentage.toStringAsFixed(0)}%",
                style: GoogleFonts.jetBrainsMono(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: isRisk
                      ? const Color(0xFFFF3B30)
                      : Theme.of(context).primaryColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAttendanceActions(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Column(
                      children: [
                        Text(
                          subject.name.toUpperCase(),
                          style: GoogleFonts.bricolageGrotesque(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white38,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Mark today's attendance",
                          style: GoogleFonts.bricolageGrotesque(
                            fontSize: 12,
                            color: Colors.white38,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Colors.white10),
                  _ActionTile(
                    label: "Mark Present",
                    icon: Icons.check_circle_rounded,
                    color: const Color(0xFF34C759),
                    onTap: () {
                      AttendanceEngine().markAttendance(
                        subjectId: subject.id,
                        present: true,
                      );
                      Navigator.pop(context);
                      HapticFeedback.mediumImpact();
                    },
                  ),
                  const Divider(height: 1, color: Colors.white10),
                  _ActionTile(
                    label: "Mark Absent",
                    icon: Icons.cancel_rounded,
                    color: const Color(0xFFFF3B30),
                    onTap: () {
                      AttendanceEngine().markAttendance(
                        subjectId: subject.id,
                        present: false,
                      );
                      Navigator.pop(context);
                      HapticFeedback.mediumImpact();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  "Cancel",
                  style: GoogleFonts.bricolageGrotesque(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: GoogleFonts.bricolageGrotesque(
                fontSize: 18,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DaySelector extends StatelessWidget {
  final int selectedDay;
  final ValueChanged<int> onChanged;

  const _DaySelector({required this.selectedDay, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 7,
        itemBuilder: (context, index) {
          final dayValue = index + 1;
          final isSelected = dayValue == selectedDay;

          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onChanged(dayValue);
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  days[index],
                  style: GoogleFonts.bricolageGrotesque(
                    color: isSelected ? Colors.black : Colors.white60,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        },
      ),
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
          color: Colors.white24,
          fontSize: 11,
          letterSpacing: 1.5,
          fontWeight: FontWeight.w900),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final int day;
  const _EmptyState({required this.day});

  @override
  Widget build(BuildContext context) {
    final dayNames = [
      "Monday",
      "Tuesday",
      "Wednesday",
      "Thursday",
      "Friday",
      "Saturday",
      "Sunday"
    ];
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.radio_button_checked_rounded,
              size: 48, color: Colors.white.withValues(alpha: 0.05)),
          const SizedBox(height: 20),
          Text(
            "SYSTEM IDLE",
            style: GoogleFonts.bricolageGrotesque(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Colors.white24,
                letterSpacing: 2),
          ),
          const SizedBox(height: 8),
          Text(
            "No sessions for ${dayNames[day - 1]}.",
            style: GoogleFonts.bricolageGrotesque(
                color: Colors.white10, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
