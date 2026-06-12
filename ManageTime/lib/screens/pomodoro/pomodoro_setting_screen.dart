import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants.dart';
import '../../main.dart';

class PomodoroSettingScreen extends StatefulWidget {
  final int currentFocus;
  final int currentShort;
  final int currentLong;
  final Function(int focus, int shortBreak, int longBreak) onSettingsSaved;

  const PomodoroSettingScreen({
    super.key,
    required this.currentFocus,
    required this.currentShort,
    required this.currentLong,
    required this.onSettingsSaved,
  });

  @override
  State<PomodoroSettingScreen> createState() => _PomodoroSettingScreenState();
}

class _PomodoroSettingScreenState extends State<PomodoroSettingScreen> {
  static const int defaultFocus = 25;
  static const int defaultShort = 5;
  static const int defaultLong = 15;

  late int _focusMins;
  late int _shortMins;
  late int _longMins;

  bool _isDark = ThemeController.isDark;

  @override
  void initState() {
    super.initState();

    _focusMins = widget.currentFocus;
    _shortMins = widget.currentShort;
    _longMins = widget.currentLong;

    ThemeController.themeNotifier.addListener(_updateTheme);
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
    ThemeController.themeNotifier.removeListener(_updateTheme);
    super.dispose();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt('pomo_focus', _focusMins);
    await prefs.setInt('pomo_short', _shortMins);
    await prefs.setInt('pomo_long', _longMins);

    widget.onSettingsSaved(
      _focusMins,
      _shortMins,
      _longMins,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã lưu cấu hình Pomodoro'),
        behavior: SnackBarBehavior.floating,
      ),
    );

    Navigator.pop(context);
  }

  Future<void> _resetToDefault() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _isDark ? AppColors.cardBg : Colors.white,
          title: Text(
            'Reset cấu hình?',
            style: TextStyle(
              color: _isDark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Pomodoro sẽ quay về mặc định:\n\n'
                '• Focus: 25 phút\n'
                '• Short Break: 5 phút\n'
                '• Long Break: 15 phút',
            style: TextStyle(
              color: _isDark ? Colors.white70 : Colors.black54,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(
                'Hủy',
                style: TextStyle(
                  color: AppColors.textMuted,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(
                'Reset',
                style: TextStyle(
                  color: AppColors.background,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() {
      _focusMins = defaultFocus;
      _shortMins = defaultShort;
      _longMins = defaultLong;
    });

    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt('pomo_focus', defaultFocus);
    await prefs.setInt('pomo_short', defaultShort);
    await prefs.setInt('pomo_long', defaultLong);

    widget.onSettingsSaved(
      defaultFocus,
      defaultShort,
      defaultLong,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã reset Pomodoro về mặc định 25 - 5 - 15'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color textColor = _isDark ? Colors.white : Colors.black87;
    final Color subTextColor = _isDark ? Colors.white70 : Colors.black54;
    final Color cardBg = _isDark ? AppColors.cardBg : Colors.white;
    final Color pageBg =
    _isDark ? AppColors.background : const Color(0xFFF8F9FA);

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: textColor,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Pomodoro Settings',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Reset mặc định',
            icon: const Icon(
              Icons.restart_alt_rounded,
              color: AppColors.primary,
            ),
            onPressed: _resetToDefault,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Timer Configuration',
              style: TextStyle(
                color: textColor,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tùy chỉnh thời lượng cho phiên tập trung và nghỉ ngơi.',
              style: TextStyle(
                color: subTextColor,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),

            _buildTimeCard(
              title: 'Focus Time',
              subtitle: 'Thời gian tập trung chính',
              icon: Icons.timer_rounded,
              value: _focusMins,
              min: 10,
              max: 60,
              color: AppColors.primary,
              cardBg: cardBg,
              textColor: textColor,
              subTextColor: subTextColor,
              onChanged: (value) {
                setState(() {
                  _focusMins = value.round();
                });
              },
            ),

            const SizedBox(height: 18),

            _buildTimeCard(
              title: 'Short Break',
              subtitle: 'Nghỉ ngắn sau một phiên Focus',
              icon: Icons.coffee_rounded,
              value: _shortMins,
              min: 3,
              max: 20,
              color: Colors.greenAccent,
              cardBg: cardBg,
              textColor: textColor,
              subTextColor: subTextColor,
              onChanged: (value) {
                setState(() {
                  _shortMins = value.round();
                });
              },
            ),

            const SizedBox(height: 18),

            _buildTimeCard(
              title: 'Long Break',
              subtitle: 'Nghỉ dài sau nhiều phiên Focus',
              icon: Icons.weekend_rounded,
              value: _longMins,
              min: 10,
              max: 40,
              color: Colors.orangeAccent,
              cardBg: cardBg,
              textColor: textColor,
              subTextColor: subTextColor,
              onChanged: (value) {
                setState(() {
                  _longMins = value.round();
                });
              },
            ),

            const SizedBox(height: 28),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.25),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Mặc định Pomodoro: 25 phút Focus, 5 phút nghỉ ngắn, 15 phút nghỉ dài.',
                      style: TextStyle(
                        color: subTextColor,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(
                    color: AppColors.primary,
                    width: 1.2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _resetToDefault,
                icon: const Icon(
                  Icons.restart_alt_rounded,
                  color: AppColors.primary,
                ),
                label: const Text(
                  'Reset to Default',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _saveSettings,
                icon: const Icon(
                  Icons.save_rounded,
                  color: AppColors.background,
                ),
                label: const Text(
                  'Save Timer Configuration',
                  style: TextStyle(
                    color: AppColors.background,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required int value,
    required int min,
    required int max,
    required Color color,
    required Color cardBg,
    required Color textColor,
    required Color subTextColor,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDark ? 0.25 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: color,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: subTextColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$value',
                style: TextStyle(
                  color: color,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'min',
                style: TextStyle(
                  color: subTextColor,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Slider(
            value: value.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: max - min,
            activeColor: color,
            inactiveColor: color.withOpacity(0.16),
            label: '$value phút',
            onChanged: onChanged,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$min min',
                style: TextStyle(
                  color: subTextColor,
                  fontSize: 11,
                ),
              ),
              Text(
                '$max min',
                style: TextStyle(
                  color: subTextColor,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}