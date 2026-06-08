import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/constants.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final String? savedName = prefs.getString('user_name');

  runApp(FocusFlowApp(initialScreen: savedName != null
      ? DashboardScreen(userName: savedName)
      : const AuthScreen()));
}

class FocusFlowApp extends StatefulWidget {
  final Widget initialScreen;
  const FocusFlowApp({super.key, required this.initialScreen});

  @override
  State<FocusFlowApp> createState() => _FocusFlowAppState();
}

class _FocusFlowAppState extends State<FocusFlowApp> {
  bool _isDarkTheme = true;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  void _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkTheme = prefs.getBool('is_dark_theme') ?? true;
      ThemeController.isDark = _isDarkTheme;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FocusFlow',
      theme: ThemeData(
        brightness: _isDarkTheme ? Brightness.dark : Brightness.light,
        scaffoldBackgroundColor: _isDarkTheme ? AppColors.background : Colors.grey.shade100,
      ),
      home: widget.initialScreen,
    );
  }
}

class ThemeController {
  static Function(bool)? onThemeChanged;
  static bool isDark = true;
}