import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../main.dart';
import '../../data/models/task_model.dart';
import '../../data/models/session_model.dart';
import 'pomodoro_setting_screen.dart';

class PomodoroTimerScreen extends StatefulWidget {
  const PomodoroTimerScreen({super.key});

  @override
  State<PomodoroTimerScreen> createState() => _PomodoroTimerScreenState();
}

class _PomodoroTimerScreenState extends State<PomodoroTimerScreen> {
  String _currentMode = 'Focus';
  int _focusMinutes = 25;
  int _shortMinutes = 5;
  int _longMinutes = 15;

  int _secondsRemaining = 25 * 60;
  Timer? _timer;
  bool _isRunning = false;

  int _completedSessions = 0;
  int _totalFocusedMinutes = 0;
  final bool _isDark = ThemeController.isDark;

  TaskModel? _selectedTask;

  void _changeMode(String mode) {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _currentMode = mode;
      if (mode == 'Focus') _secondsRemaining = _focusMinutes * 60;
      if (mode == 'Short') _secondsRemaining = _shortMinutes * 60;
      if (mode == 'Long') _secondsRemaining = _longMinutes * 60;
    });
  }

  void _toggleTimer() {
    if (_currentMode == 'Focus' && _selectedTask == null && !_isRunning) {
      _showPickTaskDialog();
      return;
    }

    if (_isRunning) {
      _timer?.cancel();
      setState(() {
        _isRunning = false;
      });
    } else {
      setState(() {
        _isRunning = true;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_secondsRemaining > 0) {
          setState(() {
            _secondsRemaining--;
          });
        } else {
          _timer?.cancel();
          _handleSessionFinished();
        }
      });
    }
  }

  void _resetTimer() {
    _timer?.cancel();
    _changeMode(_currentMode);
  }

  void _handleInterruption() {
    if (!_isRunning) return;
    _timer?.cancel();
    setState(() {
      _isRunning = false;
    });

    int maxSeconds = _getMaxSecondsForMode();
    int secondsElapsed = maxSeconds - _secondsRemaining;
    int minutesElapsed = secondsElapsed ~/ 60;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isDark ? AppColors.cardBg : Colors.white,
        title: Text('Hành Động Ngắt Ngang Đột Xuất', style: TextStyle(color: _isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
        content: Text('Bạn vừa bị ngắt ngang phiên làm việc. Bạn đã tập trung được $minutesElapsed phút. Bạn có muốn lưu lại kết quả nỗ lực này không?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetTimer();
            },
            child: const Text('Hủy bỏ phiên', style: TextStyle(color: Colors.redAccent)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (minutesElapsed > 0) {
                _logSessionToHistory(minutesElapsed);
              }
              _resetTimer();
            },
            child: const Text('Lưu kết quả phần cứng', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _handleSessionFinished() {
    setState(() {
      _isRunning = false;
      if (_currentMode == 'Focus') {
        _completedSessions++;
        _totalFocusedMinutes += _focusMinutes;
        _logSessionToHistory(_focusMinutes);
        _showFinishedDialog('Focus Session Finished!', 'Tuyệt vời Kiên ơi! Đã hoàn thành trọn vẹn phiên làm việc.');
        _changeMode('Short');
      } else {
        _showFinishedDialog('Break Time Ended!', 'Hết thời gian nghỉ ngơi, quay lại luồng tập trung thôi nào!');
        _changeMode('Focus');
      }
    });
  }

  void _logSessionToHistory(int minutes) {
    String currentTaskTitle = _selectedTask?.title ?? 'General Focus Session';
    DateTime now = DateTime.now();

    FocusHistoryModel newRecord = FocusHistoryModel(
      id: now.toString(),
      taskTitle: currentTaskTitle,
      durationMinutes: minutes,
      dateStr: DateFormat('E, MMM dd').format(now),
      timeStr: DateFormat('hh:mm a').format(now),
    );

    HistoryStorage.historyList.insert(0, newRecord);
    HistoryStorage.saveHistoryToDisk();
  }

  void _showPickTaskDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isDark ? AppColors.cardBg : Colors.white,
        title: Text('Chọn việc đầu ngày cần làm', style: TextStyle(color: _isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: TaskStorage.todoTasks.isEmpty
              ? const Text('Danh sách việc trống. Vui lòng tạo Task trước.', style: TextStyle(color: AppColors.textMuted))
              : ListView.builder(
            shrinkWrap: true,
            itemCount: TaskStorage.todoTasks.length,
            itemBuilder: (context, index) {
              final task = TaskStorage.todoTasks[index];
              return ListTile(
                title: Text(task.title, style: TextStyle(color: _isDark ? Colors.white : Colors.black87)),
                subtitle: Text(task.deadline, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                trailing: const Icon(Icons.play_circle_outline, color: AppColors.primary),
                onTap: () {
                  setState(() {
                    _selectedTask = task;
                  });
                  Navigator.pop(context);
                  _toggleTimer();
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng', style: TextStyle(color: AppColors.textMuted)),
          )
        ],
      ),
    );
  }

  void _showFinishedDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isDark ? AppColors.cardBg : Colors.white,
        title: Text(title, style: TextStyle(color: _isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
        content: Text(content, style: TextStyle(color: _isDark ? Colors.white70 : Colors.black54)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String _getFormattedTime() {
    int minutes = _secondsRemaining ~/ 60;
    int seconds = _secondsRemaining % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Color _getThemeColor() {
    if (_currentMode == 'Short') return const Color(0xFF4EF2D2);
    if (_currentMode == 'Long') return const Color(0xFF8E7CFF);
    return const Color(0xFFFF5252);
  }

  int _getMaxSecondsForMode() {
    if (_currentMode == 'Short') return _shortMinutes * 60;
    if (_currentMode == 'Long') return _longMinutes * 60;
    return _focusMinutes * 60;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color textColor = _isDark ? Colors.white : Colors.black87;
    Color cardBg = _isDark ? AppColors.cardBg : Colors.white;
    Color modeColor = _getThemeColor();

    int dailyGoalSessions = 4;
    double progressPercent = (_completedSessions / dailyGoalSessions) * 100;
    if (progressPercent > 100) progressPercent = 100;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.assignment_turned_in_outlined, color: _selectedTask != null ? AppColors.primary : textColor.withOpacity(0.4)),
                  onPressed: _isRunning ? null : _showPickTaskDialog,
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.av_timer, color: AppColors.primary, size: 20),
                    const SizedBox(width: 6),
                    Text('Focused Flow', style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.settings, color: textColor.withOpacity(0.7), size: 22),
                  onPressed: _isRunning ? null : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PomodoroSettingScreen(
                          currentFocus: _focusMinutes,
                          currentShort: _shortMinutes,
                          currentLong: _longMinutes,
                          onSettingsSaved: (f, s, l) {
                            setState(() {
                              _focusMinutes = f;
                              _shortMinutes = s;
                              _longMinutes = l;
                              _changeMode(_currentMode);
                            });
                          },
                        ),
                      ),
                    );
                  },
                )
              ],
            ),

            GestureDetector(
              onTap: _isRunning ? null : _showPickTaskDialog,
              child: Container(
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(color: _selectedTask != null ? AppColors.primary.withOpacity(0.15) : Colors.transparent, borderRadius: BorderRadius.circular(20)),
                child: Text(
                  _selectedTask != null ? '🎯 Target: ${_selectedTask!.title}' : '👉 Chạm để chọn việc cần làm đầu ngày',
                  style: TextStyle(color: _selectedTask != null ? AppColors.primary : AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(20)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildModeTab('Focus', '${_focusMinutes}m Focus', modeColor),
                  _buildModeTab('Short', '${_shortMinutes}m Short', modeColor),
                  _buildModeTab('Long', '${_longMinutes}m Long', modeColor),
                ],
              ),
            ),
            const SizedBox(height: 40),

            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 220,
                    height: 220,
                    child: CircularProgressIndicator(
                      value: _secondsRemaining / _getMaxSecondsForMode(),
                      strokeWidth: 5,
                      valueColor: AlwaysStoppedAnimation<Color>(modeColor),
                      backgroundColor: cardBg,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _getFormattedTime(),
                        style: TextStyle(color: textColor, fontSize: 52, fontWeight: FontWeight.bold, letterSpacing: -1),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _currentMode == 'Focus' ? 'Focus Time' : (_currentMode == 'Short' ? 'Short Break' : 'Long Break'),
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(Icons.refresh, color: textColor.withOpacity(0.6), size: 22),
                  onPressed: _resetTimer,
                ),
                const SizedBox(width: 24),
                GestureDetector(
                  onTap: _toggleTimer,
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor: modeColor.withOpacity(0.2),
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor: modeColor,
                      child: Icon(_isRunning ? Icons.pause : Icons.play_arrow, color: AppColors.background, size: 28),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                IconButton(
                  icon: Icon(Icons.do_not_disturb_on_outlined, color: _isRunning ? Colors.orangeAccent : textColor.withOpacity(0.2), size: 24),
                  onPressed: _isRunning ? _handleInterruption : null,
                ),
              ],
            ),
            const Spacer(),

            Container(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
              decoration: BoxDecoration(
                color: cardBg.withOpacity(0.4),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatColumn('$_completedSessions', 'Sessions', textColor),
                  _buildStatColumn('${_totalFocusedMinutes}m', 'Focused', textColor),
                  _buildStatColumn('${progressPercent.toStringAsFixed(0)}%', 'of Goal', textColor),
                ],
              ),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  Widget _buildModeTab(String mode, String label, Color activeColor) {
    bool isSelected = _currentMode == mode;
    return GestureDetector(
      onTap: _isRunning ? null : () => _changeMode(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.background : AppColors.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn(String value, String label, Color textColor) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
      ],
    );
  }
}