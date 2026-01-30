import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'navigation/bottom_nav.dart';
import 'storage/local_storage.dart';
import 'notifications/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Initialize Hive local storage
  await LocalStorage.init();

  // ✅ Initialize notifications (required for Android 13+)
  await NotificationService.init();

  runApp(const RollCallApp());
}

class RollCallApp extends StatelessWidget {
  const RollCallApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const BottomNav(),
    );
  }
}
