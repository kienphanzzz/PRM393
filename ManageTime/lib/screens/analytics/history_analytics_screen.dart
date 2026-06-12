import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../main.dart';
import '../../data/models/session_model.dart';

class HistoryAnalyticsScreen extends StatefulWidget {
  const HistoryAnalyticsScreen({super.key});

  @override
  State<HistoryAnalyticsScreen> createState() => _HistoryAnalyticsScreenState();
}

class _HistoryAnalyticsScreenState extends State<HistoryAnalyticsScreen> {
  bool _isDark = ThemeController.isDark;

  String _periodFilter = 'Week';
  String _statusFilter = 'All';
  String _searchQuery = '';
  String? _selectedDateKey;

  int _currentPage = 0;
  final int _pageSize = 10;

  final TextEditingController _searchController = TextEditingController();

  final List<String> _periodFilters = [
    'Today',
    'Week',
    'Month',
    'All',
  ];

  final List<String> _statusFilters = [
    'All',
    'Completed',
    'Interrupted',
  ];

  @override
  void initState() {
    super.initState();
    ThemeController.themeNotifier.addListener(_updateTheme);
    _loadHistoryData();
  }

  void _updateTheme() {
    if (mounted) {
      setState(() {
        _isDark = ThemeController.isDark;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadHistoryData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    ThemeController.themeNotifier.removeListener(_updateTheme);
    super.dispose();
  }

  Future<void> _loadHistoryData() async {
    await HistoryStorage.loadHistoryFromDisk();

    if (mounted) {
      setState(() {});
    }
  }

  void _resetPage() {
    _currentPage = 0;
  }

  List<FocusHistoryModel> _sessionsByPeriod() {
    final DateTime now = DateTime.now();

    if (_selectedDateKey != null) {
      return HistoryStorage.sessionsByDateKey(_selectedDateKey!)
          .cast<FocusHistoryModel>();
    }

    if (_periodFilter == 'Today') {
      final String key = DateFormat('yyyy-MM-dd').format(now);
      return HistoryStorage.sessionsByDateKey(key).cast<FocusHistoryModel>();
    }

    if (_periodFilter == 'Week') {
      final String key = HistoryStorage.getWeekKey(now);
      return HistoryStorage.sessionsByWeekKey(key).cast<FocusHistoryModel>();
    }

    if (_periodFilter == 'Month') {
      final String key = DateFormat('yyyy-MM').format(now);
      return HistoryStorage.sessionsByMonthKey(key).cast<FocusHistoryModel>();
    }

    return HistoryStorage.historyList.cast<FocusHistoryModel>();
  }

  List<FocusHistoryModel> _filteredSessions() {
    final String query = _searchQuery.toLowerCase().trim();

    List<FocusHistoryModel> sessions = _sessionsByPeriod();

    if (_statusFilter == 'Completed') {
      sessions = sessions.where((item) => item.status == 'Completed').toList();
    }

    if (_statusFilter == 'Interrupted') {
      sessions = sessions.where((item) => item.status != 'Completed').toList();
    }

    if (query.isNotEmpty) {
      sessions = sessions.where((item) {
        final String taskTitle = item.taskTitle.toLowerCase();
        final String note = item.note.toLowerCase();
        final String dateStr = item.dateStr.toLowerCase();
        final String dateKey = item.dateKey.toLowerCase();
        final String timeStr = item.timeStr.toLowerCase();
        final String rating = item.rating.toLowerCase();
        final String status = item.status.toLowerCase();

        return taskTitle.contains(query) ||
            note.contains(query) ||
            dateStr.contains(query) ||
            dateKey.contains(query) ||
            timeStr.contains(query) ||
            rating.contains(query) ||
            status.contains(query);
      }).toList();
    }

    sessions.sort((a, b) {
      final DateTime aDate = DateTime.tryParse(a.startAt) ?? DateTime(2000);
      final DateTime bDate = DateTime.tryParse(b.startAt) ?? DateTime(2000);

      return bDate.compareTo(aDate);
    });

    return sessions;
  }

  int _totalPages(int totalItems) {
    if (totalItems <= 0) return 1;

    return ((totalItems - 1) ~/ _pageSize) + 1;
  }

  List<FocusHistoryModel> _pagedSessions(List<FocusHistoryModel> sessions) {
    final int totalPages = _totalPages(sessions.length);

    if (_currentPage >= totalPages) {
      _currentPage = totalPages - 1;
    }

    if (_currentPage < 0) {
      _currentPage = 0;
    }

    final int start = _currentPage * _pageSize;
    int end = start + _pageSize;

    if (end > sessions.length) {
      end = sessions.length;
    }

    if (start >= sessions.length) {
      return [];
    }

    return sessions.sublist(start, end);
  }

  String _formatMinutes(int totalMinutes) {
    final int hours = totalMinutes ~/ 60;
    final int mins = totalMinutes % 60;

    if (hours > 0) {
      return '${hours}h ${mins}m';
    }

    return '${mins}m';
  }

  String _formatTimeRange(FocusHistoryModel record) {
    final DateTime? start = DateTime.tryParse(record.startAt);
    final DateTime? end = DateTime.tryParse(record.endAt);

    if (start == null || end == null) {
      return '${record.dateStr} | ${record.timeStr}';
    }

    return '${DateFormat('dd/MM/yyyy').format(start)} • '
        '${DateFormat('HH:mm').format(start)} - ${DateFormat('HH:mm').format(end)}';
  }

  String _ratingLabel(String rating) {
    if (rating == 'Good') {
      return '🔥 Rất tốt';
    }

    if (rating == 'Normal') {
      return '😐 Ổn';
    }

    if (rating == 'Bad') {
      return '😵 Mất tập trung';
    }

    return rating;
  }

  String _statusLabel(String status) {
    if (status == 'Completed') {
      return 'Hoàn thành';
    }

    if (status == 'Cancelled') {
      return 'Dừng giữa chừng';
    }

    return status;
  }

  String _scoreLabel(int score) {
    if (score >= 85) return 'Rất tốt';
    if (score >= 65) return 'Khá tốt';
    if (score >= 45) return 'Trung bình';

    return 'Cần cải thiện';
  }

  String _visualLabel(String visualMode) {
    if (visualMode == 'hourglass') return 'Đồng hồ cát';
    if (visualMode == 'clock') return 'Đồng hồ xoay';
    if (visualMode == 'ring') return 'Vòng tròn';
    if (visualMode == 'minimal') return 'Tối giản';

    return visualMode;
  }

  Color _statusColor(FocusHistoryModel record) {
    if (record.status == 'Completed') {
      return Colors.greenAccent;
    }

    return Colors.redAccent;
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1),
      builder: (context, child) {
        return Theme(
          data: _isDark
              ? ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              surface: AppColors.cardBg,
            ),
          )
              : ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return;

    setState(() {
      _selectedDateKey = DateFormat('yyyy-MM-dd').format(picked);
      _resetPage();
    });
  }

  void _clearDateFilter() {
    setState(() {
      _selectedDateKey = null;
      _resetPage();
    });
  }

  Future<void> _deleteRecord(FocusHistoryModel record) async {
    setState(() {
      HistoryStorage.historyList.removeWhere(
            (item) => item.id == record.id,
      );
    });

    await HistoryStorage.saveHistoryToDisk();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã xóa phiên lịch sử này.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _clearAllHistory() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _isDark ? AppColors.cardBg : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Xóa toàn bộ lịch sử?',
            style: TextStyle(
              color: _isDark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Hành động này không thể hoàn tác.\nToàn bộ dữ liệu Pomodoro đã lưu sẽ bị xóa.',
            style: TextStyle(
              color: _isDark ? Colors.white70 : Colors.black54,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                'Hủy',
                style: TextStyle(
                  color: AppColors.textMuted,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);

                setState(() {
                  HistoryStorage.historyList.clear();
                  _currentPage = 0;
                });

                await HistoryStorage.saveHistoryToDisk();
              },
              child: const Text(
                'Xóa sạch',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color textColor = _isDark ? Colors.white : Colors.black87;
    final Color cardBg = _isDark ? AppColors.cardBg : Colors.white;

    final List<FocusHistoryModel> sessions = _filteredSessions();
    final List<FocusHistoryModel> pageSessions = _pagedSessions(sessions);

    final List<FocusHistoryModel> completedSessions =
    sessions.where((item) => item.status == 'Completed').toList();

    final int totalMinutes = HistoryStorage.totalFocusMinutes(
      completedSessions,
    );

    final int completedCount =
        sessions.where((item) => item.status == 'Completed').length;

    final int interruptedCount =
        sessions.where((item) => item.status != 'Completed').length;

    final int avgScore = HistoryStorage.averageFocusScore(sessions);
    final int streak = HistoryStorage.calculateStreak();

    final Map<String, int> last7Days =
    HistoryStorage.minutesForLast7Days().cast<String, int>();

    final int maxDayMinutes = last7Days.values.isEmpty
        ? 1
        : last7Days.values.reduce((a, b) => a > b ? a : b);

    final int weeklyTotal = last7Days.values.fold(
      0,
          (a, b) => a + b,
    );

    final int totalPages = _totalPages(sessions.length);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _loadHistoryData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(textColor),
              const SizedBox(height: 18),
              _buildSearchBox(
                cardBg: cardBg,
                textColor: textColor,
              ),
              const SizedBox(height: 14),
              _buildDateTools(
                textColor: textColor,
                cardBg: cardBg,
              ),
              const SizedBox(height: 14),
              _buildPeriodFilterChips(),
              const SizedBox(height: 12),
              _buildStatusFilterChips(),
              const SizedBox(height: 22),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1.25,
                children: [
                  _buildStatCard(
                    title: 'Total Focus',
                    value: _formatMinutes(totalMinutes),
                    icon: Icons.timer_rounded,
                    color: AppColors.primary,
                    cardBg: cardBg,
                    textColor: textColor,
                  ),
                  _buildStatCard(
                    title: 'Completed',
                    value: '$completedCount',
                    icon: Icons.check_circle_rounded,
                    color: Colors.greenAccent,
                    cardBg: cardBg,
                    textColor: textColor,
                  ),
                  _buildStatCard(
                    title: 'Avg Score',
                    value: '$avgScore/100',
                    icon: Icons.speed_rounded,
                    color: Colors.orangeAccent,
                    cardBg: cardBg,
                    textColor: textColor,
                  ),
                  _buildStatCard(
                    title: 'Streak',
                    value: '$streak days',
                    icon: Icons.local_fire_department_rounded,
                    color: Colors.redAccent,
                    cardBg: cardBg,
                    textColor: textColor,
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text(
                '⚡ LAST 7 DAYS FOCUS',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 12),
              _buildWeeklyChart(
                cardBg: cardBg,
                textColor: textColor,
                last7Days: last7Days,
                maxDayMinutes: maxDayMinutes,
                weeklyTotal: weeklyTotal,
              ),
              const SizedBox(height: 28),
              _buildHistoryTitleRow(
                count: sessions.length,
                textColor: textColor,
              ),
              const SizedBox(height: 12),
              if (sessions.isEmpty)
                _buildEmptyState(cardBg)
              else ...[
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: pageSessions.length,
                  itemBuilder: (context, index) {
                    final FocusHistoryModel record = pageSessions[index];

                    return _buildHistoryCard(
                      record: record,
                      cardBg: cardBg,
                      textColor: textColor,
                    );
                  },
                ),
                const SizedBox(height: 14),
                _buildPaginationControls(
                  currentPage: _currentPage,
                  totalPages: totalPages,
                  totalItems: sessions.length,
                  textColor: textColor,
                  cardBg: cardBg,
                ),
              ],
              const SizedBox(height: 24),
              if (interruptedCount > 0)
                Text(
                  'Có $interruptedCount phiên bị dừng giữa chừng. Bạn có thể tìm theo tên task, note hoặc ngày để xem lại nhanh hơn.',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Color textColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Productivity History',
                style: TextStyle(
                  color: textColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Tìm kiếm, lọc ngày và xem lại phiên Pomodoro',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(
            Icons.refresh_rounded,
            color: AppColors.primary,
          ),
          onPressed: _loadHistoryData,
        ),
      ],
    );
  }

  Widget _buildSearchBox({
    required Color cardBg,
    required Color textColor,
  }) {
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
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
            _resetPage();
          });
        },
        decoration: InputDecoration(
          hintText: 'Tìm theo tên task, note, ngày, trạng thái...',
          hintStyle: TextStyle(
            color: AppColors.textMuted.withOpacity(0.65),
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
                _resetPage();
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

  Widget _buildDateTools({
    required Color textColor,
    required Color cardBg,
  }) {
    final String dateText = _selectedDateKey == null
        ? 'Chọn ngày'
        : DateFormat('dd/MM/yyyy').format(
      DateTime.parse(_selectedDateKey!),
    );

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 13,
              ),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _selectedDateKey == null
                      ? Colors.transparent
                      : AppColors.primary,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_month_rounded,
                    color: _selectedDateKey == null
                        ? AppColors.textMuted
                        : AppColors.primary,
                    size: 19,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    dateText,
                    style: TextStyle(
                      color: _selectedDateKey == null
                          ? AppColors.textMuted
                          : AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_selectedDateKey != null) ...[
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _clearDateFilter,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 13,
              ),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.close_rounded,
                    color: Colors.redAccent,
                    size: 18,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Bỏ lọc',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPeriodFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _periodFilters.map((filter) {
          final bool selected = _periodFilter == filter && _selectedDateKey == null;

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
                  _periodFilter = filter;
                  _selectedDateKey = null;
                  _resetPage();
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatusFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _statusFilters.map((filter) {
          final bool selected = _statusFilter == filter;

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
                  _statusFilter = filter;
                  _resetPage();
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color cardBg,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 22,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: textColor,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyChart({
    required Color cardBg,
    required Color textColor,
    required Map<String, int> last7Days,
    required int maxDayMinutes,
    required int weeklyTotal,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Weekly Focus Chart',
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _formatMinutes(weeklyTotal),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 150,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: last7Days.entries.map((entry) {
                final DateTime date = DateTime.parse(entry.key);
                final int minutes = entry.value;
                final double factor =
                maxDayMinutes == 0 ? 0 : minutes / maxDayMinutes;

                return _buildChartBar(
                  day: DateFormat('E').format(date).substring(0, 1),
                  minutes: minutes,
                  heightFactor: factor,
                  isToday: entry.key ==
                      DateFormat('yyyy-MM-dd').format(DateTime.now()),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartBar({
    required String day,
    required int minutes,
    required double heightFactor,
    required bool isToday,
  }) {
    final double safeFactor = heightFactor.clamp(0.05, 1.0);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          minutes > 0 ? '${minutes}m' : '',
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          width: 18,
          height: 100 * safeFactor,
          decoration: BoxDecoration(
            color: isToday
                ? AppColors.primary
                : AppColors.primary.withOpacity(0.28),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          day,
          style: TextStyle(
            color: isToday ? AppColors.primary : AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryTitleRow({
    required int count,
    required Color textColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            'FOCUS HISTORY ($count)',
            style: const TextStyle(
              color: Colors.blue,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ),
        if (HistoryStorage.historyList.isNotEmpty)
          TextButton.icon(
            onPressed: _clearAllHistory,
            icon: const Icon(
              Icons.delete_sweep,
              color: Colors.redAccent,
              size: 18,
            ),
            label: const Text(
              'Clear',
              style: TextStyle(
                color: Colors.redAccent,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState(Color cardBg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Text(
        'Không tìm thấy phiên Pomodoro nào phù hợp.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.textMuted,
        ),
      ),
    );
  }

  Widget _buildHistoryCard({
    required FocusHistoryModel record,
    required Color cardBg,
    required Color textColor,
  }) {
    final bool completed = record.status == 'Completed';
    final Color statusColor = _statusColor(record);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: statusColor.withOpacity(0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: statusColor.withOpacity(0.15),
                child: Icon(
                  completed
                      ? Icons.bolt_rounded
                      : Icons.warning_amber_rounded,
                  color: statusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  record.taskTitle.trim().isEmpty
                      ? 'Phiên tự do'
                      : record.taskTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              Text(
                '+${record.actualMinutes}m',
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.remove_circle_outline,
                  color: Colors.redAccent,
                  size: 20,
                ),
                onPressed: () => _deleteRecord(record),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _formatTimeRange(record),
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildInfoBadge(
                _statusLabel(record.status),
                statusColor,
              ),
              _buildInfoBadge(
                'Score ${record.focusScore}/100',
                Colors.orangeAccent,
              ),
              _buildInfoBadge(
                _scoreLabel(record.focusScore),
                AppColors.primary,
              ),
              _buildInfoBadge(
                _ratingLabel(record.rating),
                Colors.amber,
              ),
              _buildInfoBadge(
                'Pause ${record.pauseCount}',
                AppColors.textMuted,
              ),
              _buildInfoBadge(
                _visualLabel(record.visualMode),
                Colors.purpleAccent,
              ),
            ],
          ),
          if (record.note.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Note: ${record.note.trim()}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoBadge(
      String text,
      Color color,
      ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.13),
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

  Widget _buildPaginationControls({
    required int currentPage,
    required int totalPages,
    required int totalItems,
    required Color textColor,
    required Color cardBg,
  }) {
    final int from = totalItems == 0 ? 0 : currentPage * _pageSize + 1;

    int to = (currentPage + 1) * _pageSize;

    if (to > totalItems) {
      to = totalItems;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$from - $to / $totalItems phiên',
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            onPressed: currentPage <= 0
                ? null
                : () {
              setState(() {
                _currentPage--;
              });
            },
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
              fontSize: 13,
            ),
          ),
          IconButton(
            onPressed: currentPage >= totalPages - 1
                ? null
                : () {
              setState(() {
                _currentPage++;
              });
            },
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
}