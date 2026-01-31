import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/subject.dart';
import '../status/subject_history_page.dart';
import '../utils/daily_quotes.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static const Color bg = Color(0xFF0E0F11);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF9A9AA0);

  // TEMP: replace later with auth / profile data
  final String userName = "Neal Biju";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: ValueListenableBuilder(
          valueListenable: Hive.box<Subject>('subjects').listenable(),
          builder: (_, Box<Subject> box, __) {
            final subjects = box.values.toList();

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

                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 28, 20, 12),
                    child: Text(
                      "Your Classes",
                      style: TextStyle(
                        color: HomePage.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (context, index) {
                        final subject = subjects[index];
                        final percent = subject.totalClasses == 0
                            ? 0.0
                            : subject.percentage;

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
                            child: FullCardProgress(
                              title: subject.name,
                              percent: percent,
                              color: _colorFromPercentage(percent),
                              icon: _iconForPercent(percent),
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

    // ✅ SAFE name parsing (done inside build)
    final parts = userName.trim().split(RegExp(r'\s+'));
    final firstName = parts.isNotEmpty ? parts.first : '';
    final lastName =
    parts.length > 1 ? parts.sublist(1).join(' ') : '';

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      sliver: SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // NAME + ACTIONS
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        firstName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.bricolageGrotesque(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (lastName.isNotEmpty)
                        Text(
                          lastName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.bricolageGrotesque(
                            color: Colors.white,
                            fontSize: 32, // SAME SIZE
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                const _CircleButton(icon: Icons.notifications_none),
                const SizedBox(width: 8),
                const _CircleButton(icon: Icons.settings_outlined),
              ],
            ),

            const SizedBox(height: 16),

            // DAILY QUOTE
            _AnimatedQuote(text: quote),
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
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1D21),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            _SummaryItem(
              label: "Classes Attended",
              value: "$present",
            ),
            const VerticalDivider(
              color: Colors.white24,
              thickness: 1,
              width: 32,
            ),
            _SummaryItem(
              label: "Overall",
              value: "${percent.toInt()}%",
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryItem({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.bricolageGrotesque(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.bricolageGrotesque(
              color: HomePage.textSecondary,
              fontSize: 13,
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
    final chars = text.split('');

    return Wrap(
      children: List.generate(chars.length, (i) {
        return _DelayedFadeChar(
          char: chars[i],
          delayMs: i * 18,
        );
      }),
    );
  }
}

class _DelayedFadeChar extends StatefulWidget {
  final String char;
  final int delayMs;

  const _DelayedFadeChar({
    required this.char,
    required this.delayMs,
  });

  @override
  State<_DelayedFadeChar> createState() => _DelayedFadeCharState();
}

class _DelayedFadeCharState extends State<_DelayedFadeChar> {
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
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      child: Text(
        widget.char,
        style: GoogleFonts.bricolageGrotesque(
          color: HomePage.textSecondary,
          fontSize: 16,
          height: 1.3,
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

class _CircleButton extends StatelessWidget {
  final IconData icon;
  const _CircleButton({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFF1C1D21),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: Colors.white, size: 18),
    );
  }
}
