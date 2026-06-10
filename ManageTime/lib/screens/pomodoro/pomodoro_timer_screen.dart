import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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
  bool _isRunning = false;

  int _completedSessions = 0;
  int _totalFocusedMinutes = 0;
  bool _isDark = ThemeController.isDark;

  TaskModel? _selectedTask;
  StreamSubscription? _updateSubscription;
  StreamSubscription? _finishedSubscription;

  @override
  void initState() {
    super.initState();
    _listenToBackgroundService();
    ThemeController.themeNotifier.addListener(_updateTheme);
  }

  void _updateTheme() {
    if (mounted) setState(() => _isDark = ThemeController.isDark);
  }

  @override
  void dispose() {
    _updateSubscription?.cancel();
    _finishedSubscription?.cancel();
    ThemeController.themeNotifier.removeListener(_updateTheme);
    super.dispose();
  }

  void _listenToBackgroundService() {
    final service = FlutterBackgroundService();
    
    _updateSubscription = service.on('update').listen((event) {
      if (mounted && _isRunning) {
        setState(() {
          _secondsRemaining = event?['seconds'] ?? _secondsRemaining;
        });
      }
    });

    _finishedSubscription = service.on('finished').listen((event) {
      if (mounted) {
        _handleSessionFinished();
      }
    });
  }

  void _changeMode(String mode) {
    FlutterBackgroundService().invoke('stop');
    setState(() {
      _isRunning = false;
      _currentMode = mode;
      if (mode == 'Focus') _secondsRemaining = _focusMinutes * 60;
      if (mode == 'Short') _secondsRemaining = _shortMinutes * 60;
      if (mode == 'Long') _secondsRemaining = _longMinutes * 60;
    });
  }

  void _toggleTimer() async {
    // Yêu cầu quyền thông báo trên Android 13+ nếu chưa có
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // Nếu chưa chọn task mà bấm chạy ở chế độ Focus thì bắt chọn
    if (_currentMode == 'Focus' && _selectedTask == null && !_isRunning) {
      _showPickTaskDialog();
      return;
    }

    final service = FlutterBackgroundService();
    
    if (_isRunning) {
      service.invoke('pause');
      setState(() => _isRunning = false);
    } else {
      try {
        if (!(await service.isRunning())) {
          await service.startService();
          // Chờ lâu hơn một chút để hệ thống Android 14 xử lý Foreground Service
          await Future.delayed(const Duration(milliseconds: 800));
        }

        service.invoke('start', {
          'seconds': _secondsRemaining,
          'taskTitle': _selectedTask?.title ?? 'Tập trung cao độ'
        });

        setState(() => _isRunning = true);
      } catch (e) {
        debugPrint('Lỗi khởi động service: $e');
      }
    }
  }

  void _resetTimer() {
    FlutterBackgroundService().invoke('stop');
    _changeMode(_currentMode);
  }

  void _handleInterruption() {
    if (!_isRunning) return;
    
    FlutterBackgroundService().invoke('pause');
    setState(() => _isRunning = false);

    int maxSeconds = _getMaxSecondsForMode();
    int minutesElapsed = (maxSeconds - _secondsRemaining) ~/ 60;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: _isDark ? AppColors.cardBg : Colors.white,
        title: const Text('⚠️ NGẮT QUÃNG PHIÊN'),
        content: Text('Bạn đã tập trung được $minutesElapsed phút. Lưu kết quả chứ?'),
        actions: [
          TextButton(onPressed: () { Navigator.pop(context); _resetTimer(); }, child: const Text('Hủy')),
          ElevatedButton(onPressed: () {
            Navigator.pop(context);
            if (minutesElapsed > 0) _logSessionToHistory(minutesElapsed);
            _resetTimer();
          }, child: const Text('Lưu')),
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
        _changeMode('Short'); 
      } else {
        _changeMode('Focus');
      }
    });
  }

  void _logSessionToHistory(int minutes) {
    String title = _selectedTask?.title ?? 'Phiên tập trung';
    DateTime now = DateTime.now();
    FocusHistoryModel record = FocusHistoryModel(
      id: now.millisecondsSinceEpoch.toString(),
      taskTitle: title,
      durationMinutes: minutes,
      dateStr: DateFormat('E, MMM dd').format(now),
      timeStr: DateFormat('hh:mm a').format(now),
    );
    HistoryStorage.historyList.insert(0, record);
    HistoryStorage.saveHistoryToDisk();
  }

  void _showPickTaskDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isDark ? AppColors.cardBg : Colors.white,
        title: const Text('🎯 Chọn nhiệm vụ'),
        content: SizedBox(
          width: double.maxFinite,
          child: TaskStorage.todoTasks.where((t) => !t.isCompleted).isEmpty
              ? const Text('Hãy tạo nhiệm vụ mới ở trang chủ!')
              : ListView.builder(
            shrinkWrap: true,
            itemCount: TaskStorage.todoTasks.where((t) => !t.isCompleted).length,
            itemBuilder: (context, index) {
              final task = TaskStorage.todoTasks.where((t) => !t.isCompleted).toList()[index];
              return ListTile(
                title: Text(task.title, style: TextStyle(color: _isDark ? Colors.white : Colors.black87)),
                subtitle: Text(task.deadline, style: const TextStyle(fontSize: 11)),
                onTap: () {
                  setState(() => _selectedTask = task);
                  Navigator.pop(context);
                  _toggleTimer();
                },
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng'))],
      ),
    );
  }

  String _getFormattedTime() {
    int mins = _secondsRemaining ~/ 60;
    int secs = _secondsRemaining % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
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
  Widget build(BuildContext context) {
    Color textColor = _isDark ? Colors.white : Colors.black87;
    Color cardBg = _isDark ? AppColors.cardBg : Colors.white;
    Color modeColor = _getThemeColor();
    double progress = (_completedSessions / 4) * 100;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(icon: Icon(Icons.task_alt, color: _selectedTask != null ? AppColors.primary : textColor.withOpacity(0.3)), onPressed: _showPickTaskDialog),
                const Text('FOCUS FLOW', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                IconButton(icon: const Icon(Icons.tune), onPressed: () {}),
              ],
            ),
            const SizedBox(height: 10),
            Text(_selectedTask != null ? '🎯 Target: ${_selectedTask!.title}' : 'Chạm để chọn mục tiêu', style: const TextStyle(color: AppColors.primary, fontSize: 13)),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(20)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTab('Focus', modeColor),
                  _buildTab('Short', modeColor),
                  _buildTab('Long', modeColor),
                ],
              ),
            ),
            const SizedBox(height: 50),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(width: 240, height: 240, child: CircularProgressIndicator(value: _secondsRemaining / _getMaxSecondsForMode(), strokeWidth: 8, color: modeColor, backgroundColor: cardBg)),
                Text(_getFormattedTime(), style: TextStyle(color: textColor, fontSize: 60, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 60),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(icon: const Icon(Icons.refresh), onPressed: _resetTimer),
                const SizedBox(width: 30),
                GestureDetector(onTap: _toggleTimer, child: CircleAvatar(radius: 35, backgroundColor: modeColor, child: Icon(_isRunning ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 40))),
                const SizedBox(width: 30),
                IconButton(icon: const Icon(Icons.stop_circle_outlined), onPressed: _handleInterruption),
              ],
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(24)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStat('$_completedSessions', 'Phiên'),
                  _buildStat('${_totalFocusedMinutes}m', 'Tập trung'),
                  _buildStat('${progress.toStringAsFixed(0)}%', 'Mục tiêu'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String mode, Color activeColor) {
    bool sel = _currentMode == mode;
    return GestureDetector(
      onTap: () => _changeMode(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(color: sel ? activeColor : Colors.transparent, borderRadius: BorderRadius.circular(16)),
        child: Text(mode, style: TextStyle(color: sel ? Colors.white : AppColors.textMuted, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildStat(String val, String lab) {
    return Column(children: [Text(val, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), Text(lab, style: const TextStyle(color: AppColors.textMuted, fontSize: 12))]);
  }
}