import 'package:flutter/material.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'core/theme/app_theme.dart';
import 'navigation/bottom_nav.dart';
import 'navigation/onboarding_page.dart';
import 'storage/local_storage.dart';
import 'notifications/notification_service.dart';
import 'notifications/reminder_service.dart';
import 'splash/hazri_splash.dart';

Future<void> main() async {
  // ✅ Preserve native splash until Flutter is ready
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // ✅ Initialize Hive local storage
  await LocalStorage.init();

  // ✅ Initialize notifications (required for Android 13+)
  await NotificationService.init();

  // ✅ Schedule class reminders
  await ReminderService.rescheduleAll();

  // ✅ Set highest available refresh rate
  await FlutterDisplayMode.setHighRefreshRate();

  // ✅ Remove native splash - Flutter splash takes over
  FlutterNativeSplash.remove();

  runApp(const RollCallApp());
}

class RollCallApp extends StatelessWidget {
  const RollCallApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,

      // 👇 SPLASH FIRST
      home: const HazriSplash(),

      // 👇 Routes
      routes: {
        '/home': (_) => const BottomNav(),
        '/onboarding': (_) => const HazriOnboarding(),
      },
    );
  }
}
