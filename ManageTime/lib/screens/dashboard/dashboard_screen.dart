import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  int _currentIndex = 2; // Default to Home (Tasks)
  String _currentUserName = 'User';
  bool _isDark = ThemeController.isDark;

  @override
  void initState() {
    super.initState();
    _currentUserName = widget.userName;
    _loadUserData();
    ThemeController.themeNotifier.addListener(_updateTheme);
  }

  void _updateTheme() {
    if (mounted) setState(() => _isDark = ThemeController.isDark);
  }

  @override
  void dispose() {
    ThemeController.themeNotifier.removeListener(_updateTheme);
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    String email = prefs.getString('user_email') ?? '';
    if (email.isNotEmpty) {
      // Đảm bảo load đúng dữ liệu cho user hiện tại
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

  void _showNotifications() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _isDark ? AppColors.cardBg : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Thông báo gần đây', style: TextStyle(color: _isDark ? Colors.white : Colors.black87, fontSize: 20, fontWeight: FontWeight.bold)),
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng')),
              ],
            ),
            const SizedBox(height: 20),
            _buildNotificationItem('Lịch họp sắp diễn ra', 'Cuộc họp Hội đồng Đường lối bắt đầu sau 10 phút.', '10:20 AM'),
            _buildNotificationItem('Nhiệm vụ chưa hoàn thành', 'Đừng quên hoàn thành báo cáo tiến độ hôm nay!', '08:00 AM'),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationItem(String title, String body, String time) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(color: _isDark ? AppColors.primary : Colors.blue, fontWeight: FontWeight.bold)),
              Text(time, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 4),
          Text(body, style: TextStyle(color: _isDark ? Colors.white70 : Colors.black54, fontSize: 13)),
        ],
      ),
    );
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
          if (index == 2) _loadUserData(); // Refresh home data
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
      case 2: return _buildHomeStack(); // Home Overview
      case 3: return const PomodoroTimerScreen();
      case 4: return SettingsScreen(userName: _currentUserName);
      default: return _buildHomeStack();
    }
  }

  Widget _buildHomeStack() {
    // Trả về TaskListScreen nhưng có thể thêm logic overlay header nếu cần
    // Hiện tại TaskListScreen đã chứa Header và 4 card thống kê.
    return const TaskListScreen();
  }
}