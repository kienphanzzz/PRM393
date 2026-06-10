import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class EventModel {
  String id;
  String title;
  String description;
  String startTime;
  String endTime;
  String location;
  String type; // 'Meeting', 'Fitness', 'Deadline', 'Other'
  String sticker; // Sticker icon name or emoji
  bool isAllDay;
  int reminderMinutes; // Báo trước bao nhiêu phút
  String repeatInterval; // 'None', 'Daily', 'Weekly', 'Monthly'
  String userEmail;

  EventModel({
    required this.id,
    required this.title,
    this.description = '',
    required this.startTime,
    required this.endTime,
    this.location = '',
    required this.type,
    this.sticker = '📅',
    this.isAllDay = false,
    this.reminderMinutes = 10,
    this.repeatInterval = 'None',
    this.userEmail = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'startTime': startTime,
      'endTime': endTime,
      'location': location,
      'type': type,
      'sticker': sticker,
      'isAllDay': isAllDay,
      'reminderMinutes': reminderMinutes,
      'repeatInterval': repeatInterval,
      'userEmail': userEmail,
    };
  }

  factory EventModel.fromMap(Map<String, dynamic> map) {
    return EventModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      startTime: map['startTime'] ?? '',
      endTime: map['endTime'] ?? '',
      location: map['location'] ?? '',
      type: map['type'] ?? 'Other',
      sticker: map['sticker'] ?? '📅',
      isAllDay: map['isAllDay'] ?? false,
      reminderMinutes: map['reminderMinutes'] ?? 10,
      repeatInterval: map['repeatInterval'] ?? 'None',
      userEmail: map['userEmail'] ?? '',
    );
  }
}

class EventStorage {
  static List<EventModel> userEvents = [];
  static String _currentUserEmail = '';

  static Future<void> init(String email) async {
    _currentUserEmail = email;
    await loadEvents();
  }

  static Future<void> saveEvents() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> rawList = userEvents.map((e) => jsonEncode(e.toMap())).toList();
    await prefs.setStringList('events_$_currentUserEmail', rawList);
  }

  static Future<void> loadEvents() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? rawList = prefs.getStringList('events_$_currentUserEmail');
    if (rawList != null) {
      userEvents = rawList.map((str) => EventModel.fromMap(jsonDecode(str))).toList();
    } else {
      userEvents = [
        EventModel(
          id: 'e1', 
          title: 'Họp Hội đồng Đường lối dự án', 
          startTime: '2025-01-20 09:30', 
          endTime: '2025-01-20 11:00',
          location: 'Room 402', 
          type: 'Meeting',
          sticker: '🤝',
          userEmail: _currentUserEmail
        ),
      ];
    }
  }
}