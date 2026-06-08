import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../main.dart';
import '../../data/models/task_model.dart';
import '../../data/models/event_model.dart';
import 'settings_screen.dart';
import '../task/task_detail_screen.dart';
import '../calendar/calendar_view_screen.dart';
import '../pomodoro/pomodoro_timer_screen.dart';
import '../analytics/history_analytics_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String userName;
  const DashboardScreen({super.key, this.userName = 'User'});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  late String _timeString;
  late String _dateString;
  late Timer _timer;
  bool _isDarkView = ThemeController.isDark;

  @override
  void initState() {
    super.initState();
    _timeString = DateFormat('HH:mm:ss').format(DateTime.now());
    _dateString = DateFormat('EEEE, MMM dd, yyyy').format(DateTime.now());
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) => _updateTime());
    ThemeController.onThemeChanged = (bool isDark) {
      setState(() {
        _isDarkView = isDark;
      });
    };
  }

  void _updateTime() {
    final DateTime now = DateTime.now();
    setState(() {
      _timeString = DateFormat('HH:mm:ss').format(now);
      _dateString = DateFormat('EEEE, MMM dd, yyyy').format(now);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void refreshData() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    Color currentBg = _isDarkView ? AppColors.background : Colors.grey.shade100;
    Color currentTextColor = _isDarkView ? Colors.white : Colors.black87;
    Color currentCardBg = _isDarkView ? AppColors.cardBg : Colors.white;

    final List<Widget> _screens = [
      _buildHomeScreenView(currentTextColor, currentCardBg),
      _buildDedicatedTasksView(currentTextColor, currentCardBg),
      const PomodoroTimerScreen(),
      const CalendarViewScreen(),
      const HistoryAnalyticsScreen(),
    ];

    return Scaffold(
      backgroundColor: currentBg,
      body: SafeArea(
        child: _screens[_currentIndex],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: currentCardBg,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textMuted,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'Tasks'),
          BottomNavigationBarItem(icon: Icon(Icons.hourglass_empty), label: 'Focus'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: 'Calendar'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
        ],
      ),
    );
  }

  Widget _buildHomeScreenView(Color textColor, Color cardBg) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hello, ${widget.userName}!', style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text('$_dateString | $_timeString', style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w500)),
                ],
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => SettingsScreen(userName: widget.userName)),
                  );
                },
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: cardBg,
                  child: Icon(Icons.person, color: textColor, size: 24),
                ),
              )
            ],
          ),
          const SizedBox(height: 24),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.2,
            children: [
              _buildStatCard(Icons.check_circle_outline, 'Tasks', '${TaskStorage.todoTasks.length} pending', Colors.blue, cardBg, textColor),
              _buildStatCard(Icons.shutter_speed, 'Focus', '2h 15m today', Colors.purple, cardBg, textColor),
              _buildStatCard(Icons.calendar_today, 'Events', '${EventStorage.todayEvents.length} upcoming', Colors.green, cardBg, textColor),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        CircleAvatar(radius: 18, backgroundColor: Colors.orange.withValues(alpha: 0.15), child: const Icon(Icons.trending_up, color: Colors.orange, size: 20)),
                        const Text('78%', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Progress', style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: const LinearProgressIndicator(
                            value: 0.78,
                            backgroundColor: Colors.white10,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                            minHeight: 6,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text('78% weekly goal achieved', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                      ],
                    )
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Today's Lịch trình tổng hợp", style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () {
                  setState(() {
                    _currentIndex = 1;
                  });
                },
                child: const Text('View all', style: TextStyle(color: AppColors.primary)),
              )
            ],
          ),
          const SizedBox(height: 10),

          Text('📅 LỊCH TRÌNH SỰ KIỆN', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 8),
          EventStorage.todayEvents.isEmpty
              ? Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: const Text("Không có sự kiện nào sắp diễn ra", style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          )
              : ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: EventStorage.todayEvents.length,
            itemBuilder: (context, index) {
              final event = EventStorage.todayEvents[index];
              IconData eventIcon = Icons.event;
              Color iconColor = Colors.green;
              if (event.type == 'Meeting') { eventIcon = Icons.groups; iconColor = Colors.indigo; }
              if (event.type == 'Fitness') { eventIcon = Icons.fitness_center; iconColor = Colors.orange; }
              if (event.type == 'Deadline') { eventIcon = Icons.notification_important; iconColor = Colors.redAccent; }

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  leading: CircleAvatar(
                    radius: 20,
                    backgroundColor: iconColor.withValues(alpha: 0.15),
                    child: Icon(eventIcon, color: iconColor, size: 18),
                  ),
                  title: Text(event.title, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text(event.timeLocation, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ),
              );
            },
          ),

          const SizedBox(height: 16),
          Text('📝 NHIỆM VỤ CẦN LÀM (TASKS)', style: TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 8),
          _buildMinimalTaskList(textColor, cardBg),
        ],
      ),
    );
  }

  Widget _buildDedicatedTasksView(Color textColor, Color cardBg) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Task Management", style: TextStyle(color: textColor, fontSize: 26, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.add_circle, color: AppColors.primary, size: 30),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => TaskDetailScreen(onTaskUpdated: refreshData)),
                  );
                },
              )
            ],
          ),
          const SizedBox(height: 8),
          Text("Manage and filter your daily production tasks", style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
          const SizedBox(height: 24),
          _buildMinimalTaskList(textColor, cardBg),
        ],
      ),
    );
  }

  Widget _buildMinimalTaskList(Color textColor, Color cardBg) {
    if (TaskStorage.todoTasks.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        alignment: Alignment.centerLeft,
        child: const Text("Chúc mừng! Bạn đã dọn sạch toàn bộ Task.", style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: TaskStorage.todoTasks.length,
      itemBuilder: (context, index) {
        final task = TaskStorage.todoTasks[index];
        Color priorityColor = Colors.green;
        if (task.priority == 'High') priorityColor = Colors.redAccent;
        if (task.priority == 'Medium') priorityColor = Colors.orange;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => TaskDetailScreen(task: task, onTaskUpdated: refreshData)),
              );
            },
            leading: CircleAvatar(
              radius: 20,
              backgroundColor: priorityColor.withValues(alpha: 0.15),
              child: Icon(Icons.assignment, color: priorityColor, size: 18),
            ),
            title: Text(task.title, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text(task.deadline, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ),
        );
      },
    );
  }

  Widget _buildStatCard(IconData icon, String title, String value, Color iconColor, Color cardBg, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          CircleAvatar(radius: 18, backgroundColor: iconColor.withValues(alpha: 0.15), child: Icon(icon, color: iconColor, size: 20)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
            ],
          )
        ],
      ),
    );
  }
}