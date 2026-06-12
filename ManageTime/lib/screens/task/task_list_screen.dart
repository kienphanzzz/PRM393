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
  String _taskFilter = 'All';
  String _prioritySort = 'HighToLow';

  final TextEditingController _searchController = TextEditingController();

  final List<String> _filters = [
    'All',
    'Pending',
    'Completed',
  ];

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
    if (mounted) {
      setState(() {
        _isDark = ThemeController.isDark;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    ThemeController.themeNotifier.removeListener(_updateTheme);
    super.dispose();
  }

  Future<void> _addNewTask() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TaskDetailScreen(
          isNewTask: true,
        ),
      ),
    );

    if (result == true && mounted) {
      setState(() {});
    }
  }

  Future<void> _openTaskDetails(TaskModel task) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TaskDetailScreen(
          task: task,
        ),
      ),
    );

    if (result == true && mounted) {
      setState(() {});
    }
  }

  DateTime? _parseDeadline(String value) {
    if (value.trim().isEmpty) return null;

    try {
      return DateTime.parse(value.trim());
    } catch (_) {
      return null;
    }
  }

  bool _isOverdue(TaskModel task) {
    if (task.isCompleted) return false;

    final deadline = _parseDeadline(task.deadline);

    if (deadline == null) return false;

    return deadline.isBefore(DateTime.now());
  }

  int _priorityScore(String priority) {
    final String p = priority.toLowerCase().trim();

    if (p.contains('low')) return 0;
    if (p.contains('medium')) return 1;
    if (p.contains('high')) return 2;

    return 1;
  }

  Color _priorityColor(String priority) {
    final String p = priority.toLowerCase().trim();

    if (p.contains('high')) {
      return Colors.redAccent;
    }

    if (p.contains('medium')) {
      return Colors.amber;
    }

    if (p.contains('low')) {
      return Colors.grey;
    }

    return AppColors.primary;
  }

  List<TaskModel> _getSearchedTasks() {
    final String query = _searchQuery.toLowerCase().trim();

    final List<TaskModel> tasks = TaskStorage.todoTasks.where((task) {
      final bool matchesTitle = task.title.toLowerCase().contains(query);
      final bool matchesDesc = task.description.toLowerCase().contains(query);
      final bool matchesPriority = task.priority.toLowerCase().contains(query);

      return matchesTitle || matchesDesc || matchesPriority;
    }).toList();

    tasks.sort((a, b) {
      if (a.isCompleted != b.isCompleted) {
        return a.isCompleted ? 1 : -1;
      }

      final int aPriority = _priorityScore(a.priority);
      final int bPriority = _priorityScore(b.priority);

      int priorityCompare;

      if (_prioritySort == 'LowToHigh') {
        priorityCompare = aPriority.compareTo(bPriority);
      } else {
        priorityCompare = bPriority.compareTo(aPriority);
      }

      if (priorityCompare != 0) return priorityCompare;

      final DateTime? aDeadline = _parseDeadline(a.deadline);
      final DateTime? bDeadline = _parseDeadline(b.deadline);

      if (aDeadline == null && bDeadline == null) return 0;
      if (aDeadline == null) return 1;
      if (bDeadline == null) return -1;

      return aDeadline.compareTo(bDeadline);
    });

    return tasks;
  }

  List<TaskModel> _applyFilter(List<TaskModel> tasks) {
    if (_taskFilter == 'Pending') {
      return tasks.where((task) => !task.isCompleted).toList();
    }

    if (_taskFilter == 'Completed') {
      return tasks.where((task) => task.isCompleted).toList();
    }

    return tasks;
  }

  Future<void> _toggleTaskCompleted(TaskModel task, bool value) async {
    setState(() {
      task.isCompleted = value;
    });

    await TaskStorage.saveTasks();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          value ? 'Đã hoàn thành "${task.title}"' : 'Đã mở lại "${task.title}"',
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _showNotifications() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _isDark ? AppColors.cardBg : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(25),
        ),
      ),
      builder: (context) {
        final List<TaskModel> pendingTasks =
        TaskStorage.todoTasks.where((task) => !task.isCompleted).toList();

        final List<TaskModel> overdueTasks = pendingTasks.where(_isOverdue).toList();

        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Thông báo gần đây',
                    style: TextStyle(
                      color: _isDark ? Colors.white : Colors.black87,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Đóng'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (overdueTasks.isEmpty && pendingTasks.isEmpty)
                const Text(
                  'Không có thông báo nào.',
                  style: TextStyle(
                    color: AppColors.textMuted,
                  ),
                )
              else ...[
                if (overdueTasks.isNotEmpty)
                  _buildNotificationItem(
                    'Task quá hạn',
                    'Bạn có ${overdueTasks.length} nhiệm vụ đã quá deadline.',
                    DateFormat('HH:mm').format(DateTime.now()),
                  ),
                if (pendingTasks.isNotEmpty)
                  _buildNotificationItem(
                    'Nhiệm vụ chưa hoàn thành',
                    'Bạn còn ${pendingTasks.length} nhiệm vụ pending.',
                    DateFormat('HH:mm').format(DateTime.now()),
                  ),
              ],
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNotificationItem(
      String title,
      String body,
      String time,
      ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: _isDark ? AppColors.primary : Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                time,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: TextStyle(
              color: _isDark ? Colors.white70 : Colors.black54,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color textColor = _isDark ? Colors.white : Colors.black87;
    final Color cardBg = _isDark ? AppColors.cardBg : Colors.white;

    final String dateStr = DateFormat(
      'EEEE, MMM dd, yyyy',
    ).format(DateTime.now());

    final List<TaskModel> searchedTasks = _getSearchedTasks();
    final List<TaskModel> visibleTasks = _applyFilter(searchedTasks);

    final List<TaskModel> pendingTasks =
    visibleTasks.where((task) => !task.isCompleted).toList();

    final List<TaskModel> completedTasks =
    visibleTasks.where((task) => task.isCompleted).toList();

    final int totalTasks = TaskStorage.todoTasks.length;

    final int completedCount =
        TaskStorage.todoTasks.where((task) => task.isCompleted).length;

    final int pendingCount = totalTasks - completedCount;

    final double progressPercent =
    totalTasks > 0 ? (completedCount / totalTasks) * 100 : 0;

    int focusToday = 0;

    final String todayStr = DateFormat('E, MMM dd').format(DateTime.now());

    for (final h in HistoryStorage.historyList) {
      if (h.dateStr == todayStr && h.status == 'Completed') {
        focusToday += h.durationMinutes;
      }
    }

    final int focusHours = focusToday ~/ 60;
    final int focusMins = focusToday % 60;

    final String focusStr =
    focusHours > 0 ? '${focusHours}h ${focusMins}m' : '${focusMins}m';

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewTask,
        backgroundColor: AppColors.primary,
        child: const Icon(
          Icons.add,
          color: AppColors.background,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(
                textColor,
                dateStr,
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
                  _buildStatCard(
                    Icons.calendar_today_rounded,
                    'Tasks',
                    '$pendingCount pending',
                    Colors.blue,
                    cardBg,
                    textColor,
                  ),
                  _buildStatCard(
                    Icons.adjust_rounded,
                    'Focus',
                    '$focusStr today',
                    Colors.purpleAccent,
                    cardBg,
                    textColor,
                  ),
                  _buildStatCard(
                    Icons.check_circle_outline_rounded,
                    'Completed',
                    '$completedCount done',
                    Colors.greenAccent,
                    cardBg,
                    textColor,
                  ),
                  _buildStatCard(
                    Icons.trending_up_rounded,
                    'Progress',
                    '${progressPercent.toStringAsFixed(0)}% total',
                    Colors.orangeAccent,
                    cardBg,
                    textColor,
                  ),
                ],
              ),
              const SizedBox(height: 32),
              _buildSearchBox(
                cardBg,
                textColor,
              ),
              const SizedBox(height: 16),
              _buildFilterChips(),
              const SizedBox(height: 12),
              _buildPrioritySortChips(),
              const SizedBox(height: 24),
              if (visibleTasks.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Text(
                      'Không có nhiệm vụ nào.',
                      style: TextStyle(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                )
              else if (_taskFilter == 'All') ...[
                _buildTaskSection(
                  title: 'Pending Tasks',
                  count: pendingTasks.length,
                  tasks: pendingTasks,
                  cardBg: cardBg,
                  textColor: textColor,
                  emptyText: 'Không còn task pending.',
                ),
                const SizedBox(height: 20),
                _buildTaskSection(
                  title: 'Completed Tasks',
                  count: completedTasks.length,
                  tasks: completedTasks,
                  cardBg: cardBg,
                  textColor: textColor,
                  emptyText: 'Chưa có task nào hoàn thành.',
                ),
              ] else if (_taskFilter == 'Pending')
                _buildTaskSection(
                  title: 'Pending Tasks',
                  count: pendingTasks.length,
                  tasks: pendingTasks,
                  cardBg: cardBg,
                  textColor: textColor,
                  emptyText: 'Không còn task pending.',
                )
              else
                _buildTaskSection(
                  title: 'Completed Tasks',
                  count: completedTasks.length,
                  tasks: completedTasks,
                  cardBg: cardBg,
                  textColor: textColor,
                  emptyText: 'Chưa có task nào hoàn thành.',
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
      Color textColor,
      String dateStr,
      ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello, $_currentUserName!',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                dateStr,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(
            Icons.notifications_none_rounded,
            color: textColor,
            size: 28,
          ),
          onPressed: _showNotifications,
        ),
      ],
    );
  }

  Widget _buildStatCard(
      IconData icon,
      String title,
      String subtitle,
      Color color,
      Color cardBg,
      Color txtColor,
      ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: txtColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBox(
      Color cardBg,
      Color textColor,
      ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: _searchController,
        style: TextStyle(
          color: textColor,
        ),
        onChanged: (val) {
          setState(() {
            _searchQuery = val;
          });
        },
        decoration: InputDecoration(
          hintText: 'Tìm kiếm nhiệm vụ...',
          hintStyle: TextStyle(
            color: AppColors.textMuted.withOpacity(0.5),
          ),
          prefixIcon: const Icon(
            Icons.search,
            color: AppColors.textMuted,
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _filters.map((filter) {
          final bool selected = _taskFilter == filter;

          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: ChoiceChip(
              label: Text(filter),
              selected: selected,
              selectedColor: AppColors.primary,
              backgroundColor: _isDark ? AppColors.cardBg : Colors.white,
              labelStyle: TextStyle(
                color: selected
                    ? AppColors.background
                    : (_isDark ? Colors.white : Colors.black87),
                fontWeight: FontWeight.bold,
              ),
              onSelected: (_) {
                setState(() {
                  _taskFilter = filter;
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPrioritySortChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildSortChip(
            label: 'High → Low',
            value: 'HighToLow',
            icon: Icons.keyboard_double_arrow_down_rounded,
          ),
          const SizedBox(width: 10),
          _buildSortChip(
            label: 'Low → High',
            value: 'LowToHigh',
            icon: Icons.keyboard_double_arrow_up_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildSortChip({
    required String label,
    required String value,
    required IconData icon,
  }) {
    final bool selected = _prioritySort == value;

    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 17,
        color: selected
            ? AppColors.background
            : (_isDark ? Colors.white70 : Colors.black54),
      ),
      label: Text(label),
      selected: selected,
      selectedColor: AppColors.primary,
      backgroundColor: _isDark ? AppColors.cardBg : Colors.white,
      labelStyle: TextStyle(
        color: selected
            ? AppColors.background
            : (_isDark ? Colors.white : Colors.black87),
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
      onSelected: (_) {
        setState(() {
          _prioritySort = value;
        });
      },
    );
  }

  Widget _buildTaskSection({
    required String title,
    required int count,
    required List<TaskModel> tasks,
    required Color cardBg,
    required Color textColor,
    required String emptyText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title,
          count,
          textColor,
        ),
        const SizedBox(height: 12),
        if (tasks.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              emptyText,
              style: const TextStyle(
                color: AppColors.textMuted,
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final TaskModel task = tasks[index];

              return _buildTaskCard(
                task,
                cardBg,
                textColor,
              );
            },
          ),
      ],
    );
  }

  Widget _buildSectionHeader(
      String title,
      int count,
      Color textColor,
      ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          '$count task',
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildTaskCard(
      TaskModel task,
      Color bg,
      Color txtColor,
      ) {
    final bool overdue = _isOverdue(task);
    final Color priorityColor = _priorityColor(task.priority);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: task.isCompleted
            ? null
            : Border.all(
          color: priorityColor,
          width: 1.2,
        ),
      ),
      child: ListTile(
        onTap: () => _openTaskDetails(task),
        leading: Checkbox(
          value: task.isCompleted,
          activeColor: AppColors.primary,
          onChanged: (val) {
            _toggleTaskCompleted(
              task,
              val ?? false,
            );
          },
        ),
        title: Opacity(
          opacity: task.isCompleted ? 0.5 : 1,
          child: Text(
            task.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: txtColor,
              fontWeight: FontWeight.bold,
              decoration: task.isCompleted ? TextDecoration.lineThrough : null,
            ),
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _buildMiniBadge(
                task.priority,
                priorityColor,
              ),
              if (task.deadline.trim().isNotEmpty)
                _buildMiniBadge(
                  overdue ? 'Overdue • ${task.deadline}' : task.deadline,
                  overdue ? Colors.redAccent : AppColors.textMuted,
                ),
            ],
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: txtColor.withOpacity(0.3),
        ),
      ),
    );
  }

  Widget _buildMiniBadge(
      String text,
      Color color,
      ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}