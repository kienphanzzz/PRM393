import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:manage_time/core/constants.dart';
import 'package:manage_time/main.dart';
import 'package:manage_time/data/models/task_model.dart';
import 'package:manage_time/data/models/session_model.dart';
import 'package:manage_time/data/models/event_model.dart';

// Import screens
import 'package:manage_time/screens/dashboard/settings_screen.dart';
import 'package:manage_time/screens/calendar/calendar_view_screen.dart';
import 'package:manage_time/screens/pomodoro/pomodoro_timer_screen.dart';
import 'package:manage_time/screens/analytics/history_analytics_screen.dart';
import 'package:manage_time/screens/task/task_list_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String userName;
  const DashboardScreen({super.key, this.userName = 'User'});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 2;
  String _currentUserName = 'User';
  bool _isDark = ThemeController.isDark;
  Timer? _deepLinkTimer;

  @override
  void initState() {
    super.initState();
    _currentUserName = widget.userName;
    _loadUserData();
    ThemeController.themeNotifier.addListener(_updateTheme);
    
    // Check deep link từ notification mỗi 400ms để nhảy tab Focus
    _deepLinkTimer = Timer.periodic(const Duration(milliseconds: 400), (timer) {
      if (ThemeController.requestToFocus) {
        ThemeController.requestToFocus = false;
        if (mounted && _currentIndex != 3) {
          setState(() {
            _currentIndex = 3; // Chuyển sang tab Focus (Pomodoro)
          });
        }
      }
    });
  }

  void _updateTheme() {
    if (mounted) setState(() => _isDark = ThemeController.isDark);
  }

  @override
  void dispose() {
    _deepLinkTimer?.cancel();
    ThemeController.themeNotifier.removeListener(_updateTheme);
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    String email = prefs.getString('user_email') ?? '';
    if (email.isNotEmpty) {
      await TaskStorage.init(email);
      await HistoryStorage.init(email);
      await EventStorage.init(email);
    }
    
    if (mounted) {
      setState(() {
        _currentUserName = prefs.getString('user_name') ?? widget.userName;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDark ? AppColors.background : const Color(0xFFF8F9FA),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
          if (index == 2) _loadUserData(); 
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: _isDark ? AppColors.cardBg : Colors.white,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textMuted,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.history_rounded), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month_rounded), label: 'Calendar'),
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.timer_rounded), label: 'Focus'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: 'Settings'),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0: return const HistoryAnalyticsScreen();
      case 1: return const CalendarViewScreen();
      case 2: return const TaskListScreen(); 
      case 3: return const PomodoroTimerScreen();
      case 4: return SettingsScreen(userName: _currentUserName);
      default: return const TaskListScreen();
    }
  }
}