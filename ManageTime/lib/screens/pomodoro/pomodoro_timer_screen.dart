import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

import '../../core/constants.dart';
import '../../main.dart';
import '../../data/models/task_model.dart';
import '../../data/models/session_model.dart';

class PomodoroTimerScreen extends StatefulWidget {
  const PomodoroTimerScreen({super.key});

  @override
  State<PomodoroTimerScreen> createState() => _PomodoroTimerScreenState();
}

class _PomodoroTimerScreenState extends State<PomodoroTimerScreen>
    with SingleTickerProviderStateMixin {
  String _currentMode = 'Focus';

  int _focusMins = 25;
  int _shortMins = 5;
  int _longMins = 15;

  int _secondsRemaining = 25 * 60;
  int _sessionTargetSeconds = 25 * 60;

  bool _isRunning = false;
  bool _isMusicOn = false;
  bool _finishDialogShowing = false;

  String _selectedMusic = 'Deep Focus Lo-fi';
  String _visualMode = 'ring';

  DateTime? _sessionStartAt;
  int _pauseCount = 0;

  Timer? _stopCheckTimer;

  late AnimationController _pulseController;

  final List<String> _musicList = [
    'Deep Focus Lo-fi',
    'Rainy Night Piano',
    'Coffee Shop Ambience',
    'Nature Sounds (Birds)',
    'Classical Study Mix',
    'Cyberpunk Focus Beats',
  ];

  TaskModel? _selectedTask;

  StreamSubscription? _updateSub;
  StreamSubscription? _finishedSub;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
      lowerBound: 0.94,
      upperBound: 1.04,
    );

    _loadSettings();
    _listenService();

    ThemeController.themeNotifier.addListener(_rebuild);

    _stopCheckTimer = Timer.periodic(
      const Duration(milliseconds: 500),
          (timer) {
        if (ThemeController.requestToStop) {
          ThemeController.requestToStop = false;
          _handleInterruptionFromNotification();
        }
      },
    );
  }

  void _rebuild() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      _focusMins = prefs.getInt('pomo_focus') ?? 25;
      _shortMins = prefs.getInt('pomo_short') ?? 5;
      _longMins = prefs.getInt('pomo_long') ?? 15;
      _visualMode = prefs.getString('pomo_visual_mode') ?? 'ring';

      if (!_isRunning) {
        _secondsRemaining = _getModeSeconds();
        _sessionTargetSeconds = _getModeSeconds();
      }
    });
  }

  Future<void> _saveVisualMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pomo_visual_mode', mode);

    if (!mounted) return;

    setState(() {
      _visualMode = mode;
    });
  }

  int _getModeMins() {
    if (_currentMode == 'Short') return _shortMins;
    if (_currentMode == 'Long') return _longMins;
    return _focusMins;
  }

  int _getModeSeconds() {
    return _getModeMins() * 60;
  }

  int _elapsedSeconds() {
    final int elapsed = _sessionTargetSeconds - _secondsRemaining;

    if (elapsed < 0) return 0;
    if (elapsed > _sessionTargetSeconds) return _sessionTargetSeconds;

    return elapsed;
  }

  int _elapsedMinutesForSave() {
    final int elapsed = _elapsedSeconds();

    if (elapsed <= 0) return 0;

    return (elapsed / 60).ceil();
  }

  double _progressValue() {
    if (_sessionTargetSeconds <= 0) return 0;

    final double value = _elapsedSeconds() / _sessionTargetSeconds;

    return value.clamp(0.0, 1.0);
  }

  String _formatTimer(int seconds) {
    final int m = seconds ~/ 60;
    final int s = seconds % 60;

    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatShortDuration(int seconds) {
    final int m = seconds ~/ 60;
    final int s = seconds % 60;

    if (m <= 0) return '${s}s';
    return '${m}m ${s}s';
  }

  void _listenService() {
    final service = FlutterBackgroundService();

    _updateSub = service.on('update').listen((event) {
      if (!mounted || event == null) return;

      setState(() {
        _secondsRemaining = event['seconds'] ?? _secondsRemaining;
        _isRunning = event['isRunning'] ?? _isRunning;
      });

      if (_isRunning && !_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }

      if (!_isRunning && _pulseController.isAnimating) {
        _pulseController.stop();
      }
    });

    _finishedSub = service.on('finished').listen((event) {
      if (!mounted) return;

      _handleFinished();
    });
  }

  Future<void> _toggle() async {
    if (_currentMode == 'Focus' && _selectedTask == null && !_isRunning) {
      _showPickTask();
      return;
    }

    if (_selectedTask != null && _selectedTask!.isCompleted) {
      FlutterBackgroundService().invoke('kill');

      if (!mounted) return;

      setState(() {
        _selectedTask = null;
        _isRunning = false;
        _secondsRemaining = _getModeSeconds();
        _sessionTargetSeconds = _getModeSeconds();
        _sessionStartAt = null;
        _pauseCount = 0;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Task này đã hoàn thành. Hãy chọn hoặc tạo task mới.'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      return;
    }

    if (_isRunning) {
      _pauseSession(countPause: true);
      return;
    }

    await _startOrResumeSession();
  }

  Future<void> _startOrResumeSession() async {
    final service = FlutterBackgroundService();

    final bool isNewSession =
        _sessionStartAt == null || _secondsRemaining == _getModeSeconds();

    if (isNewSession) {
      _sessionStartAt = DateTime.now();
      _sessionTargetSeconds = _getModeSeconds();
      _pauseCount = 0;
    }

    final bool serviceRunning = await service.isRunning();

    if (!serviceRunning) {
      await service.startService();
      await Future.delayed(const Duration(milliseconds: 1200));
    }

    service.invoke('start', {
      'seconds': _secondsRemaining,
      'taskTitle': _selectedTask?.title ?? 'Tập trung',
      'musicTitle': _isMusicOn ? _selectedMusic : '',
    });

    if (!mounted) return;

    setState(() {
      _isRunning = true;
    });

    _pulseController.repeat(reverse: true);
  }

  void _pauseSession({
    required bool countPause,
  }) {
    FlutterBackgroundService().invoke('pause');

    if (!mounted) return;

    setState(() {
      _isRunning = false;

      if (countPause) {
        _pauseCount++;
      }
    });

    _pulseController.stop();
  }

  void _handleInterruptionFromNotification() {
    if (!mounted) return;

    setState(() {
      _isRunning = false;
    });

    _pulseController.stop();

    _showStopDialog(fromNotification: true);
  }

  Future<void> _showStopDialog({
    bool fromNotification = false,
  }) async {
    if (!fromNotification && _isRunning) {
      _pauseSession(countPause: true);
    }

    final int mins = _elapsedMinutesForSave();

    if (!mounted) return;

    final String? action = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.cardBg,
          title: const Text(
            '⚠️ Dừng phiên Pomodoro?',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Bạn đã tập trung được $mins phút.\nBạn muốn xử lý phiên này thế nào?',
            style: const TextStyle(
              color: Colors.white70,
              height: 1.4,
            ),
          ),
          actions: [
            if (!fromNotification)
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, 'continue'),
                child: const Text(
                  'Tiếp tục',
                  style: TextStyle(color: AppColors.primary),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'discard'),
              child: const Text(
                'Dừng không lưu',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              onPressed: () => Navigator.pop(dialogContext, 'save'),
              child: const Text(
                'Lưu & đánh giá',
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

    if (!mounted) return;

    if (action == 'continue') {
      await _startOrResumeSession();
      return;
    }

    if (action == 'discard') {
      _resetTimer(clearTask: true);
      return;
    }

    if (action == 'save') {
      if (mins > 0) {
        await _showFocusEvaluationDialog(
          status: 'Cancelled',
          actualMinutes: mins,
          completed: false,
        );
      } else {
        _resetTimer(clearTask: true);
      }
    }
  }

  Future<bool> _confirmInterruptAction({
    required String title,
    required String content,
    required String confirmText,
  }) async {
    if (!_isRunning) return true;

    final bool? result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.cardBg,
          title: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            content,
            style: const TextStyle(
              color: Colors.white70,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(
                'Ở lại',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                confirmText,
                style: const TextStyle(
                  color: AppColors.background,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  Future<void> _handleResetPressed() async {
    final bool allowed = await _confirmInterruptAction(
      title: 'Reset phiên hiện tại?',
      content:
      'Pomodoro đang chạy. Reset sẽ dừng phiên hiện tại và không lưu dữ liệu.',
      confirmText: 'Reset',
    );

    if (!allowed) return;

    _resetTimer(clearTask: _currentMode == 'Focus');
  }

  void _resetTimer({
    bool clearTask = false,
  }) {
    FlutterBackgroundService().invoke('kill');

    if (!mounted) return;

    setState(() {
      _isRunning = false;
      _secondsRemaining = _getModeSeconds();
      _sessionTargetSeconds = _getModeSeconds();
      _sessionStartAt = null;
      _pauseCount = 0;

      if (clearTask) {
        _selectedTask = null;
      }
    });

    _pulseController.stop();
  }

  Future<void> _changeMode(String mode) async {
    if (mode == _currentMode) return;

    final bool allowed = await _confirmInterruptAction(
      title: 'Đổi chế độ Pomodoro?',
      content:
      'Phiên hiện tại đang chạy. Đổi chế độ sẽ dừng phiên này và không lưu dữ liệu.',
      confirmText: 'Đổi',
    );

    if (!allowed) return;

    FlutterBackgroundService().invoke('kill');

    if (!mounted) return;

    setState(() {
      _currentMode = mode;
      _isRunning = false;
      _secondsRemaining =
          (mode == 'Focus'
              ? _focusMins
              : (mode == 'Short' ? _shortMins : _longMins)) *
              60;
      _sessionTargetSeconds = _secondsRemaining;
      _sessionStartAt = null;
      _pauseCount = 0;

      if (mode != 'Focus') {
        _selectedTask = null;
      }
    });

    _pulseController.stop();
  }

  Future<void> _handleFinished() async {
    if (_finishDialogShowing) return;

    if (_currentMode == 'Focus') {
      FlutterBackgroundService().invoke('kill');

      if (!mounted) return;

      setState(() {
        _isRunning = false;
        _secondsRemaining = 0;
      });

      _pulseController.stop();

      await _showFocusEvaluationDialog(
        status: 'Completed',
        actualMinutes: _getModeMins(),
        completed: true,
      );
    } else {
      FlutterBackgroundService().invoke('kill');

      if (!mounted) return;

      setState(() {
        _isRunning = false;
      });

      _pulseController.stop();

      await _switchModeAfterBreak();
    }
  }

  Future<void> _switchModeAfterBreak() async {
    if (!mounted) return;

    setState(() {
      _currentMode = 'Focus';
      _secondsRemaining = _focusMins * 60;
      _sessionTargetSeconds = _focusMins * 60;
      _sessionStartAt = null;
      _pauseCount = 0;
      _selectedTask = null;
      _isRunning = false;
    });
  }

  Future<void> _switchToShortBreakAfterSave() async {
    FlutterBackgroundService().invoke('kill');

    if (!mounted) return;

    setState(() {
      _currentMode = 'Short';
      _isRunning = false;
      _secondsRemaining = _shortMins * 60;
      _sessionTargetSeconds = _shortMins * 60;
      _sessionStartAt = null;
      _pauseCount = 0;
      _selectedTask = null;
    });

    _pulseController.stop();
  }

  int _calculateFocusScore({
    required String status,
    required int actualMinutes,
    required int targetMinutes,
    required int pauseCount,
    required String rating,
  }) {
    if (targetMinutes <= 0) return 0;

    final double completionRatio = actualMinutes / targetMinutes;

    int score = (completionRatio.clamp(0.0, 1.0) * 70).round();

    final int pauseScore = max(0, 20 - pauseCount * 5);
    score += pauseScore;

    if (rating == 'Good') {
      score += 10;
    } else if (rating == 'Normal') {
      score += 6;
    } else {
      score += 2;
    }

    if (status != 'Completed') {
      score = min(score, 65);
    }

    return score.clamp(0, 100).toInt();
  }

  Future<void> _showFocusEvaluationDialog({
    required String status,
    required int actualMinutes,
    required bool completed,
  }) async {
    if (_finishDialogShowing) return;

    _finishDialogShowing = true;

    String selectedRating = completed ? 'Good' : 'Normal';
    final TextEditingController noteController = TextEditingController();

    final int targetMinutes = _sessionTargetSeconds ~/ 60;

    if (!mounted) {
      _finishDialogShowing = false;
      noteController.dispose();
      return;
    }

    final Map<String, String>? result = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final int score = _calculateFocusScore(
              status: status,
              actualMinutes: actualMinutes,
              targetMinutes: targetMinutes,
              pauseCount: _pauseCount,
              rating: selectedRating,
            );

            return AlertDialog(
              backgroundColor: AppColors.cardBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              title: Text(
                completed
                    ? '🎉 Hoàn thành phiên Focus'
                    : '📝 Đánh giá phiên Focus',
                style: const TextStyle(
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildResultRow(
                      label: 'Task',
                      value: _selectedTask?.title ?? 'Phiên tự do',
                    ),
                    _buildResultRow(
                      label: 'Target',
                      value: '${targetMinutes}m',
                    ),
                    _buildResultRow(
                      label: 'Actual',
                      value: '${actualMinutes}m',
                    ),
                    _buildResultRow(
                      label: 'Pause',
                      value: '$_pauseCount lần',
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Focus Score',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$score/100',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _scoreLabel(score),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Bạn tự đánh giá phiên này:',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Column(
                      children: [
                        _buildRatingOption(
                          title: '😵 Mất tập trung',
                          value: 'Bad',
                          selected: selectedRating,
                          onTap: () {
                            setDialogState(() {
                              selectedRating = 'Bad';
                            });
                          },
                        ),
                        _buildRatingOption(
                          title: '🙂 Ổn',
                          value: 'Normal',
                          selected: selectedRating,
                          onTap: () {
                            setDialogState(() {
                              selectedRating = 'Normal';
                            });
                          },
                        ),
                        _buildRatingOption(
                          title: '🔥 Rất tốt',
                          value: 'Good',
                          selected: selectedRating,
                          onTap: () {
                            setDialogState(() {
                              selectedRating = 'Good';
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteController,
                      maxLines: 2,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Ghi chú ngắn về phiên này...',
                        hintStyle: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  onPressed: () {
                    Navigator.pop(dialogContext, {
                      'rating': selectedRating,
                      'note': noteController.text.trim(),
                    });
                  },
                  child: const Text(
                    'Lưu phiên',
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
      },
    );

    noteController.dispose();

    if (result == null) {
      _finishDialogShowing = false;
      return;
    }

    final String finalRating = result['rating'] ?? 'Normal';
    final String finalNote = result['note'] ?? '';

    final int finalScore = _calculateFocusScore(
      status: status,
      actualMinutes: actualMinutes,
      targetMinutes: targetMinutes,
      pauseCount: _pauseCount,
      rating: finalRating,
    );

    await _saveFocusHistory(
      status: status,
      actualMinutes: actualMinutes,
      focusScore: finalScore,
      rating: finalRating,
      note: finalNote,
    );

    if (!mounted) {
      _finishDialogShowing = false;
      return;
    }

    _finishDialogShowing = false;

    if (completed) {
      await _switchToShortBreakAfterSave();
    } else {
      _resetTimer(clearTask: true);
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã lưu dữ liệu Pomodoro và đánh giá'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _saveFocusHistory({
    required String status,
    required int actualMinutes,
    required int focusScore,
    required String rating,
    required String note,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final String email = prefs.getString('user_email') ?? '';

    final DateTime startAt = _sessionStartAt ?? DateTime.now();
    final DateTime endAt = DateTime.now();

    final FocusHistoryModel record = FocusHistoryModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      taskId: _selectedTask?.id ?? '',
      taskTitle: _selectedTask?.title ?? 'Phiên tự do',
      durationMinutes: actualMinutes,
      targetMinutes: _sessionTargetSeconds ~/ 60,
      actualMinutes: actualMinutes,
      dateStr: DateFormat('E, MMM dd').format(startAt),
      timeStr: DateFormat('HH:mm').format(startAt),
      startAt: startAt.toIso8601String(),
      endAt: endAt.toIso8601String(),
      dateKey: DateFormat('yyyy-MM-dd').format(startAt),
      weekKey: HistoryStorage.getWeekKey(startAt),
      monthKey: DateFormat('yyyy-MM').format(startAt),
      pauseCount: _pauseCount,
      focusScore: focusScore,
      rating: rating,
      note: note,
      visualMode: _visualMode,
      userEmail: email,
      status: status,
    );

    HistoryStorage.historyList.insert(0, record);

    await HistoryStorage.saveHistoryToDisk();
  }

  String _scoreLabel(int score) {
    if (score >= 90) return 'Excellent Focus';
    if (score >= 70) return 'Good Focus';
    if (score >= 50) return 'Average Focus';
    return 'Interrupted Focus';
  }

  Widget _buildResultRow({
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingOption({
    required String title,
    required String value,
    required String selected,
    required VoidCallback onTap,
  }) {
    final bool isSelected = selected == value;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.18)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? AppColors.primary : Colors.white70,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  void _showPickTask() {
    final List<TaskModel> availableTasks = TaskStorage.todoTasks
        .where((task) => task.isCompleted == false)
        .toList();

    showDialog(
      context: context,
      builder: (c) {
        return AlertDialog(
          backgroundColor: AppColors.cardBg,
          title: const Text(
            '🎯 Chọn mục tiêu',
            style: TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: availableTasks.isEmpty
                ? const Text(
              'Không còn task nào chưa hoàn thành.\nHãy tạo task mới trước khi bắt đầu Pomodoro.',
              style: TextStyle(
                color: Colors.white70,
                height: 1.4,
              ),
            )
                : ListView.builder(
              shrinkWrap: true,
              itemCount: availableTasks.length,
              itemBuilder: (ctx, i) {
                final TaskModel task = availableTasks[i];

                return ListTile(
                  title: Text(
                    task.title,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    '${task.priority} • ${task.deadline}',
                    style: const TextStyle(color: Colors.white54),
                  ),
                  onTap: () {
                    setState(() {
                      _selectedTask = task;
                    });

                    Navigator.pop(c);
                    _toggle();
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Đóng'),
            ),
          ],
        );
      },
    );
  }

  void _showMusicPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Chọn nhạc tập trung 🎧',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _musicList.length,
                  itemBuilder: (context, index) {
                    final String music = _musicList[index];
                    final bool isSelected = _selectedMusic == music;

                    return ListTile(
                      leading: Icon(
                        Icons.music_note,
                        color: isSelected ? AppColors.primary : Colors.grey,
                      ),
                      title: Text(
                        music,
                        style: TextStyle(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.white70,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(
                        Icons.check_circle,
                        color: AppColors.primary,
                        size: 20,
                      )
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedMusic = music;
                        });

                        Navigator.pop(context);

                        if (_isRunning) {
                          FlutterBackgroundService().invoke('start', {
                            'seconds': _secondsRemaining,
                            'taskTitle': _selectedTask?.title ?? 'Tập trung',
                            'musicTitle': _isMusicOn ? _selectedMusic : '',
                          });
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _toggleMusic(bool value) {
    setState(() {
      _isMusicOn = value;
    });

    if (_isRunning) {
      FlutterBackgroundService().invoke('start', {
        'seconds': _secondsRemaining,
        'taskTitle': _selectedTask?.title ?? 'Tập trung',
        'musicTitle': value ? _selectedMusic : '',
      });
    }
  }

  @override
  void dispose() {
    _updateSub?.cancel();
    _finishedSub?.cancel();
    _stopCheckTimer?.cancel();
    _pulseController.dispose();

    ThemeController.themeNotifier.removeListener(_rebuild);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color txt = ThemeController.isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildTab('Focus'),
                  _buildTab('Short'),
                  _buildTab('Long'),
                ],
              ),
              const SizedBox(height: 22),
              _buildMusicBox(txt),
              const SizedBox(height: 20),
              _buildVisualModeSwitcher(txt),
              const SizedBox(height: 18),
              ScaleTransition(
                scale: _isRunning
                    ? _pulseController
                    : const AlwaysStoppedAnimation(1.0),
                child: _buildTimerVisual(txt),
              ),
              const SizedBox(height: 14),
              Text(
                _selectedTask != null
                    ? '🎯 ĐANG LÀM: ${_selectedTask!.title.toUpperCase()}'
                    : _currentMode == 'Focus'
                    ? 'HÃY CHỌN MỘT NHIỆM VỤ!'
                    : 'ĐANG NGHỈ NGƠI',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  letterSpacing: 1.4,
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 18),
              _buildSessionInfo(txt),
              const SizedBox(height: 26),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.refresh,
                      color: txt,
                      size: 30,
                    ),
                    onPressed: _handleResetPressed,
                  ),
                  const SizedBox(width: 30),
                  GestureDetector(
                    onTap: _toggle,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Icon(
                        _isRunning ? Icons.pause : Icons.play_arrow,
                        size: 44,
                        color: AppColors.background,
                      ),
                    ),
                  ),
                  const SizedBox(width: 30),
                  IconButton(
                    icon: Icon(
                      Icons.stop_rounded,
                      color: txt,
                      size: 30,
                    ),
                    onPressed: () => _showStopDialog(),
                  ),
                ],
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMusicBox(Color txt) {
    return GestureDetector(
      onTap: _showMusicPicker,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: txt.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isMusicOn ? Icons.music_note : Icons.music_off,
              color: _isMusicOn ? AppColors.primary : Colors.grey,
              size: 18,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                _selectedMusic,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: txt,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Switch(
              value: _isMusicOn,
              activeColor: AppColors.primary,
              onChanged: _toggleMusic,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisualModeSwitcher(Color txt) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: txt.withOpacity(0.05),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildVisualButton(
            mode: 'ring',
            icon: Icons.donut_large_rounded,
            label: 'Ring',
          ),
          _buildVisualButton(
            mode: 'hourglass',
            icon: Icons.hourglass_bottom_rounded,
            label: 'Sand',
          ),
          _buildVisualButton(
            mode: 'clock',
            icon: Icons.access_time_rounded,
            label: 'Clock',
          ),
        ],
      ),
    );
  }

  Widget _buildVisualButton({
    required String mode,
    required IconData icon,
    required String label,
  }) {
    final bool selected = _visualMode == mode;

    return GestureDetector(
      onTap: () => _saveVisualMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? AppColors.background : AppColors.textMuted,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.background : AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerVisual(Color txt) {
    final double progress = _progressValue();
    final String time = _formatTimer(_secondsRemaining);

    if (_visualMode == 'hourglass') {
      return SizedBox(
        width: 260,
        height: 260,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: const Size(230, 230),
              painter: HourglassTimerPainter(
                progress: progress,
                color: AppColors.primary,
                backgroundColor: txt.withOpacity(0.16),
              ),
            ),
            Positioned(
              bottom: 20,
              child: Text(
                time,
                style: TextStyle(
                  color: txt,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -1,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_visualMode == 'clock') {
      return SizedBox(
        width: 260,
        height: 260,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: const Size(230, 230),
              painter: ClockTimerPainter(
                progress: progress,
                color: AppColors.primary,
                backgroundColor: txt.withOpacity(0.16),
              ),
            ),
            Text(
              time,
              style: TextStyle(
                color: txt,
                fontSize: 38,
                fontWeight: FontWeight.bold,
                letterSpacing: -1,
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: 270,
      height: 270,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(250, 250),
            painter: RingTimerPainter(
              progress: progress,
              color: AppColors.primary,
              backgroundColor: txt.withOpacity(0.12),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                time,
                style: TextStyle(
                  fontSize: 58,
                  fontWeight: FontWeight.bold,
                  color: txt,
                  letterSpacing: -2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${(progress * 100).round()}% completed',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSessionInfo(Color txt) {
    final String startedAt = _sessionStartAt == null
        ? '--:--'
        : DateFormat('HH:mm').format(_sessionStartAt!);

    final int elapsed = _elapsedSeconds();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: txt.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.16),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildInfoItem(
                title: 'Started',
                value: startedAt,
                icon: Icons.play_circle_outline_rounded,
              ),
              _buildInfoItem(
                title: 'Focused',
                value: _formatShortDuration(elapsed),
                icon: Icons.bolt_rounded,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildInfoItem(
                title: 'Remaining',
                value: _formatShortDuration(_secondsRemaining),
                icon: Icons.hourglass_bottom_rounded,
              ),
              _buildInfoItem(
                title: 'Pause',
                value: '$_pauseCount',
                icon: Icons.pause_circle_outline_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Expanded(
      child: Row(
        children: [
          Icon(
            icon,
            color: AppColors.primary,
            size: 18,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String mode) {
    final bool sel = _currentMode == mode;

    return GestureDetector(
      onTap: () => _changeMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: sel ? AppColors.primary : AppColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            if (sel)
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 10,
              ),
          ],
        ),
        child: Text(
          mode,
          style: TextStyle(
            color: sel ? AppColors.background : Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class RingTimerPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;

  RingTimerPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = size.width / 2 - 12;

    final Paint bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    final Paint progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    final Rect rect = Rect.fromCircle(
      center: center,
      radius: radius,
    );

    canvas.drawArc(
      rect,
      -pi / 2,
      2 * pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant RingTimerPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}

class HourglassTimerPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;

  HourglassTimerPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    final Offset topLeft = Offset(w * 0.25, h * 0.08);
    final Offset topRight = Offset(w * 0.75, h * 0.08);
    final Offset center = Offset(w * 0.5, h * 0.5);
    final Offset bottomLeft = Offset(w * 0.25, h * 0.92);
    final Offset bottomRight = Offset(w * 0.75, h * 0.92);

    final Path topTriangle = Path()
      ..moveTo(topLeft.dx, topLeft.dy)
      ..lineTo(topRight.dx, topRight.dy)
      ..lineTo(center.dx, center.dy)
      ..close();

    final Path bottomTriangle = Path()
      ..moveTo(center.dx, center.dy)
      ..lineTo(bottomLeft.dx, bottomLeft.dy)
      ..lineTo(bottomRight.dx, bottomRight.dy)
      ..close();

    final Paint outlinePaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    final Paint sandPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final double topFillRatio = (1 - progress).clamp(0.0, 1.0);
    final double bottomFillRatio = progress.clamp(0.0, 1.0);

    canvas.save();
    canvas.clipPath(topTriangle);
    canvas.drawRect(
      Rect.fromLTRB(
        0,
        topLeft.dy,
        w,
        topLeft.dy + (center.dy - topLeft.dy) * topFillRatio,
      ),
      sandPaint,
    );
    canvas.restore();

    canvas.save();
    canvas.clipPath(bottomTriangle);
    canvas.drawRect(
      Rect.fromLTRB(
        0,
        bottomRight.dy - (bottomRight.dy - center.dy) * bottomFillRatio,
        w,
        bottomRight.dy,
      ),
      sandPaint,
    );
    canvas.restore();

    if (progress > 0 && progress < 1) {
      final Paint linePaint = Paint()
        ..color = color
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(
        Offset(center.dx, center.dy - 18),
        Offset(center.dx, center.dy + 34),
        linePaint,
      );
    }

    final Path outline = Path()
      ..moveTo(topLeft.dx, topLeft.dy)
      ..lineTo(topRight.dx, topRight.dy)
      ..lineTo(center.dx, center.dy)
      ..lineTo(bottomRight.dx, bottomRight.dy)
      ..lineTo(bottomLeft.dx, bottomLeft.dy)
      ..lineTo(center.dx, center.dy)
      ..lineTo(topLeft.dx, topLeft.dy);

    canvas.drawPath(outline, outlinePaint);

    final Paint capPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(topLeft, topRight, capPaint);
    canvas.drawLine(bottomLeft, bottomRight, capPaint);
  }

  @override
  bool shouldRepaint(covariant HourglassTimerPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}

class ClockTimerPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;

  ClockTimerPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = size.width / 2 - 14;

    final Paint circlePaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;

    final Paint tickPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final Paint handPaint = Paint()
      ..color = color
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    final Paint dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, circlePaint);

    for (int i = 0; i < 12; i++) {
      final double angle = -pi / 2 + (2 * pi * i / 12);

      final Offset p1 = Offset(
        center.dx + cos(angle) * (radius - 12),
        center.dy + sin(angle) * (radius - 12),
      );

      final Offset p2 = Offset(
        center.dx + cos(angle) * radius,
        center.dy + sin(angle) * radius,
      );

      canvas.drawLine(p1, p2, tickPaint);
    }

    final double handAngle = -pi / 2 + 2 * pi * progress;

    final Offset handEnd = Offset(
      center.dx + cos(handAngle) * (radius * 0.72),
      center.dy + sin(handAngle) * (radius * 0.72),
    );

    canvas.drawLine(center, handEnd, handPaint);
    canvas.drawCircle(center, 8, dotPaint);

    final Rect arcRect = Rect.fromCircle(
      center: center,
      radius: radius,
    );

    final Paint arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      arcRect,
      -pi / 2,
      2 * pi * progress,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant ClockTimerPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}