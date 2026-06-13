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

  bool _showPending = true;
  bool _showCompleted = false;

  int _pendingPage = 0;
  int _completedPage = 0;
  int _singleListPage = 0;

  final int _pageSize = 5;

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

    if (!mounted) return;

    setState(() {
      _currentUserName = prefs.getString('user_name') ?? 'User';
    });
  }

  void _updateTheme() {
    if (!mounted) return;

    setState(() {
      _isDark = ThemeController.isDark;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    ThemeController.themeNotifier.removeListener(_updateTheme);
    super.dispose();
  }

  void _resetPages() {
    _pendingPage = 0;
    _completedPage = 0;
    _singleListPage = 0;
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
      setState(() {
        _resetPages();
      });
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

  String _formatDeadline(String value) {
    final DateTime? deadline = _parseDeadline(value);

    if (deadline == null) return value;

    return DateFormat('yyyy-MM-dd HH:mm').format(deadline);
  }

  bool _isOverdue(TaskModel task) {
    if (task.isCompleted) return false;

    final DateTime? deadline = _parseDeadline(task.deadline);

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

    if (p.contains('high')) return Colors.redAccent;
    if (p.contains('medium')) return Colors.amber;
    if (p.contains('low')) return Colors.grey;

    return AppColors.primary;
  }

  List<TaskModel> _allTasks() {
    return TaskStorage.todoTasks.cast<TaskModel>();
  }

  List<TaskModel> _getSearchedAndSortedTasks() {
    final String query = _searchQuery.toLowerCase().trim();

    final List<TaskModel> tasks = _allTasks().where((task) {
      if (query.isEmpty) return true;

      final String title = task.title.toLowerCase();
      final String description = task.description.toLowerCase();
      final String priority = task.priority.toLowerCase();
      final String deadline = task.deadline.toLowerCase();

      return title.contains(query) ||
          description.contains(query) ||
          priority.contains(query) ||
          deadline.contains(query);
    }).toList();

    tasks.sort((a, b) {
      if (a.isCompleted != b.isCompleted) {
        return a.isCompleted ? 1 : -1;
      }

      final int aPriority = _priorityScore(a.priority);
      final int bPriority = _priorityScore(b.priority);

      final int priorityCompare = _prioritySort == 'HighToLow'
          ? bPriority.compareTo(aPriority)
          : aPriority.compareTo(bPriority);

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

  int _totalPages(int totalItems) {
    if (totalItems <= 0) return 1;

    return ((totalItems - 1) ~/ _pageSize) + 1;
  }

  int _safePage(int page, int totalItems) {
    final int totalPages = _totalPages(totalItems);

    if (page < 0) return 0;
    if (page >= totalPages) return totalPages - 1;

    return page;
  }

  List<TaskModel> _pageItems(List<TaskModel> tasks, int page) {
    if (tasks.isEmpty) return [];

    final int safePage = _safePage(page, tasks.length);
    final int start = safePage * _pageSize;
    int end = start + _pageSize;

    if (end > tasks.length) {
      end = tasks.length;
    }

    return tasks.sublist(start, end);
  }

  Future<void> _toggleTaskCompleted(TaskModel task, bool value) async {
    setState(() {
      task.isCompleted = value;
      _resetPages();
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
        final List<TaskModel> pendingTasks = _allTasks()
            .where((task) => !task.isCompleted)
            .toList();

        final List<TaskModel> overdueTasks =
        pendingTasks.where(_isOverdue).toList();

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

    final List<TaskModel> searchedTasks = _getSearchedAndSortedTasks();
    final List<TaskModel> visibleTasks = _applyFilter(searchedTasks);

    final List<TaskModel> pendingTasks =
    searchedTasks.where((task) => !task.isCompleted).toList();

    final List<TaskModel> completedTasks =
    searchedTasks.where((task) => task.isCompleted).toList();

    final int totalTasks = _allTasks().length;

    final int completedCount =
        _allTasks().where((task) => task.isCompleted).length;

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

    if (_taskFilter == 'Pending') {
      _singleListPage = _safePage(_singleListPage, visibleTasks.length);
    }

    if (_taskFilter == 'Completed') {
      _singleListPage = _safePage(_singleListPage, visibleTasks.length);
    }

    _pendingPage = _safePage(_pendingPage, pendingTasks.length);
    _completedPage = _safePage(_completedPage, completedTasks.length);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            24,
            24,
            24,
            110,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(
                textColor,
                dateStr,
              ),
              const SizedBox(height: 28),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1.18,
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
              const SizedBox(height: 28),
              _buildSearchBox(
                cardBg,
                textColor,
              ),
              const SizedBox(height: 16),
              _buildFilterChips(),
              const SizedBox(height: 12),
              _buildSortChips(),
              const SizedBox(height: 24),
              if (visibleTasks.isEmpty)
                _buildEmptyState(cardBg)
              else if (_taskFilter == 'All') ...[
                _buildTaskSection(
                  title: 'Pending Tasks',
                  count: pendingTasks.length,
                  tasks: pendingTasks,
                  page: _pendingPage,
                  expanded: _showPending,
                  cardBg: cardBg,
                  textColor: textColor,
                  emptyText: 'Không còn task pending.',
                  onToggleExpanded: () {
                    setState(() {
                      _showPending = !_showPending;
                    });
                  },
                  onPrevPage: () {
                    setState(() {
                      _pendingPage--;
                    });
                  },
                  onNextPage: () {
                    setState(() {
                      _pendingPage++;
                    });
                  },
                ),
                const SizedBox(height: 18),
                _buildTaskSection(
                  title: 'Completed Tasks',
                  count: completedTasks.length,
                  tasks: completedTasks,
                  page: _completedPage,
                  expanded: _showCompleted,
                  cardBg: cardBg,
                  textColor: textColor,
                  emptyText: 'Chưa có task nào hoàn thành.',
                  onToggleExpanded: () {
                    setState(() {
                      _showCompleted = !_showCompleted;
                    });
                  },
                  onPrevPage: () {
                    setState(() {
                      _completedPage--;
                    });
                  },
                  onNextPage: () {
                    setState(() {
                      _completedPage++;
                    });
                  },
                ),
              ] else
                _buildSingleFilteredSection(
                  tasks: visibleTasks,
                  cardBg: cardBg,
                  textColor: textColor,
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
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                dateStr,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(
            Icons.notifications_none_rounded,
            color: textColor,
            size: 26,
          ),
          onPressed: _showNotifications,
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 44,
          height: 44,
          child: ElevatedButton(
            onPressed: _addNewTask,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            child: const Icon(
              Icons.add_rounded,
              color: AppColors.background,
              size: 25,
            ),
          ),
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 22,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: txtColor,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
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
      padding: const EdgeInsets.symmetric(horizontal: 14),
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
            _resetPages();
          });
        },
        decoration: InputDecoration(
          hintText: 'Tìm kiếm nhiệm vụ, deadline, priority...',
          hintStyle: TextStyle(
            color: AppColors.textMuted.withOpacity(0.55),
            fontSize: 13,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.textMuted,
          ),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
            onPressed: () {
              setState(() {
                _searchController.clear();
                _searchQuery = '';
                _resetPages();
              });
            },
            icon: const Icon(
              Icons.close_rounded,
              color: AppColors.textMuted,
            ),
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
                fontSize: 12,
              ),
              onSelected: (_) {
                setState(() {
                  _taskFilter = filter;
                  _resetPages();

                  if (filter == 'Completed') {
                    _showCompleted = true;
                  }

                  if (filter == 'Pending') {
                    _showPending = true;
                  }
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSortChips() {
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
        size: 16,
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
          _resetPages();
        });
      },
    );
  }

  Widget _buildSingleFilteredSection({
    required List<TaskModel> tasks,
    required Color cardBg,
    required Color textColor,
  }) {
    final String title =
    _taskFilter == 'Pending' ? 'Pending Tasks' : 'Completed Tasks';

    return _buildTaskSection(
      title: title,
      count: tasks.length,
      tasks: tasks,
      page: _singleListPage,
      expanded: true,
      cardBg: cardBg,
      textColor: textColor,
      emptyText: _taskFilter == 'Pending'
          ? 'Không còn task pending.'
          : 'Chưa có task nào hoàn thành.',
      onToggleExpanded: () {},
      onPrevPage: () {
        setState(() {
          _singleListPage--;
        });
      },
      onNextPage: () {
        setState(() {
          _singleListPage++;
        });
      },
      hideCollapseButton: true,
    );
  }

  Widget _buildTaskSection({
    required String title,
    required int count,
    required List<TaskModel> tasks,
    required int page,
    required bool expanded,
    required Color cardBg,
    required Color textColor,
    required String emptyText,
    required VoidCallback onToggleExpanded,
    required VoidCallback onPrevPage,
    required VoidCallback onNextPage,
    bool hideCollapseButton = false,
  }) {
    final int safePage = _safePage(page, tasks.length);
    final List<TaskModel> pageItems = _pageItems(tasks, safePage);
    final int totalPages = _totalPages(tasks.length);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: title,
          count: count,
          expanded: expanded,
          textColor: textColor,
          onTap: onToggleExpanded,
          hideCollapseButton: hideCollapseButton,
        ),
        const SizedBox(height: 12),
        if (!expanded)
          _buildCollapsedSectionCard(
            count: count,
            cardBg: cardBg,
            textColor: textColor,
            onTap: onToggleExpanded,
          )
        else if (tasks.isEmpty)
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
        else ...[
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: pageItems.length,
              itemBuilder: (context, index) {
                final TaskModel task = pageItems[index];

                return _buildTaskCard(
                  task,
                  cardBg,
                  textColor,
                );
              },
            ),
            const SizedBox(height: 4),
            _buildPaginationControls(
              totalItems: tasks.length,
              currentPage: safePage,
              totalPages: totalPages,
              cardBg: cardBg,
              textColor: textColor,
              onPrevPage: onPrevPage,
              onNextPage: onNextPage,
            ),
          ],
      ],
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required int count,
    required bool expanded,
    required Color textColor,
    required VoidCallback onTap,
    bool hideCollapseButton = false,
  }) {
    return InkWell(
      onTap: hideCollapseButton ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 4,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: textColor,
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              '$count task',
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
            ),
            if (!hideCollapseButton) ...[
              const SizedBox(width: 8),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCollapsedSectionCard({
    required int count,
    required Color cardBg,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.15),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.inventory_2_outlined,
              color: AppColors.primary,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Đang thu gọn $count task. Bấm để mở xem.',
                style: TextStyle(
                  color: textColor.withOpacity(0.8),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.primary,
            ),
          ],
        ),
      ),
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
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: task.isCompleted
            ? Border.all(
          color: Colors.greenAccent.withOpacity(0.25),
          width: 1,
        )
            : Border.all(
          color: priorityColor,
          width: 1.1,
        ),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 5,
        ),
        minLeadingWidth: 26,
        onTap: () => _openTaskDetails(task),
        leading: Transform.scale(
          scale: 0.86,
          child: Checkbox(
            value: task.isCompleted,
            activeColor: AppColors.primary,
            onChanged: (val) {
              _toggleTaskCompleted(
                task,
                val ?? false,
              );
            },
          ),
        ),
        title: Opacity(
          opacity: task.isCompleted ? 0.55 : 1,
          child: Text(
            task.title.trim().isEmpty ? 'Không có tiêu đề' : task.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: txtColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
              decoration: task.isCompleted ? TextDecoration.lineThrough : null,
            ),
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Wrap(
            spacing: 7,
            runSpacing: 5,
            children: [
              _buildMiniBadge(
                task.priority,
                priorityColor,
              ),
              if (task.deadline.trim().isNotEmpty)
                _buildMiniBadge(
                  overdue
                      ? 'Overdue • ${_formatDeadline(task.deadline)}'
                      : _formatDeadline(task.deadline),
                  overdue ? Colors.redAccent : AppColors.textMuted,
                ),
            ],
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: txtColor.withOpacity(0.3),
          size: 20,
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
        horizontal: 7,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.13),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPaginationControls({
    required int totalItems,
    required int currentPage,
    required int totalPages,
    required Color cardBg,
    required Color textColor,
    required VoidCallback onPrevPage,
    required VoidCallback onNextPage,
  }) {
    final int from = totalItems == 0 ? 0 : currentPage * _pageSize + 1;

    int to = (currentPage + 1) * _pageSize;

    if (to > totalItems) {
      to = totalItems;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.09),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$from - $to / $totalItems',
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: currentPage <= 0 ? null : onPrevPage,
            icon: Icon(
              Icons.chevron_left_rounded,
              color: currentPage <= 0
                  ? AppColors.textMuted.withOpacity(0.35)
                  : AppColors.primary,
            ),
          ),
          Text(
            '${currentPage + 1}/$totalPages',
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: currentPage >= totalPages - 1 ? null : onNextPage,
            icon: Icon(
              Icons.chevron_right_rounded,
              color: currentPage >= totalPages - 1
                  ? AppColors.textMuted.withOpacity(0.35)
                  : AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(Color cardBg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Text(
        'Không có nhiệm vụ nào phù hợp.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}