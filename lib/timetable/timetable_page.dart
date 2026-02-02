import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/timetable_slot.dart';
import '../models/subject.dart';
import 'add_course_page.dart';
import 'ai_import_page.dart';
import 'timetable_image_preview_page.dart';
import '../notifications/reminder_service.dart';

class TimetablePage extends StatefulWidget {
  const TimetablePage({super.key});

  @override
  State<TimetablePage> createState() => _TimetablePageState();
}

class _TimetablePageState extends State<TimetablePage> {
  final ImagePicker _picker = ImagePicker();
  static const Color _surfaceBackground = Color(0xFF121212);

  /* ───────────────── DISCOVERY DIALOG LOGIC ───────────────── */

  Future<void> _showDiscoveryDialog() async {
    HapticFeedback.heavyImpact();

    final bool? proceed = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Discovery",
      barrierColor: Colors.black.withValues(alpha: 0.9),
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (context, anim1, anim2) => _DiscoveryDialog(
        onProceed: () => Navigator.pop(context, true),
      ),
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
            child: child,
          ),
        );
      },
    );

    if (proceed == true) {
      _pickTimetableImage();
    }
  }

  Future<void> _pickTimetableImage() async {
    final image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 95);
    if (image == null || !mounted) return;
    HapticFeedback.mediumImpact();
    Navigator.push(context, MaterialPageRoute(builder: (_) => TimetableImagePreviewPage(imageFile: File(image.path))));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surfaceBackground,
      body: SafeArea(
        bottom: false,
        child: ValueListenableBuilder(
          valueListenable: Hive.box<TimetableSlot>('timetable').listenable(),
          builder: (context, Box<TimetableSlot> timetableBox, _) {
            if (timetableBox.isEmpty) {
              return _EmptyState(onScan: _showDiscoveryDialog);
            }
            return _TimetableContent(
              timetableBox: timetableBox,
              onScan: _showDiscoveryDialog,
            );
          },
        ),
      ),
    );
  }
}

/* ───────────────── SCROLLABLE CONTENT WITH PINNED HEADER ───────────────── */

class _TimetableContent extends StatelessWidget {
  final Box<TimetableSlot> timetableBox;
  final VoidCallback onScan;

  const _TimetableContent({required this.timetableBox, required this.onScan});

  @override
  Widget build(BuildContext context) {
    final subjectBox = Hive.box<Subject>('subjects');
    final slots = timetableBox.values.toList();

    slots.sort((a, b) {
      int dayComp = a.weekday.compareTo(b.weekday);
      if (dayComp != 0) return dayComp;
      return a.startTime.compareTo(b.startTime);
    });

    return Stack(
      children: [
        NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                pinned: true,
                floating: false,
                backgroundColor: const Color(0xFF121212),
                elevation: 0,
                scrolledUnderElevation: 0,
                toolbarHeight: 80,
                flexibleSpace: FlexibleSpaceBar(
                  expandedTitleScale: 1.0,
                  titlePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Schedules",
                        style: GoogleFonts.bricolageGrotesque(
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -1.2,
                        ),
                      ),
                      _TopActionIcon(
                        icon: Icons.auto_awesome,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AIImportTimetablePage())),
                      ),
                    ],
                  ),
                ),
              ),
            ];
          },
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                  child: Text(
                    "You have ${slots.length} sessions organized for this week. Swipe any card to modify or remove an entry.",
                    style: GoogleFonts.bricolageGrotesque(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: Colors.white38,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 240),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      final slot = slots[index];
                      final subject = subjectBox.get(slot.subjectId);
                      bool showDayHeader = index == 0 || slots[index - 1].weekday != slot.weekday;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showDayHeader) _DayHeader(day: slot.weekday),
                          _DismissibleTile(
                            slot: slot,
                            subjectName: subject?.name ?? "Unknown",
                          ),
                          const SizedBox(height: 12),
                        ],
                      );
                    },
                    childCount: slots.length,
                  ),
                ),
              ),
            ],
          ),
        ),
        _FloatingActionDock(onScan: onScan, onClear: () => _handleClear(context)),
      ],
    );
  }

  void _handleClear(BuildContext context) async {
    HapticFeedback.vibrate();
    final clear = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AppleSheet(
        title: "Clear Schedule",
        message: "This will permanently remove all entries.",
        confirmLabel: "Clear All",
        isDestructive: true,
      ),
    );
    if (clear == true) {
      timetableBox.clear();
      ReminderService.rescheduleAll();
      HapticFeedback.lightImpact();
    }
  }
}

