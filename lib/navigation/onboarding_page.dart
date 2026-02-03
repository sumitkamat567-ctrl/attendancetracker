import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../storage/local_storage.dart';
import '../notifications/notification_service.dart';
import 'bottom_nav.dart';

class HazriOnboarding extends StatefulWidget {
  const HazriOnboarding({super.key});

  @override
  State<HazriOnboarding> createState() => _HazriOnboardingState();
}

class _HazriOnboardingState extends State<HazriOnboarding> {
  final PageController _controller = PageController();
  final TextEditingController _firstController = TextEditingController();
  final TextEditingController _middleController = TextEditingController();

  final Color primaryPurple = const Color(0xFF8B5CF6);
  final Color darkBg = const Color(0xFF070B14);

  // Permission states
  bool _notificationGranted = false;
  bool _alarmGranted = false;
  bool _isCheckingPermissions = true;

  // Samarkan for branding, Bricolage for reading
  TextStyle get samarkanStyle =>
      const TextStyle(fontFamily: 'Samarkan', color: Colors.white);
  TextStyle get bricolageStyle =>
      GoogleFonts.bricolageGrotesque(color: Colors.white);

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final notifEnabled = await NotificationService.areNotificationsEnabled();
    final alarmEnabled = await NotificationService.canScheduleExactAlarms();

    setState(() {
      _notificationGranted = notifEnabled;
      _alarmGranted = alarmEnabled;
      _isCheckingPermissions = false;
    });
  }

  Future<void> _requestNotificationPermission() async {
    final granted = await NotificationService.requestNotificationPermission();
    setState(() => _notificationGranted = granted);
  }

  Future<void> _requestAlarmPermission() async {
    // Mark that user explicitly requested alarm permission
    await LocalStorage.setAlarmPermissionRequested(true);
    await NotificationService.requestExactAlarmPermission();
    // Re-check after user returns from settings
    await _checkPermissions();
  }

  Future<void> _requestAllPermissions() async {
    await _requestNotificationPermission();
    await _requestAlarmPermission();
  }

  void _nextPage() {
    _controller.nextPage(
      duration: const Duration(milliseconds: 800),
      curve: Curves.fastLinearToSlowEaseIn,
    );
  }

  Future<void> _completeSetup() async {
    String fullName =
        "${_firstController.text} ${_middleController.text}".trim();
    if (fullName.isEmpty) fullName = "Hazri User";

    await LocalStorage.settingsBox.put('userName', fullName);
    await LocalStorage.settingsBox.put('isSetupDone', true);

    if (mounted) {
      // Trigger a simple custom transition to Home
      Navigator.pushAndRemoveUntil(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const BottomNav(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 1000),
        ),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBg,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Background "Deep Space" Particles
          ...List.generate(5, (index) => _BackgroundParticle(index: index)),

          PageView(
            controller: _controller,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildOverview(),
              _buildPrivacyAndNotifications(),
              _buildIdentityStage(),
            ],
          ),
        ],
      ),
    );
  }

  // --- STAGE 1: OVERVIEW ---
  Widget _buildOverview() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _SlideFade(
            delay: 100,
            child: Icon(Icons.auto_awesome_rounded,
                size: 80, color: primaryPurple),
          ),
          const SizedBox(height: 20),
          _SlideFade(
            delay: 300,
            child: Text("HAZRI",
                style: samarkanStyle.copyWith(
                    fontSize: 80, color: primaryPurple, letterSpacing: 2)),
          ),
          _SlideFade(
            delay: 500,
            child: Text("Presence, Perfected.",
                style: bricolageStyle.copyWith(
                    fontSize: 18, color: Colors.white38, letterSpacing: 1.2)),
          ),
          const SizedBox(height: 100),
          _SlideFade(
            delay: 800,
            child: _purpleButton("Begin Journey", _nextPage),
          ),
        ],
      ),
    );
  }

  // --- STAGE 2: PERMISSIONS ---
  Widget _buildPrivacyAndNotifications() {
    final bool allPermissionsGranted = _notificationGranted && _alarmGranted;

    return Padding(
      padding: const EdgeInsets.all(30.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("PERMISSIONS",
              style: bricolageStyle.copyWith(
                  color: primaryPurple,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2)),
          const SizedBox(height: 10),
          Text("Allow Access",
              style: bricolageStyle.copyWith(
                  fontSize: 40, fontWeight: FontWeight.w800, height: 1.1)),
          const SizedBox(height: 15),
          Text(
              "Hazri needs permission to send class reminders and schedule alarms. Your data stays on this device.",
              style:
                  bricolageStyle.copyWith(color: Colors.white54, fontSize: 16)),
          const SizedBox(height: 40),
          if (_isCheckingPermissions)
            const Center(child: CircularProgressIndicator())
          else ...[
            _PermissionCard(
              title: "Notifications",
              subtitle: "Get reminders before each class",
              icon: Icons.notifications_active_outlined,
              primaryColor: primaryPurple,
              isGranted: _notificationGranted,
              onRequest: _requestNotificationPermission,
            ),
            const SizedBox(height: 16),
            _PermissionCard(
              title: "Alarms & Reminders",
              subtitle: "Schedule exact class alerts",
              icon: Icons.alarm_rounded,
              primaryColor: primaryPurple,
              isGranted: _alarmGranted,
              onRequest: _requestAlarmPermission,
            ),
          ],
          const SizedBox(height: 40),
          if (!allPermissionsGranted) ...[
            _purpleButton("Grant All Permissions", _requestAllPermissions),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: _nextPage,
                child: Text(
                  "Skip for now",
                  style: bricolageStyle.copyWith(
                      color: Colors.white38, fontSize: 14),
                ),
              ),
            ),
          ] else
            _purpleButton("Continue", _nextPage),
        ],
      ),
    );
  }

  // --- STAGE 3: IDENTITY ---
  Widget _buildIdentityStage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30.0),
      child: Column(
        children: [
          const SizedBox(height: 120),
          Text("NAMASTE",
              style:
                  samarkanStyle.copyWith(fontSize: 50, color: primaryPurple)),
          const SizedBox(height: 10),
          Text("Introduce yourself",
              style:
                  bricolageStyle.copyWith(fontSize: 18, color: Colors.white38)),
          const SizedBox(height: 60),
          _customInput("First Name", _firstController),
          const SizedBox(height: 30),
          _customInput("Middle Name (Optional)", _middleController),
          const SizedBox(height: 80),
          _purpleButton("Enter Hazri", _completeSetup),
        ],
      ),
    );
  }

  // --- REUSABLE WIDGETS ---

  Widget _purpleButton(String text, VoidCallback onPressed) {
    return Container(
      width: double.infinity,
      height: 65,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
              color: primaryPurple.withValues(alpha: 0.2),
              blurRadius: 25,
              offset: const Offset(0, 10)),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryPurple,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
        ),
        child: Text(text,
            style: bricolageStyle.copyWith(
                fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _customInput(String hint, TextEditingController ctrl) {
    return TextField(
      controller: ctrl,
      style: bricolageStyle.copyWith(fontSize: 22),
      cursorColor: primaryPurple,
      decoration: InputDecoration(
        labelText: hint,
        labelStyle:
            bricolageStyle.copyWith(color: Colors.white24, fontSize: 16),
        floatingLabelStyle: bricolageStyle.copyWith(color: primaryPurple),
        enabledBorder:
            UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
        focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: primaryPurple, width: 2)),
      ),
    );
  }
}

