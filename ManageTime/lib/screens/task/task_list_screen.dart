import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../../main.dart';
import '../../data/models/task_model.dart';
import '../../data/models/session_model.dart';
import 'task_detail_screen.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  bool _isDark = ThemeController.isDark;
  String _currentUserName = 'User';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
    ThemeController.themeNotifier.addListener(_updateTheme);
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _currentUserName = prefs.getString('user_name') ?? 'User';
      });
    }
  }

  void _updateTheme() {
    if (mounted) setState(() => _isDark = ThemeController.isDark);
  }

  @override
  void dispose() {
    _searchController.dispose();
    ThemeController.themeNotifier.removeListener(_updateTheme);
    super.dispose();
  }

  void _addNewTask() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TaskDetailScreen(isNewTask: true)),
    );
    if (result == true) setState(() {});
  }

  void _openTaskDetails(TaskModel task) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => TaskDetailScreen(task: task)),
    );
    if (result == true) setState(() {});
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
      decoration: BoxDecoration(color: _isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)),
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
    Color textColor = _isDark ? Colors.white : Colors.black87;
    Color cardBg = _isDark ? AppColors.cardBg : Colors.white;
    String dateStr = DateFormat('EEEE, MMM dd, yyyy').format(DateTime.now());

    List<TaskModel> filteredTasks = TaskStorage.todoTasks
        .where((t) => t.title.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
        
    filteredTasks.sort((a, b) {
      if (a.isCompleted == b.isCompleted) return 0;
      return a.isCompleted ? 1 : -1;
    });

    int totalTasks = TaskStorage.todoTasks.length;
    int completedTasks = TaskStorage.todoTasks.where((t) => t.isCompleted).length;
    double progressPercent = totalTasks > 0 ? (completedTasks / totalTasks) * 100 : 0;
    
    int focusToday = 0;
    String todayStr = DateFormat('E, MMM dd').format(DateTime.now());
    for (var h in HistoryStorage.historyList) {
      if (h.dateStr == todayStr) focusToday += h.durationMinutes;
    }
    int focusHours = focusToday ~/ 60;
    int focusMins = focusToday % 60;
    String focusStr = focusHours > 0 ? '${focusHours}h ${focusMins}m' : '${focusMins}m';

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewTask,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: AppColors.background),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hello, $_currentUserName!', style: TextStyle(color: textColor, fontSize: 28, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(dateStr, style: const TextStyle(color: AppColors.textMuted, fontSize: 14)),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.notifications_none_rounded, color: textColor, size: 28),
                    onPressed: _showNotifications,
                  )
                ],
              ),
              const SizedBox(height: 32),

              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.1,
                children: [
                  _buildStatCard(Icons.calendar_today_rounded, 'Tasks', '${totalTasks - completedTasks} pending', Colors.blue, cardBg, textColor),
                  _buildStatCard(Icons.adjust_rounded, 'Focus', '$focusStr today', Colors.purpleAccent, cardBg, textColor),
                  _buildStatCard(Icons.event_note_rounded, 'Events', '3 upcoming', Colors.greenAccent, cardBg, textColor),
                  _buildStatCard(Icons.trending_up_rounded, 'Progress', '${progressPercent.toStringAsFixed(0)}% weekly', Colors.orangeAccent, cardBg, textColor),
                ],
              ),
              const SizedBox(height: 32),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16)),
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: textColor),
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm nhiệm vụ...',
                    hintStyle: TextStyle(color: AppColors.textMuted.withOpacity(0.5)),
                    prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Text('Today\'s Overview', style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              
              filteredTasks.isEmpty 
              ? Center(child: Padding(padding: const EdgeInsets.only(top: 20), child: Text('Không có nhiệm vụ nào.', style: TextStyle(color: AppColors.textMuted))))
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredTasks.length,
                  itemBuilder: (context, index) {
                    final task = filteredTasks[index];
                    return _buildTaskCard(task, cardBg, textColor);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(IconData icon, String title, String subtitle, Color color, Color cardBg, Color txtColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 24),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: txtColor, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildTaskCard(TaskModel task, Color bg, Color txtColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: ListTile(
        onTap: () => _openTaskDetails(task),
        leading: Checkbox(
          value: task.isCompleted,
          activeColor: AppColors.primary,
          onChanged: (val) {
            setState(() {
              task.isCompleted = val ?? false;
              TaskStorage.saveTasks();
            });
          },
        ),
        title: Opacity(
          opacity: task.isCompleted ? 0.5 : 1,
          child: Text(
            task.title,
            style: TextStyle(color: txtColor, fontWeight: FontWeight.bold, decoration: task.isCompleted ? TextDecoration.lineThrough : null),
          ),
        ),
        subtitle: Text(task.deadline, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        trailing: Icon(Icons.chevron_right, color: txtColor.withValues(alpha: 0.3)),
      ),
    );
  }
}