/* ───────────────── PREMIUM DISCOVERY DIALOG ───────────────── */

class _DiscoveryDialog extends StatelessWidget {
  final VoidCallback onProceed;
  const _DiscoveryDialog({required this.onProceed});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 30),
        padding: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF818CF8),
              const Color(0xFF818CF8).withValues(alpha: 0),
              const Color(0xFF818CF8),
            ],
          ),
        ),
        child: Material( // <--- THIS IS THE FIX
          color: const Color(0xFF161618),
          borderRadius: BorderRadius.circular(31),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Beta Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF818CF8).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: const Color(0xFF818CF8).withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    "BETA ACCESS",
                    style: GoogleFonts.bricolageGrotesque(
                      color: const Color(0xFF818CF8),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                // Icon Glow
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF818CF8).withValues(alpha: 0.35),
                            blurRadius: 50,
                            spreadRadius: 10,
                          )
                        ],
                      ),
                    ),
                    const Icon(Icons.auto_awesome_rounded, size: 52, color: Colors.white),
                  ],
                ),
                const SizedBox(height: 28),
                Text(
                  "Vision Import",
                  style: GoogleFonts.bricolageGrotesque(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Experience surgical precision. Upload a photo of your schedule and watch our neural engine build your entire week in seconds.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.bricolageGrotesque(
                    fontSize: 16,
                    color: Colors.white38,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 36),
                _DiscoveryButton(label: "Try it Now", onTap: onProceed),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    "Maybe later",
                    style: GoogleFonts.bricolageGrotesque(
                      color: Colors.white24,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DiscoveryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _DiscoveryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Material( // Wrap in Material to ensure clean button text
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        elevation: 8,
        shadowColor: Colors.white.withValues(alpha: 0.15),
        child: Container(
          width: double.infinity,
          height: 60,
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.bricolageGrotesque(
              color: Colors.black,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _TopActionIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _TopActionIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); onTap(); },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Icon(icon, color: const Color(0xFF818CF8), size: 18),
      ),
    );
  }
}

class _DismissibleTile extends StatelessWidget {
  final TimetableSlot slot;
  final String subjectName;
  const _DismissibleTile({required this.slot, required this.subjectName});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(slot.key),
      direction: DismissDirection.horizontal,
      background: _SwipeAction(
          color: const Color(0xFF34C759),
          icon: Icons.edit_rounded,
          label: "Edit",
          align: Alignment.centerLeft
      ),
      secondaryBackground: _SwipeAction(
          color: const Color(0xFFFF3B30),
          icon: Icons.delete_rounded,
          label: "Delete",
          align: Alignment.centerRight
      ),
      confirmDismiss: (dir) async {
        if (dir == DismissDirection.startToEnd) {
          HapticFeedback.lightImpact();
          Navigator.push(context, MaterialPageRoute(builder: (_) => AddCoursePage(existingSlot: slot)));
          return false;
        }
        HapticFeedback.vibrate();
        return await showModalBottomSheet<bool>(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (_) => const _AppleSheet(title: "Delete Entry", message: "Remove this class from schedule?", confirmLabel: "Delete", isDestructive: true),
        );
      },
        onDismissed: (_) {
          slot.delete();
          ReminderService.rescheduleAll();
        },
        child: _CourseTile(slot: slot, name: subjectName),
    );
  }
}

class _CourseTile extends StatelessWidget {
  final TimetableSlot slot;
  final String name;
  const _CourseTile({required this.slot, required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: GoogleFonts.bricolageGrotesque(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.access_time_filled_rounded, size: 14, color: Color(0xFF818CF8)),
                    const SizedBox(width: 8),
                    Text("${slot.startTime} — ${slot.endTime}", style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white38)),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.unfold_more_rounded, color: Colors.white10, size: 20),
        ],
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  final int day;
  const _DayHeader({required this.day});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12, left: 4),
      child: Text(_weekdayName(day).toUpperCase(), style: GoogleFonts.bricolageGrotesque(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFF818CF8), letterSpacing: 1.2)),
    );
  }
}

