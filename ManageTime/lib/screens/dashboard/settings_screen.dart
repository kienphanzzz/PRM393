import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../../main.dart';
import '../auth/auth_screen.dart';

class SettingsScreen extends StatefulWidget {
  final String userName;
  const SettingsScreen({super.key, this.userName = 'User'});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDarkTheme = ThemeController.isDark;
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.userName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _showEditProfileDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _isDarkTheme ? AppColors.cardBg : Colors.white,
          title: Text('Edit Profile Name', style: TextStyle(color: _isDarkTheme ? Colors.white : Colors.black87)),
          content: TextField(
            controller: _nameController,
            style: TextStyle(color: _isDarkTheme ? Colors.white : Colors.black87),
            decoration: const InputDecoration(
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () {
                setState(() {});
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profile updated successfully!')),
                );
              },
              child: const Text('Save', style: TextStyle(color: AppColors.background)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Color currentBg = _isDarkTheme ? AppColors.background : Colors.grey.shade100;
    Color currentCardBg = _isDarkTheme ? AppColors.cardBg : Colors.white;
    Color currentTextColor = _isDarkTheme ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: currentBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back, color: currentTextColor),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(height: 10),
              Text('Settings & Profile', style: TextStyle(color: currentTextColor, fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 30),
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 45,
                      backgroundColor: currentCardBg,
                      child: Icon(Icons.person, size: 45, color: currentTextColor),
                    ),
                    const SizedBox(height: 16),
                    Text(_nameController.text, style: TextStyle(color: currentTextColor, fontSize: 22, fontWeight: FontWeight.bold)),
                    const Text('kienphanzzz@gmail.com', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: currentCardBg, borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  leading: Icon(Icons.color_lens_outlined, color: currentTextColor),
                  title: Text('Dark Theme Mode', style: TextStyle(color: currentTextColor, fontWeight: FontWeight.bold)),
                  trailing: Switch(
                    activeThumbColor: AppColors.primary,
                    value: _isDarkTheme,
                    onChanged: (value) async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('is_dark_theme', value);
                      setState(() {
                        _isDarkTheme = value;
                        ThemeController.isDark = value;
                      });
                      if (ThemeController.onThemeChanged != null) {
                        ThemeController.onThemeChanged!(value);
                      }
                    },
                  ),
                ),
              ),
              _buildSettingItem(Icons.edit_outlined, 'Edit Profile Name', 'Update your application screen nickname', currentCardBg, currentTextColor, _showEditProfileDialog),
              _buildSettingItem(Icons.lock_clock_outlined, 'Pomodoro Timer Setting', 'Change focus and rest break intervals', currentCardBg, currentTextColor, () {}),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.redAccent, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.remove('user_name');
                    if (context.mounted) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => const AuthScreen()),
                            (route) => false,
                      );
                    }
                  },
                  icon: const Icon(Icons.logout, color: Colors.redAccent),
                  label: const Text('Log Out Account', style: TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingItem(IconData icon, String title, String subtitle, Color cardBg, Color textColor, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: textColor),
        title: Text(title, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
      ),
    );
  }
}