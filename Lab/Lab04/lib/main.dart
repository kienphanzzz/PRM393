import 'package:flutter/material.dart';

void main() {
  runApp(const Lab4App());
}

class Lab4App extends StatefulWidget {
  const Lab4App({super.key});

  @override
  State<Lab4App> createState() => _Lab4AppState();
}

class _Lab4AppState extends State<Lab4App> {
  bool _isDarkMode = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Lab 4 - UI Fundamentals',
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: Lab4MainMenu(
        isDarkMode: _isDarkMode,
        onThemeChanged: (value) => setState(() => _isDarkMode = value),
      ),
    );
  }
}

class Lab4MainMenu extends StatelessWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;

  const Lab4MainMenu({super.key, required this.isDarkMode, required this.onThemeChanged});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> menuItems = [
      {'title': 'Exercise 1 - Core Widgets Demo', 'screen': const CoreWidgetsDemo()},
      {'title': 'Exercise 2 - Input Controls Demo', 'screen': const InputControlsDemo()},
      {'title': 'Exercise 3 - Layout Demo', 'screen': const LayoutDemo()},
      {'title': 'Exercise 4 - App Structure & Theme', 'screen': AppStructureThemeDemo(isDarkMode: isDarkMode, onThemeChanged: onThemeChanged)},
      {'title': 'Exercise 5 - Common UI Fixes', 'screen': const CommonUiFixesDemo()},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Lab 4 – Flutter UI Fundamentals'), centerTitle: true),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: menuItems.length,
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListTile(
              title: Text(menuItems[index]['title']),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => menuItems[index]['screen']),
              ),
            ),
          );
        },
      ),
    );
  }
}

class CoreWidgetsDemo extends StatelessWidget {
  const CoreWidgetsDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Exercise 1 – Core Widgets')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Welcome to Flutter UI', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Center(child: Icon(Icons.movie, size: 80, color: Colors.blue)),
            const SizedBox(height: 16),
            Center(
              child: Image.network(
                'https://images.unsplash.com/photo-1542204172-e7052809a86e?w=500',
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 16),
            const Card(
              child: ListTile(
                leading: Icon(Icons.star, color: Colors.amber),
                title: Text('Movie Item'),
                subtitle: Text('This is a sample ListTile inside a Card.'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class InputControlsDemo extends StatefulWidget {
  const InputControlsDemo({super.key});

  @override
  State<InputControlsDemo> createState() => _InputControlsDemoState();
}

class _InputControlsDemoState extends State<InputControlsDemo> {
  double _sliderValue = 50.0;
  bool _switchValue = false;
  String? _selectedGenre = 'None';
  DateTime? _selectedDate;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Exercise 2 – Input Controls')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Rating (Slider)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Slider(
            value: _sliderValue,
            min: 0,
            max: 100,
            onChanged: (value) => setState(() => _sliderValue = value),
          ),
          Text('Current value: ${_sliderValue.round()}'),
          const SizedBox(height: 20),
          const Text('Active (Switch)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SwitchListTile(
            title: const Text('Is movie active?'),
            value: _switchValue,
            onChanged: (value) => setState(() => _switchValue = value),
          ),
          const SizedBox(height: 20),
          const Text('Genre (RadioListTile)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          RadioListTile<String>(
            title: const Text('Action'),
            value: 'Action',
            groupValue: _selectedGenre,
            onChanged: (value) => setState(() => _selectedGenre = value),
          ),
          RadioListTile<String>(
            title: const Text('Comedy'),
            value: 'Comedy',
            groupValue: _selectedGenre,
            onChanged: (value) => setState(() => _selectedGenre = value),
          ),
          Text('Selected genre: $_selectedGenre'),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) setState(() => _selectedDate = picked);
            },
            child: const Text('Open Date Picker'),
          ),
          if (_selectedDate != null) Text('Date: ${_selectedDate!.toLocal()}'.split(' ')[0]),
        ],
      ),
    );
  }
}

class LayoutDemo extends StatelessWidget {
  const LayoutDemo({super.key});

  @override
  Widget build(BuildContext context) {
    final movies = ['Avatar', 'Inception', 'Interstellar', 'Joker'];

    return Scaffold(
      appBar: AppBar(title: const Text('Exercise 3 – Layout Demo')),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Now Playing', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: movies.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Card(
                    child: ListTile(
                      leading: CircleAvatar(child: Text(movies[index][0])),
                      title: Text(movies[index]),
                      subtitle: const Text('Sample description'),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class AppStructureThemeDemo extends StatelessWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;

  const AppStructureThemeDemo({super.key, required this.isDarkMode, required this.onThemeChanged});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exercise 4 – App Structure'),
        actions: [
          Row(
            children: [
              const Text('Dark'),
              Switch(value: isDarkMode, onChanged: onThemeChanged),
            ],
          )
        ],
      ),
      body: const Center(child: Text('This is a simple screen with theme toggle.', style: TextStyle(fontSize: 16))),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
    );
  }
}

class CommonUiFixesDemo extends StatelessWidget {
  const CommonUiFixesDemo({super.key});

  @override
  Widget build(BuildContext context) {
    final movies = ['Movie A', 'Movie B', 'Movie C', 'Movie D'];

    return Scaffold(
      appBar: AppBar(title: const Text('Exercise 5 – Common UI Fixes')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Correct ListView inside Column using Expanded', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              SizedBox(
                height: 300,
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: movies.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      leading: const Icon(Icons.movie_filter),
                      title: Text(movies[index]),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              Container(height: 200, color: Colors.blueGrey.withValues(alpha: 0.2), child: const Center(child: Text('Safe from screen overflow!'))),
            ],
          ),
        ),
      ),
    );
  }
}