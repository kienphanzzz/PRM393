import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FocusHistoryModel {
  final String id;
  final String taskTitle;
  final int durationMinutes;
  final String dateStr;
  final String timeStr;
  final String userEmail;
  final String status;

  final String taskId;
  final int targetMinutes;
  final int actualMinutes;
  final String startAt;
  final String endAt;
  final String dateKey;
  final String weekKey;
  final String monthKey;
  final int pauseCount;
  final int focusScore;
  final String rating;
  final String note;
  final String visualMode;

  FocusHistoryModel({
    required this.id,
    required this.taskTitle,
    required this.durationMinutes,
    required this.dateStr,
    required this.timeStr,
    required this.userEmail,
    this.status = 'Completed',
    this.taskId = '',
    int? targetMinutes,
    int? actualMinutes,
    String? startAt,
    String? endAt,
    String? dateKey,
    String? weekKey,
    String? monthKey,
    this.pauseCount = 0,
    this.focusScore = 0,
    this.rating = 'Normal',
    this.note = '',
    this.visualMode = 'ring',
  })  : targetMinutes = targetMinutes ?? durationMinutes,
        actualMinutes = actualMinutes ?? durationMinutes,
        startAt = startAt ?? DateTime.now().toIso8601String(),
        endAt = endAt ?? DateTime.now().toIso8601String(),
        dateKey = dateKey ?? DateFormat('yyyy-MM-dd').format(DateTime.now()),
        weekKey = weekKey ?? HistoryStorage.getWeekKey(DateTime.now()),
        monthKey = monthKey ?? DateFormat('yyyy-MM').format(DateTime.now());

  bool get isCompleted => status == 'Completed';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'taskTitle': taskTitle,
      'durationMinutes': durationMinutes,
      'dateStr': dateStr,
      'timeStr': timeStr,
      'userEmail': userEmail,
      'status': status,
      'taskId': taskId,
      'targetMinutes': targetMinutes,
      'actualMinutes': actualMinutes,
      'startAt': startAt,
      'endAt': endAt,
      'dateKey': dateKey,
      'weekKey': weekKey,
      'monthKey': monthKey,
      'pauseCount': pauseCount,
      'focusScore': focusScore,
      'rating': rating,
      'note': note,
      'visualMode': visualMode,
    };
  }

  factory FocusHistoryModel.fromMap(Map<String, dynamic> map) {
    final String oldDateStr = map['dateStr'] ?? '';
    final DateTime fallbackDate = HistoryStorage.parseOldDateStr(oldDateStr);

    return FocusHistoryModel(
      id: map['id'] ?? '',
      taskTitle: map['taskTitle'] ?? '',
      durationMinutes: map['durationMinutes'] ?? 0,
      dateStr: oldDateStr.isNotEmpty
          ? oldDateStr
          : DateFormat('E, MMM dd').format(fallbackDate),
      timeStr: map['timeStr'] ?? '',
      userEmail: map['userEmail'] ?? '',
      status: map['status'] ?? 'Completed',
      taskId: map['taskId'] ?? '',
      targetMinutes: map['targetMinutes'] ?? map['durationMinutes'] ?? 0,
      actualMinutes: map['actualMinutes'] ?? map['durationMinutes'] ?? 0,
      startAt: map['startAt'] ?? fallbackDate.toIso8601String(),
      endAt: map['endAt'] ?? fallbackDate.toIso8601String(),
      dateKey: map['dateKey'] ?? DateFormat('yyyy-MM-dd').format(fallbackDate),
      weekKey: map['weekKey'] ?? HistoryStorage.getWeekKey(fallbackDate),
      monthKey: map['monthKey'] ?? DateFormat('yyyy-MM').format(fallbackDate),
      pauseCount: map['pauseCount'] ?? 0,
      focusScore: map['focusScore'] ?? 0,
      rating: map['rating'] ?? 'Normal',
      note: map['note'] ?? '',
      visualMode: map['visualMode'] ?? 'ring',
    );
  }
}

class HistoryStorage {
  static List<FocusHistoryModel> historyList = [];
  static String _currentUserEmail = '';

