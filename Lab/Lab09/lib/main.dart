import 'package:flutter/material.dart';
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDarkMode = true;

  @override
  void initState() {
    super.initState();
    _loadThemeSettings();
  }

  void _loadThemeSettings() {
    setState(() {
      _isDarkMode = FakePrefs.getBool('isDarkMode', defaultValue: true);
    });
  }

  void _toggleTheme(bool value) {
    setState(() {
      _isDarkMode = value;
      FakePrefs.setBool('isDarkMode', value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mini Storage Mock Demo',
      theme: _isDarkMode ? ThemeData.dark() : ThemeData.light(),
      home: Lab9HomeScreen(
        isDarkMode: _isDarkMode,
        onThemeChanged: _toggleTheme,
      ),
    );
  }
}

class FakePrefs {
  static final Map<String, dynamic> _storage = {};

  static bool getBool(String key, {required bool defaultValue}) {
    return _storage.containsKey(key) ? _storage[key] as bool : defaultValue;
  }

  static void setBool(String key, bool value) {
    _storage[key] = value;
  }
}

class NoteModel {
  final String id;
  final String content;

  NoteModel({required this.id, required this.content});

  Map<String, dynamic> toMap() => {'id': id, 'content': content};
  factory NoteModel.fromMap(Map<String, dynamic> map) => NoteModel(id: map['id'], content: map['content']);
}

class FakeJsonFileStorage {
  static String _fakeFileContent = "[]";

  static Future<void> writeNotes(List<NoteModel> notes) async {
    List<Map<String, dynamic>> mapList = notes.map((n) => n.toMap()).toList();
    _fakeFileContent = jsonEncode(mapList);
  }

  static Future<List<NoteModel>> readNotes() async {
    List<dynamic> decodedList = jsonDecode(_fakeFileContent);
    return decodedList.map((item) => NoteModel.fromMap(item)).toList();
  }
}

class TodoTask {
  final int id;
  final String title;
  int isCompleted;

  TodoTask({required this.id, required this.title, required this.isCompleted});

  Map<String, dynamic> toMap() => {'id': id, 'title': title, 'isCompleted': isCompleted};
}

class FakeSQLiteDatabase {
  static final List<Map<String, dynamic>> _taskTable = [];
  static int _idCounter = 1;

  static Future<void> insertTask(String title) async {
    _taskTable.add({'id': _idCounter++, 'title': title, 'isCompleted': 0});
  }

  static Future<List<TodoTask>> queryAllTasks() async {
    return _taskTable.map((row) => TodoTask(
      id: row['id'],
      title: row['title'],
      isCompleted: row['isCompleted'],
    )).toList();
  }

  static Future<void> updateTaskStatus(int id, int isCompleted) async {
    int index = _taskTable.indexWhere((row) => row['id'] == id);
    if (index != -1) {
      _taskTable[index]['isCompleted'] = isCompleted;
    }
  }

  static Future<void> deleteTask(int id) async {
    _taskTable.removeWhere((row) => row['id'] == id);
  }
}

class Lab9HomeScreen extends StatefulWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;

  const Lab9HomeScreen({super.key, required this.isDarkMode, required this.onThemeChanged});

  @override
  State<Lab9HomeScreen> createState() => _Lab9HomeScreenState();
}

class _Lab9HomeScreenState extends State<Lab9HomeScreen> {
  int _selectedTabIndex = 0;
  List<NoteModel> _notesList = [];
  List<TodoTask> _tasksList = [];
  final _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAllOfflineData();
  }

  Future<void> _loadAllOfflineData() async {
    List<NoteModel> notes = await FakeJsonFileStorage.readNotes();
    List<TodoTask> tasks = await FakeSQLiteDatabase.queryAllTasks();
    setState(() {
      _notesList = notes;
      _tasksList = tasks;
    });
  }

  Future<void> _addNewNote() async {
    if (_textController.text.isNotEmpty) {
      final newNote = NoteModel(id: DateTime.now().toString(), content: _textController.text);
      _notesList.add(newNote);
      await FakeJsonFileStorage.writeNotes(_notesList);
      _textController.clear();
      _loadAllOfflineData();
    }
  }

  Future<void> _addNewTask() async {
    if (_textController.text.isNotEmpty) {
      await FakeSQLiteDatabase.insertTask(_textController.text);
      _textController.clear();
      _loadAllOfflineData();
    }
  }

  Future<void> _toggleTaskCheck(TodoTask task) async {
    int newStatus = task.isCompleted == 0 ? 1 : 0;
    await FakeSQLiteDatabase.updateTaskStatus(task.id, newStatus);
    _loadAllOfflineData();
  }

  Future<void> _deleteTaskItem(int id) async {
    await FakeSQLiteDatabase.deleteTask(id);
    _loadAllOfflineData();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> tabScreens = [
      Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Theme Settings (FakePrefs)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('In a real app, this would use SharedPreferences.\nHere we simulate it with FakePrefs (in-memory only).', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 32),
            Card(
              elevation: 2,
              child: SwitchListTile(
                title: const Text('Enable Dark Mode'),
                value: widget.isDarkMode,
                activeColor: const Color(0xFF6366F1),
                onChanged: widget.onThemeChanged,
              ),
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(labelText: 'Write a quick note...', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), padding: const EdgeInsets.symmetric(vertical: 16)),
                  onPressed: _addNewNote,
                  child: const Text('Save Note'),
                )
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _notesList.isEmpty
                  ? const Center(child: Text('No notes found in local JSON file.', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                itemCount: _notesList.length,
                itemBuilder: (context, index) {
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      leading: const Icon(Icons.description_outlined, color: Color(0xFF6366F1)),
                      title: Text(_notesList[index].content),
                    ),
                  );
                },
              ),
            )
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(labelText: 'Enter new task...', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
                  icon: const Icon(Icons.add, color: Colors.white),
                  onPressed: _addNewTask,
                )
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _tasksList.isEmpty
                  ? const Center(child: Text('No tasks inside local SQLite table.', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                itemCount: _tasksList.length,
                itemBuilder: (context, index) {
                  final task = _tasksList[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      leading: Checkbox(
                        activeColor: const Color(0xFF6366F1),
                        value: task.isCompleted == 1,
                        onChanged: (_) => _toggleTaskCheck(task),
                      ),
                      title: Text(
                        task.title,
                        style: TextStyle(
                          decoration: task.isCompleted == 1 ? TextDecoration.lineThrough : null,
                          color: task.isCompleted == 1 ? Colors.grey : null,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        onPressed: () => _deleteTaskItem(task.id),
                      ),
                    ),
                  );
                },
              ),
            )
          ],
        ),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mini Storage Mock Demo', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 1,
      ),
      body: tabScreens[_selectedTabIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTabIndex,
        selectedItemColor: const Color(0xFF6366F1),
        onTap: (index) {
          setState(() {
            _selectedTabIndex = index;
            _textController.clear();
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
          BottomNavigationBarItem(icon: Icon(Icons.note_alt), label: 'Notes'),
          BottomNavigationBarItem(icon: Icon(Icons.task_alt), label: 'Tasks'),
        ],
      ),
    );
  }
}