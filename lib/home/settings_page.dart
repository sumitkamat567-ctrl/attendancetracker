import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;
  double _minAttendance = 75.0;
  bool _classroomMode = true;
  bool _lowAttendanceAlerts = true;

  // Professional Palette
  static const Color _surface = Color(0xFF0A0A0A);
  static const Color _card = Color(0xFF161616);
  static const Color _accent = Colors.indigoAccent;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            stretch: true,
            backgroundColor: _surface,
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              centerTitle: false,
              titlePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Hazri",
                    style: GoogleFonts.bricolageGrotesque(
                      fontWeight: FontWeight.w900,
                      fontSize: 28,
                      letterSpacing: -1.5,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    "PREMIUM ASSISTANT",
                    style: GoogleFonts.jetBrainsMono( // FIXED: Capital B
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      color: _accent,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
              background: Stack(
                children: [
                  Positioned(
                    right: -20,
                    top: 40,
                    child: Icon(Icons.school_rounded,
                        size: 180,
                        color: Colors.white.withValues(alpha: 0.03) // FIXED: withValues
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildSectionHeader("Academic Standards"),
                _buildAttendanceCard(),

                _buildSectionHeader("Automation & Utility"),
                _buildTile(
                  title: "Classroom Mode",
                  desc: "Auto-mute device during ongoing classes",
                  icon: Icons.do_not_disturb_on_rounded,
                  trailing: _switch(_classroomMode, (v) => setState(() => _classroomMode = v)),
                ),
                _buildTile(
                  title: "Smart Reminders",
                  desc: "Get pinged before your lecture starts",
                  icon: Icons.alarm_on_rounded,
                  trailing: _switch(_notificationsEnabled, (v) => setState(() => _notificationsEnabled = v)),
                ),

                _buildSectionHeader("Risk Management"),
                _buildTile(
                  title: "Shortage Alerts",
                  desc: "Notify when attendance drops below ${_minAttendance.round()}%",
                  icon: Icons.warning_amber_rounded,
                  trailing: _switch(_lowAttendanceAlerts, (v) => setState(() => _lowAttendanceAlerts = v)),
                ),

                const SizedBox(height: 32),
                _buildActionButton("Export Attendance Report (PDF)", Icons.ios_share_rounded, () {}),
                _buildActionButton("Reset Semester Data", Icons.delete_outline_rounded, () {}, isDestructive: true),

                const SizedBox(height: 60),
                _buildLegalFooter(),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 32, 8, 12),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.jetBrainsMono( // FIXED: Capital B
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white24,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildAttendanceCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)), // FIXED: withValues
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Target Attendance",
                  style: GoogleFonts.bricolageGrotesque(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w600)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.1), // FIXED: withValues
                    borderRadius: BorderRadius.circular(8)
                ),
                child: Text("${_minAttendance.round()}%",
                    style: GoogleFonts.jetBrainsMono(color: _accent, fontWeight: FontWeight.bold)), // FIXED: Capital B
              ),
            ],
          ),
          const SizedBox(height: 20),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: _accent,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.05), // FIXED: withValues
              thumbColor: Colors.white,
              trackHeight: 12,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            ),
            child: Slider(
              value: _minAttendance,
              min: 50,
              max: 100,
              onChanged: (v) {
                HapticFeedback.selectionClick();
                setState(() => _minAttendance = v);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile({required String title, required String desc, required IconData icon, required Widget trailing}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(24),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Icon(icon, color: Colors.white54),
        title: Text(title, style: GoogleFonts.bricolageGrotesque(color: Colors.white, fontWeight: FontWeight.w600)),
        subtitle: Text(desc, style: GoogleFonts.bricolageGrotesque(color: Colors.white30, fontSize: 13)),
        trailing: trailing,
      ),
    );
  }

  Widget _switch(bool val, Function(bool) onChanged) {
    return Switch.adaptive(
      value: val,
      activeTrackColor: _accent.withValues(alpha: 0.5), // FIXED: activeTrackColor
      activeColor: _accent, // This sets the thumb color in adaptive mode
      onChanged: onChanged,
    );
  }

  Widget _buildActionButton(String label, IconData icon, VoidCallback onTap, {bool isDestructive = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
          decoration: BoxDecoration(
            border: Border.all(color: isDestructive
                ? Colors.redAccent.withValues(alpha: 0.2)
                : Colors.white10), // FIXED: withValues
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: isDestructive ? Colors.redAccent : Colors.white70),
              const SizedBox(width: 12),
              Text(label, style: GoogleFonts.bricolageGrotesque(
                  color: isDestructive ? Colors.redAccent : Colors.white70,
                  fontWeight: FontWeight.w600
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegalFooter() {
    return Center(
      child: Column(
        children: [
          Text("Sir Ji Mobile • v1.0.0",
              style: GoogleFonts.jetBrainsMono(color: Colors.white10, fontSize: 10)), // FIXED: Capital B
          const SizedBox(height: 4),
          Text("TERMS OF SERVICE • PRIVACY POLICY",
              style: GoogleFonts.jetBrainsMono(color: Colors.white10, fontSize: 9, letterSpacing: 1)), // FIXED: Capital B
        ],
      ),
    );
  }
}