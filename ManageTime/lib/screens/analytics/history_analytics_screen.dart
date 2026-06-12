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
  String _filter = 'Week';

  final List<String> _filters = [
    'Today',
    'Week',
    'Month',
    'All',
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
    ThemeController.themeNotifier.removeListener(_updateTheme);
    super.dispose();
  }

  void _loadHistoryData() {
    HistoryStorage.loadHistoryFromDisk().then((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  List<FocusHistoryModel> _filteredSessions() {
    final DateTime now = DateTime.now();

    if (_filter == 'Today') {
      final String key = DateFormat('yyyy-MM-dd').format(now);
      return HistoryStorage.sessionsByDateKey(key);
    }

    if (_filter == 'Week') {
      final String key = HistoryStorage.getWeekKey(now);
      return HistoryStorage.sessionsByWeekKey(key);
    }

    if (_filter == 'Month') {
      final String key = DateFormat('yyyy-MM').format(now);
      return HistoryStorage.sessionsByMonthKey(key);
    }

    return HistoryStorage.historyList;
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

    return '${DateFormat('dd/MM').format(start)} • '
        '${DateFormat('HH:mm').format(start)} - ${DateFormat('HH:mm').format(end)}';
  }

  String _ratingLabel(String rating) {
    switch (rating) {
      case 'Good':
        return '🔥 Rất tốt';
      case 'Normal':
        return '🙂 Ổn';
      case 'Bad':
        return '😵 Mất tập trung';
      default:
        return rating;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'Completed':
        return 'Hoàn thành';
      case 'Cancelled':
        return 'Dừng giữa chừng';
      default:
        return status;
    }
  }

  String _scoreLabel(int score) {
    if (score >= 90) return 'Excellent';
    if (score >= 70) return 'Good';
    if (score >= 50) return 'Average';
    return 'Interrupted';
  }

  String _historySubtitle(FocusHistoryModel record) {
    final StringBuffer buffer = StringBuffer();

    buffer.writeln(_formatTimeRange(record));

    buffer.write(
      '${_statusLabel(record.status)} • '
          'Score ${record.focusScore}/100 (${_scoreLabel(record.focusScore)}) • '
          '${_ratingLabel(record.rating)} • '
          'Pause ${record.pauseCount}',
    );

    if (record.note.trim().isNotEmpty) {
      buffer.write('\nNote: ${record.note.trim()}');
    }

    return buffer.toString();
  }

  void _deleteRecord(FocusHistoryModel record) async {
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
      builder: (context) {
        return AlertDialog(
          backgroundColor: _isDark ? AppColors.cardBg : Colors.white,
          title: Text(
            'Xóa toàn bộ lịch sử?',
            style: TextStyle(
              color: _isDark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Hành động này không thể hoàn tác. Toàn bộ dữ liệu Pomodoro đã lưu sẽ bị xóa.',
            style: TextStyle(
              color: _isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Hủy',
                style: TextStyle(
                  color: AppColors.textMuted,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);

                setState(() {
                  HistoryStorage.historyList.clear();
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

    final List<FocusHistoryModel> completedSessions = sessions
        .where((item) => item.status == 'Completed')
        .toList();

    final int totalMinutes = HistoryStorage.totalFocusMinutes(
      completedSessions,
    );

    final int completedCount = sessions
        .where((item) => item.status == 'Completed')
        .length;

    final int cancelledCount = sessions
        .where((item) => item.status != 'Completed')
        .length;

    final int avgScore = HistoryStorage.averageFocusScore(sessions);
    final int streak = HistoryStorage.calculateStreak();

    final Map<String, int> last7Days = HistoryStorage.minutesForLast7Days();

    final int maxDayMinutes = last7Days.values.isEmpty
        ? 1
        : last7Days.values.reduce((a, b) => a > b ? a : b);

    final int weeklyTotal = last7Days.values.fold(
      0,
          (a, b) => a + b,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () async {
          await HistoryStorage.loadHistoryFromDisk();

          if (mounted) {
            setState(() {});
          }
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(textColor),
              const SizedBox(height: 20),
              _buildFilterChips(),
              const SizedBox(height: 20),

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

              Container(
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

                          final double factor = maxDayMinutes == 0
                              ? 0
                              : minutes / maxDayMinutes;

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
              ),

              const SizedBox(height: 28),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '📜 FOCUS HISTORY (${sessions.length})',
                    style: const TextStyle(
                      color: Colors.blue,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
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
              ),

              const SizedBox(height: 12),

              if (sessions.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Text(
                    'Chưa có phiên Pomodoro nào trong khoảng thời gian này.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textMuted,
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: sessions.length,
                  itemBuilder: (context, index) {
                    final FocusHistoryModel record = sessions[index];

                    return _buildHistoryCard(
                      record: record,
                      cardBg: cardBg,
                      textColor: textColor,
                    );
                  },
                ),

              const SizedBox(height: 24),

              if (cancelledCount > 0)
                Text(
                  'Có $cancelledCount phiên bị dừng giữa chừng. Bạn có thể dùng chỉ số này để đánh giá mức độ ổn định khi tập trung.',
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
                'Pomodoro records, scores and focus analytics',
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

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _filters.map((filter) {
          final bool selected = _filter == filter;

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
                  _filter = filter;
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
        Container(
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

  Widget _buildHistoryCard({
    required FocusHistoryModel record,
    required Color cardBg,
    required Color textColor,
  }) {
    final bool completed = record.status == 'Completed';
    final Color statusColor = completed ? Colors.greenAccent : Colors.redAccent;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withOpacity(0.25),
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: statusColor.withOpacity(0.15),
          child: Icon(
            completed ? Icons.bolt_rounded : Icons.warning_amber_rounded,
            color: statusColor,
            size: 20,
          ),
        ),
        title: Text(
          record.taskTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            _historySubtitle(record),
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '+${record.actualMinutes}m',
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(
                Icons.remove_circle_outline,
                color: Colors.redAccent,
                size: 18,
              ),
              onPressed: () => _deleteRecord(record),
            ),
          ],
        ),
      ),
    );
  }
}