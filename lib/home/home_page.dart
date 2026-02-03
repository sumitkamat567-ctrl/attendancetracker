import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:Hazri/home/settings_page.dart';
import '../storage/local_storage.dart';
import '../models/subject.dart';
import '../models/timetable_slot.dart';
import '../status/subject_history_page.dart';
import '../utils/daily_quotes.dart';

class HomePage extends StatelessWidget {
  HomePage({super.key});

  static const Color textSecondary = Color(0xFF9A9AA0);

  // Fetch the name saved during onboarding from the Hive box
  final String userName =
      LocalStorage.settingsBox.get('userName', defaultValue: 'Hazri User');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: ValueListenableBuilder(
          valueListenable: Hive.box<TimetableSlot>('timetable').listenable(),
          builder: (context, timetableBox, _) {
            return ValueListenableBuilder(
              valueListenable: Hive.box<Subject>('subjects').listenable(),
              builder: (_, Box<Subject> subjectBox, __) {
                // 🔍 Filter: Show subjects in current timetable OR with attendance history
                final activeSubjectIds =
                    timetableBox.values.map((s) => s.subjectId).toSet();

                final subjects = subjectBox.values.where((s) {
                  final inTimetable = activeSubjectIds.contains(s.id);
                  final hasAttendance = s.totalClasses > 0;
                  return inTimetable || hasAttendance;
                }).toList();

                // 🏗️ Sort: Active (Timetable) subjects first, then alphabetical
                subjects.sort((a, b) {
                  final aIn = activeSubjectIds.contains(a.id);
                  final bIn = activeSubjectIds.contains(b.id);
                  if (aIn && !bIn) return -1;
                  if (!aIn && bIn) return 1;
                  return a.name.toLowerCase().compareTo(b.name.toLowerCase());
                });

                final totalClasses =
                    subjects.fold<int>(0, (sum, s) => sum + s.totalClasses);
                final presentClasses =
                    subjects.fold<int>(0, (sum, s) => sum + s.presentClasses);

                final overallPercent = totalClasses == 0
                    ? 0.0
                    : (presentClasses / totalClasses) * 100;

                return CustomScrollView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  slivers: [
                    _ProfileHeader(
                      userName: userName,
                      overallPercent: overallPercent,
                    ),
                    SliverToBoxAdapter(
                      child: _SummaryCard(
                        present: presentClasses,
                        total: totalClasses,
                        percent: overallPercent,
                      ),
                    ),
                    if (subjects.isNotEmpty)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(20, 28, 20, 12),
                          child: Text(
                            "Your Classes",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 140),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final subject = subjects[index];
                            final percent = subject.totalClasses == 0
                                ? 0.0
                                : subject.percentage;

                            final isInTimetable =
                                activeSubjectIds.contains(subject.id);

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _TapScale(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          SubjectHistoryPage(subject: subject),
                                    ),
                                  );
                                },
                                child: Opacity(
                                  opacity: isInTimetable ? 1.0 : 0.6,
                                  child: FullCardProgress(
                                    title: subject.name +
                                        (isInTimetable ? "" : " (Inactive)"),
                                    percent: percent,
                                    color: _colorFromPercentage(percent),
                                    icon: _iconForPercent(percent),
                                  ),
                                ),
                              ),
                            );
                          },
                          childCount: subjects.length,
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  // ---------------- COLOR LOGIC ----------------

  Color _colorFromPercentage(double percent) {
    final p = percent.clamp(0.0, 100.0);
    double hue;

    if (p <= 30) {
      hue = lerpDouble(0, 55, p / 30)!; // red → yellow
    } else if (p <= 55) {
      hue = lerpDouble(55, 210, (p - 30) / 25)!; // yellow → blue
    } else if (p <= 80) {
      hue = lerpDouble(210, 120, (p - 55) / 25)!; // blue → green
    } else {
      hue = 120;
    }

    return HSLColor.fromAHSL(
      1,
      hue,
      0.65,
      0.42,
    ).toColor();
  }

  IconData _iconForPercent(double p) {
    if (p < 60) return Icons.sentiment_very_dissatisfied;
    if (p < 75) return Icons.sentiment_dissatisfied;
    if (p < 90) return Icons.sentiment_satisfied;
    return Icons.sentiment_very_satisfied;
  }
}

/* ───────────────── PROFILE HEADER ───────────────── */
class _ProfileHeader extends StatelessWidget {
  final String userName;
  final double overallPercent;

  const _ProfileHeader({
    required this.userName,
    required this.overallPercent,
  });

