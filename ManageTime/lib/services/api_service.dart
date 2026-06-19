import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiService {

  static const String baseUrl = 'http://10.0.2.2:3000';



  static Future<List<Map<String, dynamic>>> getTasks(String email) async {
    final uri = Uri.parse('$baseUrl/api/tasks?email=$email');

    final response = await http.get(uri);

    final Map<String, dynamic> body = jsonDecode(response.body);

    if (response.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Không lấy được danh sách task');
    }

    final List<dynamic> data = body['data'] ?? [];

    return data.map((item) => Map<String, dynamic>.from(item)).toList();
  }

  static Future<Map<String, dynamic>> createTask({
    required String userEmail,
    required String title,
    String description = '',
    String priority = 'medium',
    String status = 'pending',
    String? dueDate,
  }) async {
    final uri = Uri.parse('$baseUrl/api/tasks');

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'userEmail': userEmail,
        'title': title,
        'description': description,
        'priority': priority,
        'status': status,
        'dueDate': dueDate,
      }),
    );

    final Map<String, dynamic> body = jsonDecode(response.body);

    if (response.statusCode != 201 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Không tạo được task');
    }

    return Map<String, dynamic>.from(body['data']);
  }

  static Future<void> updateTask({
    required int id,
    required String title,
    String description = '',
    String priority = 'medium',
    String status = 'pending',
    String? dueDate,
  }) async {
    final uri = Uri.parse('$baseUrl/api/tasks/$id');

    final response = await http.put(
      uri,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'title': title,
        'description': description,
        'priority': priority,
        'status': status,
        'dueDate': dueDate,
      }),
    );

    final Map<String, dynamic> body = jsonDecode(response.body);

    if (response.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Không cập nhật được task');
    }
  }

  static Future<void> deleteTask(int id) async {
    final uri = Uri.parse('$baseUrl/api/tasks/$id');

    final response = await http.delete(uri);

    final Map<String, dynamic> body = jsonDecode(response.body);

    if (response.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Không xóa được task');
    }
  }
}