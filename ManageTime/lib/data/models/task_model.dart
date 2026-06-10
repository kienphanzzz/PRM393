import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class TaskModel {
  String id;
  String title;
  String deadline;
  String priority;
  bool isCompleted;
  String description;
  String userEmail; // Để phân tách dữ liệu người dùng

  TaskModel({
    required this.id,
    required this.title,
    required this.deadline,
    required this.priority,
    this.isCompleted = false,
    this.description = '',
    this.userEmail = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'deadline': deadline,
      'priority': priority,
      'isCompleted': isCompleted,
      'description': description,
      'userEmail': userEmail,
    };
  }

  factory TaskModel.fromMap(Map<String, dynamic> map) {
    return TaskModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      deadline: map['deadline'] ?? '',
      priority: map['priority'] ?? 'Medium',
      isCompleted: map['isCompleted'] ?? false,
      description: map['description'] ?? '',
      userEmail: map['userEmail'] ?? '',
    );
  }
}

class TaskStorage {
  static List<TaskModel> todoTasks = [];
  static String _currentUserEmail = '';

  static Future<void> init(String email) async {
    _currentUserEmail = email;
    await loadTasks();
  }

  static Future<void> saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> rawList = todoTasks.map((t) => jsonEncode(t.toMap())).toList();
    await prefs.setStringList('tasks_$_currentUserEmail', rawList);
  }

  static Future<void> loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? rawList = prefs.getStringList('tasks_$_currentUserEmail');
    if (rawList != null) {
      todoTasks = rawList.map((str) => TaskModel.fromMap(jsonDecode(str))).toList();
    } else {
      todoTasks = []; // Tài khoản mới thì danh sách trống
    }
  }
}