class _FloatingActionDock extends StatelessWidget {
  final VoidCallback onScan, onClear;
  const _FloatingActionDock({required this.onScan, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 40, 20, 40),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [const Color(0xFF121212).withValues(alpha: 0), const Color(0xFF121212)],
          ),
        ),
        child: Row(
          children: [
            _SmallActionBtn(icon: Icons.delete_outline_rounded, color: const Color(0xFFFF3B30), onTap: onClear),
            const SizedBox(width: 12),
            Expanded(child: _LargeActionBtn(label: "Add Class", icon: Icons.add_rounded, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddCoursePage())))),
            const SizedBox(width: 12),
            _SmallActionBtn(icon: Icons.camera_alt_rounded, color: Colors.white, onTap: onScan),
          ],
        ),
      ),
    );
  }
}

class _LargeActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _LargeActionBtn({required this.label, required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); onTap(); },
      child: Container(
        height: 60,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: Colors.black, size: 20), const SizedBox(width: 10), Text(label, style: GoogleFonts.bricolageGrotesque(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.black))]),
      ),
    );
  }
}

class _SmallActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _SmallActionBtn({required this.icon, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { HapticFeedback.mediumImpact(); onTap(); },
      child: Container(height: 60, width: 60, decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: 0.05))), child: Icon(icon, color: color, size: 22)),
    );
  }
}

class _AppleSheet extends StatelessWidget {
  final String title, message, confirmLabel;
  final bool isDestructive;
  const _AppleSheet({required this.title, required this.message, required this.confirmLabel, this.isDestructive = false});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: double.infinity, decoration: BoxDecoration(color: const Color(0xFF2C2C2E), borderRadius: BorderRadius.circular(16)), child: Column(children: [
          Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Column(children: [Text(title, style: GoogleFonts.bricolageGrotesque(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white38)), const SizedBox(height: 4), Text(message, style: GoogleFonts.bricolageGrotesque(fontSize: 12, color: Colors.white38))])),
          const Divider(height: 1, color: Colors.white10),
          TextButton(onPressed: () => Navigator.pop(context, true), child: SizedBox(width: double.infinity, child: Center(child: Text(confirmLabel, style: GoogleFonts.bricolageGrotesque(fontSize: 18, color: isDestructive ? const Color(0xFFFF453A) : const Color(0xFF0A84FF))))))
        ])),
        const SizedBox(height: 12),
        Container(width: double.infinity, decoration: BoxDecoration(color: const Color(0xFF2C2C2E), borderRadius: BorderRadius.circular(16)), child: TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel", style: GoogleFonts.bricolageGrotesque(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white))))
      ]),
    );
  }
}

class _SwipeAction extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final Alignment align;
  const _SwipeAction({required this.color, required this.icon, required this.label, required this.align});
  @override
  Widget build(BuildContext context) {
    return Container(
        alignment: align,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 4),
            Text(label, style: GoogleFonts.bricolageGrotesque(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12))
          ],
        )
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onScan;
  const _EmptyState({required this.onScan});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 15),
              // Header Row with Top Action Icon
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Schedules",
                    style: GoogleFonts.bricolageGrotesque(
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -1.2,
                    ),
                  ),
                  _TopActionIcon(
                    icon: Icons.auto_awesome,
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AIImportTimetablePage())
                    ),
                  ),
                ],
              ),
              const Spacer(flex: 2),
              // Visual Centerpiece
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.02),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome_rounded, size: 64, color: Colors.white10),
              ),
              const SizedBox(height: 24),
              Text(
                "No classes yet",
                style: GoogleFonts.bricolageGrotesque(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Start building your week by adding a class manually or using our AI Vision import.",
                textAlign: TextAlign.center,
                style: GoogleFonts.bricolageGrotesque(
                    color: Colors.white30,
                    fontSize: 15,
                    height: 1.5
                ),
              ),
              const Spacer(flex: 3),
            ],
          ),
        ),
        // Bottom Action Dock
        _FloatingActionDock(
          onScan: onScan,
          onClear: () {
            HapticFeedback.vibrate();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Schedule is already empty")),
            );
          },
        ),
      ],
    );
  }
}

String _weekdayName(int day) {
  const days = ["", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];
  return (day >= 1 && day < days.length) ? days[day] : "";
}