// --- CRAZY ANIMATION COMPONENTS ---

class _SlideFade extends StatelessWidget {
  final Widget child;
  final int delay;
  const _SlideFade({required this.child, required this.delay});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 800 + delay),
      curve: Curves.easeOutExpo,
      builder: (context, double value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 50 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _PermissionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color primaryColor;
  final bool isGranted;
  final VoidCallback onRequest;

  const _PermissionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.primaryColor,
    required this.isGranted,
    required this.onRequest,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isGranted
            ? primaryColor.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: isGranted
              ? primaryColor.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isGranted
                  ? primaryColor.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: isGranted ? primaryColor : Colors.white54,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.bricolageGrotesque(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.bricolageGrotesque(
                    color: Colors.white38,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (isGranted)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF34C759).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Color(0xFF34C759),
                size: 20,
              ),
            )
          else
            GestureDetector(
              onTap: onRequest,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "Allow",
                  style: GoogleFonts.bricolageGrotesque(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BackgroundParticle extends StatefulWidget {
  final int index;
  const _BackgroundParticle({required this.index});

  @override
  State<_BackgroundParticle> createState() => _BackgroundParticleState();
}

class _BackgroundParticleState extends State<_BackgroundParticle>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: Duration(seconds: 5 + widget.index))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Positioned(
          top: 100.0 + (widget.index * 150) * _ctrl.value,
          left: 50.0 + (widget.index * 60) * (1 - _ctrl.value),
          child: Container(
            width: 100 + (widget.index * 20),
            height: 100 + (widget.index * 20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
