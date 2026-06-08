import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class FocusHistoryModel {
  final String id;
  final String taskTitle;
  final int durationMinutes;
  final String dateStr;
  final String timeStr;

  FocusHistoryModel({
    required this.id,
    required this.taskTitle,
    required this.durationMinutes,
    required this.dateStr,
    required this.timeStr,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'taskTitle': taskTitle,
      'durationMinutes': durationMinutes,
      'dateStr': dateStr,
      'timeStr': timeStr,
    };
  }

  factory FocusHistoryModel.fromMap(Map<String, dynamic> map) {
    return FocusHistoryModel(
      id: map['id'] ?? '',
      taskTitle: map['taskTitle'] ?? '',
      durationMinutes: map['durationMinutes'] ?? 0,
      dateStr: map['dateStr'] ?? '',
      timeStr: map['timeStr'] ?? '',
    );
  }
}

class HistoryStorage {
  static List<FocusHistoryModel> historyList = [];

  static Future<void> saveHistoryToDisk() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> rawList = historyList.map((item) => jsonEncode(item.toMap())).toList();
    await prefs.setStringList('focus_history_disk', rawList);
  }

  static Future<void> loadHistoryFromDisk() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? rawList = prefs.getStringList('focus_history_disk');
    if (rawList != null) {
      historyList = rawList.map((str) => FocusHistoryModel.fromMap(jsonDecode(str))).toList();
    } else {
      historyList = [
        FocusHistoryModel(id: 'h1', taskTitle: 'Finish project report', durationMinutes: 25, dateStr: 'Mon, Jun 08', timeStr: '08:15 AM'),
        FocusHistoryModel(id: 'h2', taskTitle: 'Team standup meeting', durationMinutes: 25, dateStr: 'Mon, Jun 08', timeStr: '09:00 AM'),
      ];
    }
  }
}