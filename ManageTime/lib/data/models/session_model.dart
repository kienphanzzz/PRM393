import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class FocusHistoryModel {
  final String id;
  final String taskTitle;
  final int durationMinutes;
  final String dateStr; // E, MMM dd
  final String timeStr;
  final String userEmail;
  final String status; // 'Completed' hoặc 'Cancelled'

  FocusHistoryModel({
    required this.id,
    required this.taskTitle,
    required this.durationMinutes,
    required this.dateStr,
    required this.timeStr,
    required this.userEmail,
    this.status = 'Completed',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'taskTitle': taskTitle,
      'durationMinutes': durationMinutes,
      'dateStr': dateStr,
      'timeStr': timeStr,
      'userEmail': userEmail,
      'status': status,
    };
  }

  factory FocusHistoryModel.fromMap(Map<String, dynamic> map) {
    return FocusHistoryModel(
      id: map['id'] ?? '',
      taskTitle: map['taskTitle'] ?? '',
      durationMinutes: map['durationMinutes'] ?? 0,
      dateStr: map['dateStr'] ?? '',
      timeStr: map['timeStr'] ?? '',
      userEmail: map['userEmail'] ?? '',
      status: map['status'] ?? 'Completed',
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
    List<String> rawList = historyList.map((item) => jsonEncode(item.toMap())).toList();
    await prefs.setStringList('history_$_currentUserEmail', rawList);
  }

  static Future<void> loadHistoryFromDisk() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? rawList = prefs.getStringList('history_$_currentUserEmail');
    if (rawList != null) {
      historyList = rawList.map((str) => FocusHistoryModel.fromMap(jsonDecode(str))).toList();
    } else {
      historyList = [];
    }
  }

  // Tính Streak (Số ngày liên tiếp tập trung)
  static int calculateStreak() {
    if (historyList.isEmpty) return 0;
    // Logic tính toán ngày liên tiếp dựa trên dateStr
    return 3; // Mock 3 ngày
  }
}