import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../../main.dart';
import '../auth/auth_screen.dart';
import '../../data/models/session_model.dart';
import '../../data/models/achievement_model.dart';
import 'achievements_screen.dart';

class SettingsScreen extends StatefulWidget {
  final String userName;
  const SettingsScreen({super.key, this.userName = 'User'});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDarkTheme = ThemeController.isDark;
  String _displayName = 'User';
  String _userEmail = 'user@gmail.com';
  String _profileImageIdx = '0';

  int _focusTime = 25;
  int _shortBreak = 5;
  int _longBreak = 15;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    ThemeController.themeNotifier.addListener(_updateTheme);
  }

  void _updateTheme() {
    if (mounted) setState(() => _isDarkTheme = ThemeController.isDark);
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    String email = prefs.getString('user_email') ?? 'user@gmail.com';
    setState(() {
      _userEmail = email;
      _displayName = prefs.getString('user_name') ?? widget.userName;
      _profileImageIdx = prefs.getString('profile_image_$email') ?? '0';
      _focusTime = prefs.getInt('pomo_focus') ?? 25;
      _shortBreak = prefs.getInt('pomo_short') ?? 5;
      _longBreak = prefs.getInt('pomo_long') ?? 15;
    });
  }

  @override
  void dispose() {
    ThemeController.themeNotifier.removeListener(_updateTheme);
    super.dispose();
  }

  void _showEditProfileDialog() {
    final nameCtrl = TextEditingController(text: _displayName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: const Text('Đổi tên hiển thị', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: nameCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(labelText: 'Tên mới'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('user_name', nameCtrl.text.trim());
              setState(() => _displayName = nameCtrl.text.trim());
              Navigator.pop(context);
            },
            child: const Text('Lưu'),
          )
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    final oldPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: const Text('Đổi mật khẩu', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: oldPassCtrl, obscureText: true, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Mật khẩu cũ')),
            TextField(controller: newPassCtrl, obscureText: true, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Mật khẩu mới')),
            TextField(controller: confirmPassCtrl, obscureText: true, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Xác nhận mật khẩu mới')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              if (newPassCtrl.text != confirmPassCtrl.text) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mật khẩu xác nhận không khớp!')));
                return;
              }
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('saved_password', newPassCtrl.text);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã đổi mật khẩu thành công!')));
            },
            child: const Text('Cập nhật'),
          )
        ],
      ),
    );
  }

  void _showAvatarPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Chọn ảnh đại diện', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 5,
                itemBuilder: (context, index) => GestureDetector(
                  onTap: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('profile_image_$_userEmail', index.toString());
                    setState(() => _profileImageIdx = index.toString());
                    Navigator.pop(context);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 15),
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _profileImageIdx == index.toString() ? AppColors.primary : Colors.transparent, width: 3)),
                    child: CircleAvatar(radius: 40, child: Icon(_getIcon(index.toString()), size: 40)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIcon(String idx) {
    if (idx == '1') return Icons.face_retouching_natural;
    if (idx == '2') return Icons.face_6;
    if (idx == '3') return Icons.face_3;
    if (idx == '4') return Icons.face_2;
    return Icons.person;
  }

  void _showPomoSettings() {
    int tempFocus = _focusTime;
    int tempShort = _shortBreak;
    int tempLong = _longBreak;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.cardBg,
          title: const Text('Cài đặt Pomodoro', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPomoSlider('Tập trung', tempFocus, 10, 60, (v) => setDialogState(() => tempFocus = v.toInt())),
              _buildPomoSlider('Nghỉ ngắn', tempShort, 1, 15, (v) => setDialogState(() => tempShort = v.toInt())),
              _buildPomoSlider('Nghỉ dài', tempLong, 5, 30, (v) => setDialogState(() => tempLong = v.toInt())),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
            ElevatedButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setInt('pomo_focus', tempFocus);
                await prefs.setInt('pomo_short', tempShort);
                await prefs.setInt('pomo_long', tempLong);
                setState(() {
                  _focusTime = tempFocus;
                  _shortBreak = tempShort;
                  _longBreak = tempLong;
                });
                Navigator.pop(context);
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPomoSlider(String label, int value, double min, double max, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white)),
            Text('$value phút', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ],
        ),
        Slider(value: value.toDouble(), min: min, max: max, activeColor: AppColors.primary, onChanged: onChanged),
      ],
    );
  }

  void _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', false);
    if (mounted) {
       Navigator.pushAndRemoveUntil(
         context,
         MaterialPageRoute(builder: (context) => const AuthScreen()),
         (route) => false
       );
    }
  }

  @override
  Widget build(BuildContext context) {
    int streak = HistoryStorage.calculateStreak();
    int totalMins = HistoryStorage.historyList.fold(0, (sum, item) => sum + item.durationMinutes);
    AchievementProvider.checkAchievements(totalMins, streak);

    Color textColor = _isDarkTheme ? Colors.white : Colors.black87;
    Color cardBg = _isDarkTheme ? AppColors.cardBg : Colors.white;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Settings & Profile', style: TextStyle(color: textColor, fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 30),
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _showAvatarPicker,
                    child: Stack(
                      children: [
                        CircleAvatar(radius: 50, backgroundColor: cardBg, child: Icon(_getIcon(_profileImageIdx), size: 50, color: textColor)),
                        Positioned(bottom: 0, right: 0, child: Container(padding: const EdgeInsets.all(6), decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle), child: const Icon(Icons.camera_alt, size: 14, color: AppColors.background))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(_displayName, style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.bold)),
                  Text(_userEmail, style: const TextStyle(color: AppColors.textMuted)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(color: Colors.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.local_fire_department, color: Colors.orange, size: 18),
                        const SizedBox(width: 4),
                        Text('$streak Days Streak', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
            _buildSection('HUY HIỆU VINH DANH'),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(20)),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: AchievementProvider.getFeatured().isEmpty
                      ? [const Text('Chưa đạt huy hiệu nào', style: TextStyle(color: AppColors.textMuted, fontSize: 12))]
                      : AchievementProvider.getFeatured().map((a) => Column(
                          children: [
                            Text(a.emoji, style: const TextStyle(fontSize: 40)),
                            const SizedBox(height: 4),
                            Text(a.title, style: TextStyle(color: textColor, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        )).toList(),
                  ),
                  const Divider(height: 30),
                  TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AchievementsScreen())),
                    child: const Text('Xem toàn bộ kho huy hiệu →', style: TextStyle(color: AppColors.primary)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            _buildSection('GIAO DIỆN & CÀI ĐẶT'),
            Container(
              decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.dark_mode, color: AppColors.primary),
                    title: Text('Chế độ tối', style: TextStyle(color: textColor)),
                    trailing: Switch(
                      value: _isDarkTheme,
                      onChanged: (v) async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('is_dark_theme', v);
                        ThemeController.toggleTheme(v);
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.timer, color: AppColors.primary),
                    title: Text('Thời gian Pomodoro', style: TextStyle(color: textColor)),
                    subtitle: Text('$_focusTime - $_shortBreak - $_longBreak', style: const TextStyle(fontSize: 12)),
                    onTap: _showPomoSettings,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.person_outline, color: AppColors.primary),
                    title: Text('Cập nhật thông tin', style: TextStyle(color: textColor)),
                    onTap: _showEditProfileDialog,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.lock_outline, color: AppColors.primary),
                    title: Text('Đổi mật khẩu', style: TextStyle(color: textColor)),
                    onTap: _showChangePasswordDialog,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _handleLogout,
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text('Đăng xuất', style: TextStyle(color: Colors.red)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title) => Padding(padding: const EdgeInsets.only(bottom: 8, left: 4), child: Text(title, style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.bold, letterSpacing: 1)));
}