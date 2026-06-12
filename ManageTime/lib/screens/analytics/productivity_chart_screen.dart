import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../main.dart';
import '../../data/models/session_model.dart';

class ProductivityChartScreen extends StatefulWidget {
  const ProductivityChartScreen({super.key});

  @override
  State<ProductivityChartScreen> createState() =>
      _ProductivityChartScreenState();
}

class _ProductivityChartScreenState extends State<ProductivityChartScreen> {
  bool _isDark = ThemeController.isDark;

  @override
  void initState() {
    super.initState();
    ThemeController.themeNotifier.addListener(_updateTheme);
    _loadData();
  }

  void _updateTheme() {
    if (mounted) {
      setState(() {
        _isDark = ThemeController.isDark;
      });
    }
  }

  Future<void> _loadData() async {
    await HistoryStorage.loadHistoryFromDisk();

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    ThemeController.themeNotifier.removeListener(_updateTheme);
    super.dispose();
  }

  String _formatMinutes(int totalMinutes) {
    final int hours = totalMinutes ~/ 60;
    final int mins = totalMinutes % 60;

    if (hours > 0) return '${hours}h ${mins}m';
    return '${mins}m';
  }

  @override
  Widget build(BuildContext context) {
    final Color textColor = _isDark ? Colors.white : Colors.black87;
    final Color cardBg = _isDark ? AppColors.cardBg : Colors.white;

    final Map<String, int> data = HistoryStorage.minutesForLast7Days();

    final int maxMinutes = data.values.isEmpty
        ? 1
        : data.values.reduce((a, b) => a > b ? a : b);

    final int totalMinutes = data.values.fold(0, (a, b) => a + b);

    return Scaffold(
      backgroundColor: _isDark ? AppColors.background : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Productivity Chart',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: IconThemeData(color: textColor),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Focus trend',
                style: TextStyle(
                  color: textColor,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Thống kê thời lượng Pomodoro trong 7 ngày gần nhất.',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildInfoTile(
                          title: '7-day total',
                          value: _formatMinutes(totalMinutes),
                          color: AppColors.primary,
                        ),
                        _buildInfoTile(
                          title: 'Avg score',
                          value:
                          '${HistoryStorage.averageFocusScore(HistoryStorage.historyList)}/100',
                          color: Colors.orangeAccent,
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      height: 220,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: data.entries.map((entry) {
                          final DateTime date = DateTime.parse(entry.key);
                          final int minutes = entry.value;

                          final double factor = maxMinutes == 0
                              ? 0
                              : minutes / maxMinutes;

                          return _buildBar(
                            label: DateFormat('E').format(date).substring(0, 1),
                            date: DateFormat('dd/MM').format(date),
                            minutes: minutes,
                            factor: factor,
                            isToday: entry.key ==
                                DateFormat('yyyy-MM-dd').format(DateTime.now()),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.22),
                  ),
                ),
                child: const Text(
                  'Biểu đồ này được tính từ HistoryStorage, không còn là dữ liệu fix cứng. '
                      'Mỗi phiên Pomodoro hoàn thành sẽ cộng phút vào đúng ngày tương ứng.',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    height: 1.4,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required String title,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBar({
    required String label,
    required String date,
    required int minutes,
    required double factor,
    required bool isToday,
  }) {
    final double safeFactor = factor.clamp(0.05, 1.0);

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
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 450),
          width: 24,
          height: 150 * safeFactor,
          decoration: BoxDecoration(
            color: isToday
                ? AppColors.primary
                : AppColors.primary.withOpacity(0.25),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: isToday ? AppColors.primary : AppColors.textMuted,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        Text(
          date,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 9,
          ),
        ),
      ],
    );
  }
}