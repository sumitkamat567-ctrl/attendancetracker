import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../storage/local_storage.dart';
import '../notifications/reminder_service.dart';
import '../notifications/notification_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late bool _notificationsEnabled;
  late double _minAttendance;
  late bool _classroomMode;
  late bool _lowAttendanceAlerts;
  int _pendingNotifications = 0;

  @override
  void initState() {
    super.initState();
    // Load settings from storage
    _notificationsEnabled = LocalStorage.notificationsEnabled;
    _minAttendance = LocalStorage.targetAttendance;
    _classroomMode = LocalStorage.classroomMode;
    _lowAttendanceAlerts = LocalStorage.lowAttendanceAlerts;
    _loadPendingCount();
  }

  Future<void> _loadPendingCount() async {
    final count = await NotificationService.getPendingCount();
    if (mounted) setState(() => _pendingNotifications = count);
  }

  Future<void> _onNotificationsChanged(bool value) async {
    setState(() => _notificationsEnabled = value);
    await LocalStorage.setNotificationsEnabled(value);
    await ReminderService.rescheduleAll();
    await _loadPendingCount();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? '🔔 Notifications enabled! $_pendingNotifications reminders scheduled.'
                : '🔕 Notifications disabled',
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _onAttendanceChanged(double value) async {
    HapticFeedback.selectionClick();
    setState(() => _minAttendance = value);
  }

  Future<void> _onAttendanceChangeEnd(double value) async {
    await LocalStorage.setTargetAttendance(value);
    await ReminderService.rescheduleAll();
    await _loadPendingCount();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Target attendance set to ${value.round()}%'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _onClassroomModeChanged(bool value) async {
    setState(() => _classroomMode = value);
    await LocalStorage.setClassroomMode(value);
  }

  Future<void> _onLowAttendanceAlertsChanged(bool value) async {
    setState(() => _lowAttendanceAlerts = value);
    await LocalStorage.setLowAttendanceAlerts(value);
  }

  Future<void> _testNotification() async {
    await NotificationService.showTestNotification();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📤 Test notification sent!'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // Samarkan style for branding
  TextStyle get samarkanStyle => const TextStyle(
        fontFamily: 'Samarkan',
        color: Colors.white,
      );

  // Professional Palette - Matching Onboarding Accents
  static const Color _surface =
      Color(0xFF070B14); // Deeper dark from onboarding
  static const Color _card = Color(0xFF161616);
  static const Color _accent = Color(0xFF8B5CF6); // Unified Purple Accent

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
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              centerTitle: false,
              titlePadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Hazri",
                    style: samarkanStyle.copyWith(
                      fontSize: 32,
                      letterSpacing: 2,
                    ),
                  ),
                  Text(
                    "PREMIUM ASSISTANT",
                    style: GoogleFonts.jetBrainsMono(
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
                    child: Icon(Icons.settings_suggest_rounded,
                        size: 180, color: _accent.withValues(alpha: 0.05)),
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
                  trailing: _switch(_classroomMode, _onClassroomModeChanged),
                ),
                _buildTile(
                  title: "Smart Reminders",
                  desc: _notificationsEnabled
                      ? "$_pendingNotifications reminders scheduled (3 & 10 min before)"
                      : "Tap to enable class reminders",
                  icon: Icons.alarm_on_rounded,
                  trailing:
                      _switch(_notificationsEnabled, _onNotificationsChanged),
                ),
                _buildSectionHeader("Risk Management"),
                _buildTile(
                  title: "Shortage Alerts",
                  desc:
                      "Notify when attendance drops below ${_minAttendance.round()}%",
                  icon: Icons.warning_amber_rounded,
                  trailing: _switch(
                      _lowAttendanceAlerts, _onLowAttendanceAlertsChanged),
                ),
                const SizedBox(height: 32),
                _buildActionButton("Test Notification",
                    Icons.notifications_active_rounded, _testNotification),
                _buildActionButton(
                    "Reset Semester Data", Icons.delete_outline_rounded, () {
                  // TODO: Add confirmation dialog
                }, isDestructive: true),
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
        style: GoogleFonts.jetBrainsMono(
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
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Target Attendance",
                  style: GoogleFonts.bricolageGrotesque(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.w600)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: Text("${_minAttendance.round()}%",
                    style: GoogleFonts.jetBrainsMono(
                        color: _accent, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: _accent,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.05),
              thumbColor: Colors.white,
              trackHeight: 12,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            ),
            child: Slider(
              value: _minAttendance,
              min: 50,
              max: 100,
              onChanged: _onAttendanceChanged,
              onChangeEnd: _onAttendanceChangeEnd,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "All subjects below this % will show urgent reminders",
            style: GoogleFonts.bricolageGrotesque(
              fontSize: 12,
              color: Colors.white38,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(
      {required String title,
      required String desc,
      required IconData icon,
      required Widget trailing}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(24),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Icon(icon, color: Colors.white54),
        title: Text(title,
            style: GoogleFonts.bricolageGrotesque(
                color: Colors.white, fontWeight: FontWeight.w600)),
        subtitle: Text(desc,
            style: GoogleFonts.bricolageGrotesque(
                color: Colors.white30, fontSize: 13)),
        trailing: trailing,
      ),
    );
  }

  Widget _switch(bool val, Function(bool) onChanged) {
    return Switch.adaptive(
      value: val,
      activeTrackColor: _accent.withValues(alpha: 0.5),
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return _accent;
        return Colors.grey;
      }),
      onChanged: onChanged,
    );
  }

  Widget _buildActionButton(String label, IconData icon, VoidCallback onTap,
      {bool isDestructive = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
          decoration: BoxDecoration(
            border: Border.all(
                color: isDestructive
                    ? Colors.redAccent.withValues(alpha: 0.2)
                    : Colors.white10),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Icon(icon,
                  size: 20,
                  color: isDestructive ? Colors.redAccent : Colors.white70),
              const SizedBox(width: 12),
              Text(label,
                  style: GoogleFonts.bricolageGrotesque(
                      color: isDestructive ? Colors.redAccent : Colors.white70,
                      fontWeight: FontWeight.w600)),
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
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Column(
              children: [
                Text(
                  "CRAFTED WITH ❤️ BY",
                  style: GoogleFonts.jetBrainsMono(
                    color: Colors.white24,
                    fontSize: 10,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Summit Kamat",
                  style: GoogleFonts.bricolageGrotesque(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Neal Biju",
                  style: GoogleFonts.bricolageGrotesque(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "Hazri • v1.0.0",
            style: GoogleFonts.jetBrainsMono(
              color: Colors.white10,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "© 2026 All Rights Reserved",
            style: GoogleFonts.jetBrainsMono(
              color: Colors.white10,
              fontSize: 9,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}
