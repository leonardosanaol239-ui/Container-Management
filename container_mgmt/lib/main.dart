import 'package:flutter/material.dart';
import 'screens/landing_screen.dart';
import 'theme/app_theme.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().init();
  runApp(const ContainerMgmtApp());
}

class ContainerMgmtApp extends StatelessWidget {
  const ContainerMgmtApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gothong Southern Container Management',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const LandingScreen(),
    );
  }
}
