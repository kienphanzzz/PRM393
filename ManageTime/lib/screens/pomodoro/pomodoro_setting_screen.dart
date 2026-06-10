import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../main.dart';

class PomodoroSettingScreen extends StatefulWidget {
  final int currentFocus;
  final int currentShort;
  final int currentLong;
  final Function(int, int, int) onSettingsSaved;

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
  late double _focusMins;
  late double _shortMins;
  late double _longMins;
  final bool _isDark = ThemeController.isDark;

  @override
  void initState() {
    super.initState();
    _focusMins = widget.currentFocus.toDouble();
    _shortMins = widget.currentShort.toDouble();
    _longMins = widget.currentLong.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    Color bg = _isDark ? AppColors.background : Colors.grey.shade100;
    Color textColor = _isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back, color: textColor),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(height: 10),
              Text('Timer Settings', style: TextStyle(color: textColor, fontSize: 26, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Customize intervals to match your deep work flow', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              const SizedBox(height: 35),

              _buildSliderSection('🧘 Focus Duration', _focusMins, 10, 60, const Color(0xFFFF5252), (val) {
                setState(() => _focusMins = val);
              }),
              const SizedBox(height: 24),

              _buildSliderSection('☕ Short Break', _shortMins, 2, 15, const Color(0xFF4EF2D2), (val) {
                setState(() => _shortMins = val);
              }),
              const SizedBox(height: 24),

              _buildSliderSection('🛌 Long Break', _longMins, 5, 30, const Color(0xFF8E7CFF), (val) {
                setState(() => _longMins = val);
              }),

              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    widget.onSettingsSaved(_focusMins.toInt(), _shortMins.toInt(), _longMins.toInt());
                    Navigator.pop(context);
                  },
                  child: const Text('Save Timer Configuration', style: TextStyle(color: AppColors.background, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliderSection(String title, double currentVal, double min, double max, Color activeColor, ValueChanged<double> onChanged) {
    Color textColor = _isDark ? Colors.white : Colors.black87;
    Color cardBg = _isDark ? AppColors.cardBg : Colors.white;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
              Text('${currentVal.toInt()} mins', style: TextStyle(color: activeColor, fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 8),
          Slider(
            value: currentVal,
            min: min,
            max: max,
            activeColor: activeColor,
            inactiveColor: _isDark ? Colors.white12 : Colors.grey.shade300,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}