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

  bool _isRunning = false;
  bool _isMusicOn = false;

  String _selectedMusic = 'Deep Focus Lo-fi';

  Timer? _stopCheckTimer;

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

      if (!_isRunning) {
        _secondsRemaining = _getModeMins() * 60;
      }
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

      _handleFinished('Completed');
    });
  }

  Future<void> _toggle() async {
    if (_currentMode == 'Focus' &&
        _selectedTask == null &&
        !_isRunning) {
      _showPickTask();
      return;
    }

    if (_selectedTask != null && _selectedTask!.isCompleted) {
      FlutterBackgroundService().invoke('kill');

      if (mounted) {
        setState(() {
          _selectedTask = null;
          _isRunning = false;
          _secondsRemaining = _getModeSeconds();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Task này đã hoàn thành. Hãy chọn hoặc tạo task mới.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      return;
    }

    final service = FlutterBackgroundService();

    if (_isRunning) {
      service.invoke('pause');

      if (mounted) {
        setState(() {
          _isRunning = false;
        });
      }

      return;
    }

    final bool serviceRunning = await service.isRunning();

    if (!serviceRunning) {
      await service.startService();

      await Future.delayed(
        const Duration(milliseconds: 1500),
      );
    }

    service.invoke('start', {
      'seconds': _secondsRemaining,
      'taskTitle': _selectedTask?.title ?? 'Tập trung',
      'musicTitle': _isMusicOn ? _selectedMusic : '',
    });

    if (mounted) {
      setState(() {
        _isRunning = true;
      });
    }
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
    final service = FlutterBackgroundService();

    if (!fromNotification && _isRunning) {
      service.invoke('pause');

      if (mounted) {
        setState(() {
          _isRunning = false;
        });
      }
    }

    final int elapsed = _getModeSeconds() - _secondsRemaining;
    final int mins = elapsed ~/ 60;

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) {
        return AlertDialog(
          backgroundColor: AppColors.cardBg,
          title: const Text(
            '⚠️ DỪNG PHIÊN TẬP TRUNG?',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Bạn đã tập trung được $mins phút. Bạn muốn xử lý phiên này thế nào?',
            style: const TextStyle(
              color: Colors.white70,
            ),
          ),
          actions: [
            if (!fromNotification)
              TextButton(
                onPressed: () {
                  Navigator.pop(c);

                  FlutterBackgroundService().invoke('start', {
                    'seconds': _secondsRemaining,
                    'taskTitle': _selectedTask?.title ?? 'Tập trung',
                    'musicTitle': _isMusicOn ? _selectedMusic : '',
                  });

                  if (mounted) {
                    setState(() {
                      _isRunning = true;
                    });
                  }
                },
                child: const Text(
                  'Tiếp tục',
                  style: TextStyle(
                    color: AppColors.primary,
                  ),
                ),
              ),
            TextButton(
              onPressed: () {
                Navigator.pop(c);
                _resetTimer();
              },
              child: const Text(
                'Dừng không lưu',
                style: TextStyle(
                  color: Colors.redAccent,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(c);

                if (mins > 0) {
                  _logHistory(mins, 'Cancelled');
                }

                _resetTimer();
              },
              child: const Text('Lưu & Dừng'),
            ),
          ],
        );
      },
    );
  }

  void _resetTimer() {
    FlutterBackgroundService().invoke('kill');

    if (!mounted) return;

    setState(() {
      _isRunning = false;
      _secondsRemaining = _getModeSeconds();

      if (_currentMode == 'Focus') {
        _selectedTask = null;
      }
    });
  }

  void _changeMode(String mode) {
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

      if (mode != 'Focus') {
        _selectedTask = null;
      }
    });
  }

  void _handleFinished(String status) {
    if (_currentMode == 'Focus') {
      _logHistory(_focusMins, status);
      _showCongrats();

      if (!mounted) return;

      setState(() {
        _isRunning = false;
      });

      _changeMode('Short');
    } else {
      if (!mounted) return;

      setState(() {
        _isRunning = false;
      });

      _changeMode('Focus');
    }
  }

  void _logHistory(int mins, String status) async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('user_email') ?? '';

    final record = FocusHistoryModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      taskTitle: _selectedTask?.title ?? 'Phiên tự do',
      durationMinutes: mins,
      dateStr: DateFormat('E, MMM dd').format(DateTime.now()),
      timeStr: DateFormat('hh:mm a').format(DateTime.now()),
      userEmail: email,
      status: status,
    );

    HistoryStorage.historyList.insert(0, record);
    await HistoryStorage.saveHistoryToDisk();
  }

  void _showCongrats() {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (c) {
        return AlertDialog(
          backgroundColor: AppColors.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            '🎉 HOÀN THÀNH!',
            style: TextStyle(
              color: Colors.amber,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'Bạn vừa hoàn thành một phiên tập trung tuyệt vời.',
            style: TextStyle(
              color: Colors.white70,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Tiếp tục'),
            ),
          ],
        );
      },
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
            style: TextStyle(
              color: Colors.white,
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
              itemBuilder: (ctx, i) {
                final TaskModel task = availableTasks[i];

                return ListTile(
                  title: Text(
                    task.title,
                    style: const TextStyle(
                      color: Colors.white,
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
                    final music = _musicList[index];
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

    ThemeController.themeNotifier.removeListener(_rebuild);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int m = _secondsRemaining ~/ 60;
    final int s = _secondsRemaining % 60;

    final Color txt = ThemeController.isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
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
            const SizedBox(height: 30),
            GestureDetector(
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
            ),
            const Spacer(),
            Text(
              '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 84,
                fontWeight: FontWeight.bold,
                color: txt,
                letterSpacing: -2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _selectedTask != null
                  ? '🎯 ĐANG LÀM: ${_selectedTask!.title.toUpperCase()}'
                  : _currentMode == 'Focus'
                  ? 'HÃY CHỌN MỘT NHIỆM VỤ!'
                  : 'ĐANG NGHỈ NGƠI',
              textAlign: TextAlign.center,
              style: const TextStyle(
                letterSpacing: 2,
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.refresh,
                    color: txt,
                    size: 30,
                  ),
                  onPressed: () => _changeMode(_currentMode),
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
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String mode) {
    final bool sel = _currentMode == mode;

    return GestureDetector(
      onTap: () => _changeMode(mode),
      child: Container(
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