  static Future<void> init(String email) async {
    _currentUserEmail = email;
    await loadHistoryFromDisk();
  }

  static Future<void> saveHistoryToDisk() async {
    final prefs = await SharedPreferences.getInstance();

    final List<String> rawList = historyList
        .map((item) => jsonEncode(item.toMap()))
        .toList();

    await prefs.setStringList(
      'history_$_currentUserEmail',
      rawList,
    );
  }

  static Future<void> loadHistoryFromDisk() async {
    final prefs = await SharedPreferences.getInstance();

    final List<String>? rawList = prefs.getStringList(
      'history_$_currentUserEmail',
    );

    if (rawList != null) {
      historyList = rawList.map((str) {
        return FocusHistoryModel.fromMap(jsonDecode(str));
      }).toList();
    } else {
      historyList = [];
    }

    historyList.sort((a, b) {
      final DateTime aDate = DateTime.tryParse(a.startAt) ?? DateTime(2000);
      final DateTime bDate = DateTime.tryParse(b.startAt) ?? DateTime(2000);
      return bDate.compareTo(aDate);
    });
  }

  static String getWeekKey(DateTime date) {
    final DateTime firstDayOfYear = DateTime(date.year, 1, 1);
    final int dayOfYear = date.difference(firstDayOfYear).inDays + 1;
    final int weekNumber = ((dayOfYear - date.weekday + 10) / 7).floor();

    return '${date.year}-W${weekNumber.toString().padLeft(2, '0')}';
  }

  static DateTime parseOldDateStr(String dateStr) {
    if (dateStr.isEmpty) return DateTime.now();

    try {
      final int year = DateTime.now().year;
      return DateFormat('E, MMM dd yyyy').parse('$dateStr $year');
    } catch (_) {
      return DateTime.now();
    }
  }

  static List<FocusHistoryModel> completedSessions() {
    return historyList.where((item) => item.status == 'Completed').toList();
  }

  static List<FocusHistoryModel> cancelledSessions() {
    return historyList.where((item) => item.status != 'Completed').toList();
  }

  static List<FocusHistoryModel> sessionsByDateKey(String dateKey) {
    return historyList.where((item) => item.dateKey == dateKey).toList();
  }

  static List<FocusHistoryModel> sessionsByWeekKey(String weekKey) {
    return historyList.where((item) => item.weekKey == weekKey).toList();
  }

  static List<FocusHistoryModel> sessionsByMonthKey(String monthKey) {
    return historyList.where((item) => item.monthKey == monthKey).toList();
  }

  static int totalFocusMinutes(List<FocusHistoryModel> sessions) {
    int total = 0;

    for (final item in sessions) {
      total += item.actualMinutes;
    }

    return total;
  }

  static int averageFocusScore(List<FocusHistoryModel> sessions) {
    final scored = sessions.where((item) => item.focusScore > 0).toList();

    if (scored.isEmpty) return 0;

    int total = 0;

    for (final item in scored) {
      total += item.focusScore;
    }

    return (total / scored.length).round();
  }

  static int calculateStreak() {
    final completed = completedSessions();

    if (completed.isEmpty) return 0;

    final Set<String> dateKeys = completed.map((item) => item.dateKey).toSet();

    int streak = 0;
    DateTime cursor = DateTime.now();

    while (true) {
      final String key = DateFormat('yyyy-MM-dd').format(cursor);

      if (dateKeys.contains(key)) {
        streak++;
        cursor = cursor.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    return streak;
  }

  static Map<String, int> minutesForLast7Days() {
    final Map<String, int> result = {};

    for (int i = 6; i >= 0; i--) {
      final DateTime day = DateTime.now().subtract(Duration(days: i));
      final String key = DateFormat('yyyy-MM-dd').format(day);
      result[key] = 0;
    }

    for (final item in historyList) {
      if (item.status == 'Completed' && result.containsKey(item.dateKey)) {
        result[item.dateKey] = (result[item.dateKey] ?? 0) + item.actualMinutes;
      }
    }

    return result;
  }
}