  @override
  Widget build(BuildContext context) {
    final quote = DailyQuotes.getDailyQuote(overallPercent);
    final parts = userName.trim().split(RegExp(r'\s+'));
    final firstName = parts.isNotEmpty ? parts.first : '';
    final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
      sliver: SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Good Morning,", // Or "Hello,"
                      style: GoogleFonts.bricolageGrotesque(
                        color: HomePage.textSecondary,
                        fontSize: 14,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.bricolageGrotesque(
                          fontSize: 34,
                          height: 1.1,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -1.0,
                        ),
                        children: [
                          TextSpan(
                              text: firstName,
                              style: const TextStyle(color: Colors.white)),
                          if (lastName.isNotEmpty)
                            TextSpan(
                              text: " $lastName",
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.3)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                _CircleButton(
                  icon: Icons.settings_rounded,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SettingsPage()));
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Updated Quote styling
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: _AnimatedQuote(text: quote),
            ),
          ],
        ),
      ),
    );
  }
}

/* ───────────────── SUMMARY CARD ───────────────── */

class _SummaryCard extends StatelessWidget {
  final int present;
  final int total;
  final double percent;

  const _SummaryCard({
    required this.present,
    required this.total,
    required this.percent,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              _SummaryItem(
                label: "Attendance",
                value: "$present",
                subValue: "/$total classes",
              ),
              VerticalDivider(
                color: Colors.white.withValues(alpha: 0.1),
                thickness: 1,
                indent: 10,
                endIndent: 10,
              ),
              _SummaryItem(
                label: "Overall Score",
                value: "${percent.toInt()}%",
                isHighlighted: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final String? subValue;
  final bool isHighlighted;

  const _SummaryItem({
    required this.label,
    required this.value,
    this.subValue,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: GoogleFonts.bricolageGrotesque(
              color: HomePage.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.bricolageGrotesque(
              color: isHighlighted
                  ? Theme.of(context).primaryColor
                  : Colors.white, // Pop of color if high
              fontSize: 36,
              fontWeight: FontWeight.w700,
              letterSpacing: -1,
            ),
          ),
          if (subValue != null)
            Text(
              subValue!,
              style: GoogleFonts.bricolageGrotesque(
                color: HomePage.textSecondary.withValues(alpha: 0.6),
                fontSize: 11,
              ),
            ),
        ],
      ),
    );
  }
}

/* ───────────────── SUBJECT CARD ───────────────── */

class FullCardProgress extends StatelessWidget {
  final String title;
  final double percent;
  final Color color;
  final IconData icon;

  const FullCardProgress({
    super.key,
    required this.title,
    required this.percent,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Dim base
            Container(color: color.withValues(alpha: 0.35)),

            // Progress fill (curved)
            AnimatedFractionallySizedBox(
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              alignment: Alignment.centerLeft,
              widthFactor: (percent / 100).clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),

            Positioned(
              top: 12,
              left: 14,
              child: Text(
                title,
                style: GoogleFonts.bricolageGrotesque(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            Positioned(
              bottom: 12,
              left: 14,
              child: Icon(icon, size: 26, color: Colors.white),
            ),

            Positioned(
              bottom: 12,
              right: 14,
              child: Text(
                "${percent.toInt()}%",
                style: GoogleFonts.bricolageGrotesque(
                  color: Colors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ───────────────── QUOTE ANIMATION ───────────────── */

class _AnimatedQuote extends StatelessWidget {
  final String text;
  const _AnimatedQuote({required this.text});

  @override
  Widget build(BuildContext context) {
    // Split by space to keep words together
    final words = text.split(' ');

    return Wrap(
      spacing: 4.0, // Space between words
      runSpacing: 2.0, // Space between lines
      children: List.generate(words.length, (i) {
        return _DelayedFadeWord(
          word: words[i],
          delayMs: i * 80, // Slightly slower delay since it's words now
        );
      }),
    );
  }
}

class _DelayedFadeWord extends StatefulWidget {
  final String word;
  final int delayMs;

  const _DelayedFadeWord({
    required this.word,
    required this.delayMs,
  });

  @override
  State<_DelayedFadeWord> createState() => _DelayedFadeWordState();
}

class _DelayedFadeWordState extends State<_DelayedFadeWord> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      child: Text(
        widget.word,
        style: GoogleFonts.bricolageGrotesque(
          color: HomePage.textSecondary,
          fontSize: 15,
          height: 1.4,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}

/* ───────────────── TAP SCALE ───────────────── */

class _TapScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _TapScale({
    required this.child,
    required this.onTap,
  });

  @override
  State<_TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<_TapScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/* ───────────────── ICON BUTTON ───────────────── */
/* ───────────────── INTERACTIVE ICON BUTTON ───────────────── */
class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _TapScale(
      onTap: onTap,
      child: Container(
        width: 42, // Slightly larger for better touch target
        height: 42,
        decoration: BoxDecoration(
          color: const Color(0xFF1C1D21),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}
