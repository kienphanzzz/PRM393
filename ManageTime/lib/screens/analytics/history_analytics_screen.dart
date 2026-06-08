import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../main.dart';
import '../../data/models/session_model.dart';

class HistoryAnalyticsScreen extends StatefulWidget {
  const HistoryAnalyticsScreen({super.key});

  @override
  State<HistoryAnalyticsScreen> createState() => _HistoryAnalyticsScreenState();
}

class _HistoryAnalyticsScreenState extends State<HistoryAnalyticsScreen> {
  final bool _isDark = ThemeController.isDark;

  @override
  void initState() {
    super.initState();
    _loadHistoryData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadHistoryData();
  }

  void _loadHistoryData() {
    HistoryStorage.loadHistoryFromDisk().then((_) {
      if (mounted) setState(() {});
    });
  }

  void _deleteSingleRecord(int index) async {
    setState(() {
      HistoryStorage.historyList.removeAt(index);
    });
    await HistoryStorage.saveHistoryToDisk();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xóa phiên lịch sử này.')),
      );
    }
  }

  void _clearAllHistory() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isDark ? AppColors.cardBg : Colors.white,
        title: Text('Xóa toàn bộ lịch sử?', style: TextStyle(color: _isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
        content: const Text('Hành động này không thể hoàn tác. Bạn có chắc chắn muốn xóa sạch sành sanh mọi phiên cày cuốc từ trước đến nay không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy', style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() {
                HistoryStorage.historyList.clear();
              });
              await HistoryStorage.saveHistoryToDisk();
            },
            child: const Text('Xóa sạch vĩnh viễn', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Color textColor = _isDark ? Colors.white : Colors.black87;
    Color cardBg = _isDark ? AppColors.cardBg : Colors.white;

    int totalMinutes = 0;
    for (var item in HistoryStorage.historyList) {
      totalMinutes += item.durationMinutes;
    }
    int hours = totalMinutes ~/ 60;
    int mins = totalMinutes % 60;
    String totalFocusedStr = hours > 0 ? '${hours}h ${mins}m' : '${mins}m';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
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
                    Text("Productivity History", style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text("Analytics and focus session records", style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                  ],
                ),
                if (HistoryStorage.historyList.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.delete_sweep, color: Colors.redAccent, size: 26),
                    onPressed: _clearAllHistory,
                    tooltip: 'Xóa toàn bộ lịch sử',
                  ),
              ],
            ),
            const SizedBox(height: 24),

            Text("⚡ PRODUCTIVITY CHART (WEEKLY)", style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(20)),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Weekly Total Focus", style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w500)),
                      Text(totalFocusedStr, style: const TextStyle(color: AppColors.primary, fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildChartBar('M', totalMinutes > 0 ? 0.8 : 0.1, true),
                      _buildChartBar('T', 0.2, false),
                      _buildChartBar('W', 0.4, false),
                      _buildChartBar('T', 0.1, false),
                      _buildChartBar('F', 0.5, false),
                      _buildChartBar('S', 0.3, false),
                      _buildChartBar('S', 0.0, false),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            Text("📜 FOCUS HISTORY LIST (${HistoryStorage.historyList.length})", style: TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
            const SizedBox(height: 12),
            HistoryStorage.historyList.isEmpty
                ? Container(
              padding: const EdgeInsets.all(30),
              alignment: Alignment.center,
              child: const Text('Chưa có lịch sử cày cuốc nào được lưu.', style: TextStyle(color: AppColors.textMuted)),
            )
                : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: HistoryStorage.historyList.length,
              itemBuilder: (context, index) {
                final record = HistoryStorage.historyList[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.amber.withValues(alpha: 0.15),
                      child: const Icon(Icons.bolt, color: Colors.amber, size: 18),
                    ),
                    title: Text(record.taskTitle, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text('${record.dateStr} | ${record.timeStr}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('+${record.durationMinutes}m', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 18),
                          onPressed: () => _deleteSingleRecord(index),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartBar(String day, double heightFactor, bool isToday) {
    return Column(
      children: [
        Container(
          width: 14,
          height: 100 * heightFactor,
          decoration: BoxDecoration(
            color: isToday ? AppColors.primary : AppColors.primary.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 8),
        Text(day, style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }
}