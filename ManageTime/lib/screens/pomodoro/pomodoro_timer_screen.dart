import 'dart:async';

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

class _PomodoroTimerScreenState extends State<PomodoroTimerScreen> {
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
  StreamSubscription? _updateSub;
  StreamSubscription? _finishedSub;

  TaskModel? _selectedTask;

  final List<String> _musicList = [
    'Deep Focus Lo-fi',
    'Rainy Night Piano',
    'Coffee Shop Ambience',
    'Nature Sounds (Birds)',
    'Classical Study Mix',
    'Cyberpunk Focus Beats',
  ];

  @override
  void initState() {
    super.initState();

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
  }

  void _handleInterruptionFromNotification() {
    if (!mounted) return;

    setState(() {
      _isRunning = false;
    });

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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
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
                  style: TextStyle(
                    color: AppColors.primary,
                  ),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'discard'),
              child: const Text(
                'Dừng không lưu',
                style: TextStyle(
                  color: Colors.redAccent,
                ),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
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
      content: 'Pomodoro đang chạy.\nReset sẽ dừng phiên hiện tại và không lưu dữ liệu.',
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
  }

  Future<void> _changeMode(String mode) async {
    if (mode == _currentMode) return;

    final bool allowed = await _confirmInterruptAction(
      title: 'Đổi chế độ Pomodoro?',
      content: 'Phiên hiện tại đang chạy.\nĐổi chế độ sẽ dừng phiên này và không lưu dữ liệu.',
      confirmText: 'Đổi',
    );

    if (!allowed) return;

    FlutterBackgroundService().invoke('kill');

    if (!mounted) return;

    setState(() {
      _currentMode = mode;
      _isRunning = false;
      _secondsRemaining = _getModeSeconds();
      _sessionTargetSeconds = _getModeSeconds();
      _sessionStartAt = null;
      _pauseCount = 0;

      if (mode != 'Focus') {
        _selectedTask = null;
      }
    });
  }

  Future<void> _handleFinished() async {
    if (_finishDialogShowing) return;

    if (_currentMode == 'Focus') {
      if (!mounted) return;

      setState(() {
        _isRunning = false;
        _secondsRemaining = 0;
      });

      await _showFocusEvaluationDialog(
        status: 'Completed',
        actualMinutes: _getModeMins(),
        completed: true,
      );
    } else {
      FlutterBackgroundService().invoke('kill');

      if (!mounted) return;

      setState(() {
        _currentMode = 'Focus';
        _isRunning = false;
        _secondsRemaining = _focusMins * 60;
        _sessionTargetSeconds = _focusMins * 60;
        _sessionStartAt = null;
        _pauseCount = 0;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã kết thúc thời gian nghỉ. Quay lại Focus nhé!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  int _calculateFocusScore({
    required String status,
    required int actualMinutes,
    required int targetMinutes,
    required int pauseCount,
    required String rating,
  }) {
    int score = 0;

    if (targetMinutes > 0) {
      final double ratio = actualMinutes / targetMinutes;
      score += (ratio.clamp(0.0, 1.0) * 60).round();
    }

    if (status == 'Completed') {
      score += 25;
    } else {
      score += 10;
    }

    score -= pauseCount * 5;

    if (rating == 'Good') {
      score += 15;
    } else if (rating == 'Normal') {
      score += 8;
    } else {
      score -= 5;
    }

    return score.clamp(0, 100);
  }

  String _scoreLabel(int score) {
    if (score >= 85) return 'Rất tập trung';
    if (score >= 65) return 'Khá tốt';
    if (score >= 45) return 'Ổn nhưng cần cải thiện';
    return 'Dễ mất tập trung';
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
                          title: '😐 Ổn',
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
                      style: const TextStyle(
                        color: Colors.white,
                      ),
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
                  onPressed: () async {
                    FocusScope.of(dialogContext).unfocus();

                    final Map<String, String> data = {
                      'rating': selectedRating,
                      'note': noteController.text.trim(),
                    };

                    await Future.delayed(
                      const Duration(milliseconds: 150),
                    );

                    if (Navigator.of(dialogContext).canPop()) {
                      Navigator.of(dialogContext).pop(data);
                    }
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

    await Future.delayed(const Duration(milliseconds: 150));
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

    final DateTime now = DateTime.now();
    final DateTime startAt = _sessionStartAt ??
        now.subtract(
          Duration(
            minutes: actualMinutes,
          ),
        );

    final int targetMinutes = _sessionTargetSeconds ~/ 60;

    final record = FocusHistoryModel(
      id: now.millisecondsSinceEpoch.toString(),
      taskTitle: _selectedTask?.title ?? 'Phiên tự do',
      durationMinutes: actualMinutes,
      dateStr: DateFormat('E, MMM dd').format(now),
      timeStr: DateFormat('hh:mm a').format(now),
      userEmail: email,
      status: status,
      taskId: _selectedTask?.id ?? '',
      targetMinutes: targetMinutes,
      actualMinutes: actualMinutes,
      startAt: startAt.toIso8601String(),
      endAt: now.toIso8601String(),
      dateKey: DateFormat('yyyy-MM-dd').format(now),
      weekKey: HistoryStorage.getWeekKey(now),
      monthKey: DateFormat('yyyy-MM').format(now),
      pauseCount: _pauseCount,
      focusScore: focusScore,
      rating: rating,
      note: note,
      visualMode: _visualMode,
    );

    HistoryStorage.historyList.insert(0, record);
    await HistoryStorage.saveHistoryToDisk();
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
  }

  Widget _buildResultRow({
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 8,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
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
    final bool isSelected = value == selected;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(
          bottom: 8,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.18)
              : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? AppColors.primary : Colors.white70,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            '🎯 Chọn nhiệm vụ',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
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
              itemBuilder: (context, index) {
                final TaskModel task = availableTasks[index];

                return Container(
                  margin: const EdgeInsets.only(
                    bottom: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                      _priorityColor(task.priority).withOpacity(0.15),
                      child: Icon(
                        Icons.flag_rounded,
                        color: _priorityColor(task.priority),
                      ),
                    ),
                    title: Text(
                      task.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      '${task.priority} • ${task.deadline}',
                      style: const TextStyle(
                        color: Colors.white54,
                      ),
                    ),
                    onTap: () {
                      setState(() {
                        _selectedTask = task;
                      });

                      Navigator.pop(dialogContext);
                      _toggle();
                    },
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                'Đóng',
                style: TextStyle(
                  color: AppColors.primary,
                ),
              ),
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
                        Icons.music_note_rounded,
                        color: isSelected ? AppColors.primary : Colors.grey,
                      ),
                      title: Text(
                        music,
                        style: TextStyle(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.white70,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
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

  Color _priorityColor(String priority) {
    final String p = priority.toLowerCase();

    if (p.contains('high')) return Colors.redAccent;
    if (p.contains('medium')) return Colors.amber;
    if (p.contains('low')) return Colors.grey;

    return AppColors.primary;
  }

  String _modeSubtitle() {
    if (_currentMode == 'Short') return 'Short Break';
    if (_currentMode == 'Long') return 'Long Break';
    return 'Deep Focus';
  }

  String _mainStatusText() {
    if (_currentMode == 'Focus') {
      if (_selectedTask == null) {
        return 'Hãy chọn một nhiệm vụ để bắt đầu';
      }

      return 'Đang làm: ${_selectedTask!.title}';
    }

    if (_currentMode == 'Short') {
      return 'Nghỉ ngắn để nạp lại năng lượng';
    }

    return 'Nghỉ dài sau nhiều phiên tập trung';
  }

  @override
  void dispose() {
    _updateSub?.cancel();
    _finishedSub?.cancel();
    _stopCheckTimer?.cancel();

    ThemeController.themeNotifier.removeListener(_rebuild);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = ThemeController.isDark;

    final Color pageBg =
    isDark ? AppColors.background : const Color(0xFFF7F8FA);
    final Color cardBg = isDark ? AppColors.cardBg : Colors.white;
    final Color textColor = isDark ? Colors.white : Colors.black87;
    final Color subTextColor = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      backgroundColor: pageBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            20,
            18,
            20,
            26,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Pomodoro',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _handleResetPressed,
                    icon: Icon(
                      Icons.refresh_rounded,
                      color: textColor,
                    ),
                  ),
                  IconButton(
                    onPressed: _showMusicPicker,
                    icon: Icon(
                      Icons.music_note_rounded,
                      color: _isMusicOn ? AppColors.primary : textColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    if (!isDark)
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                  ],
                ),
                child: Row(
                  children: [
                    _buildModeTab(
                      mode: 'Focus',
                      label: 'Focus',
                      textColor: textColor,
                    ),
                    _buildModeTab(
                      mode: 'Short',
                      label: 'Short',
                      textColor: textColor,
                    ),
                    _buildModeTab(
                      mode: 'Long',
                      label: 'Long',
                      textColor: textColor,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    if (!isDark)
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      _modeSubtitle(),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _mainStatusText(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: subTextColor,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 26),
                    SizedBox(
                      width: 250,
                      height: 250,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 245,
                            height: 245,
                            child: CircularProgressIndicator(
                              value: _progressValue(),
                              strokeWidth: 14,
                              backgroundColor:
                              AppColors.textMuted.withOpacity(0.18),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                AppColors.primary,
                              ),
                            ),
                          ),
                          Container(
                            width: 205,
                            height: 205,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary.withOpacity(0.06),
                              border: Border.all(
                                color: AppColors.primary.withOpacity(0.2),
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _formatTimer(_secondsRemaining),
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 46,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -1,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _isRunning
                                      ? 'Đang chạy'
                                      : _secondsRemaining == _getModeSeconds()
                                      ? 'Sẵn sàng'
                                      : 'Đang tạm dừng',
                                  style: TextStyle(
                                    color: subTextColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildRoundButton(
                          icon: Icons.stop_rounded,
                          onTap: () => _showStopDialog(),
                          bgColor: Colors.redAccent.withOpacity(0.14),
                          iconColor: Colors.redAccent,
                        ),
                        const SizedBox(width: 22),
                        GestureDetector(
                          onTap: _toggle,
                          child: Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.35),
                                  blurRadius: 24,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: Icon(
                              _isRunning
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: AppColors.background,
                              size: 46,
                            ),
                          ),
                        ),
                        const SizedBox(width: 22),
                        _buildRoundButton(
                          icon: Icons.restart_alt_rounded,
                          onTap: _handleResetPressed,
                          bgColor: AppColors.primary.withOpacity(0.14),
                          iconColor: AppColors.primary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (_selectedTask != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: _priorityColor(
                          _selectedTask!.priority,
                        ).withOpacity(0.15),
                        child: Icon(
                          Icons.flag_rounded,
                          color: _priorityColor(_selectedTask!.priority),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedTask!.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_selectedTask!.priority} • ${_selectedTask!.deadline}',
                              style: TextStyle(
                                color: subTextColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _isRunning
                            ? null
                            : () {
                          setState(() {
                            _selectedTask = null;
                          });
                        },
                        icon: Icon(
                          Icons.close_rounded,
                          color: _isRunning
                              ? AppColors.textMuted.withOpacity(0.35)
                              : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isMusicOn
                              ? Icons.music_note_rounded
                              : Icons.music_off_rounded,
                          color: _isMusicOn
                              ? AppColors.primary
                              : AppColors.textMuted,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: _showMusicPicker,
                            child: Text(
                              _isMusicOn
                                  ? _selectedMusic
                                  : 'Nhạc tập trung đang tắt',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        Switch(
                          value: _isMusicOn,
                          activeColor: AppColors.primary,
                          onChanged: _toggleMusic,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildVisualModeChip(
                            label: 'Ring',
                            value: 'ring',
                            icon: Icons.donut_large_rounded,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildVisualModeChip(
                            label: 'Minimal',
                            value: 'minimal',
                            icon: Icons.center_focus_strong_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          color: AppColors.textMuted,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Đã làm: ${_formatShortDuration(_elapsedSeconds())}',
                          style: TextStyle(
                            color: subTextColor,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Pause: $_pauseCount',
                          style: TextStyle(
                            color: subTextColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeTab({
    required String mode,
    required String label,
    required Color textColor,
  }) {
    final bool selected = _currentMode == mode;

    return Expanded(
      child: GestureDetector(
        onTap: () => _changeMode(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(
            vertical: 13,
          ),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? AppColors.background : textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoundButton({
    required IconData icon,
    required VoidCallback onTap,
    required Color bgColor,
    required Color iconColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: iconColor,
          size: 28,
        ),
      ),
    );
  }

  Widget _buildVisualModeChip({
    required String label,
    required String value,
    required IconData icon,
  }) {
    final bool selected = _visualMode == value;

    return GestureDetector(
      onTap: () => _saveVisualMode(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withOpacity(0.15)
              : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: selected ? AppColors.primary : AppColors.textMuted,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.primary : AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}