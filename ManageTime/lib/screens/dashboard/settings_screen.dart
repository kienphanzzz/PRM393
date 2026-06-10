import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:manage_time/core/constants.dart';
import 'package:manage_time/main.dart';
import 'package:manage_time/screens/auth/auth_screen.dart';

class SettingsScreen extends StatefulWidget {
  final String userName;
  const SettingsScreen({super.key, this.userName = 'User'});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDarkTheme = ThemeController.isDark;
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  String _profileImagePath = ''; // Mock path for avatar index or asset

  // Pomodoro Settings
  int _focusTime = 25;
  int _shortBreak = 5;
  int _longBreak = 15;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.userName);
    _emailController = TextEditingController();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nameController.text = prefs.getString('user_name') ?? widget.userName;
      _emailController.text = prefs.getString('user_email') ?? 'kienphanzzz@gmail.com';
      _profileImagePath = prefs.getString('profile_image') ?? '0'; // index of mock avatar
      _focusTime = prefs.getInt('pomo_focus') ?? 25;
      _shortBreak = prefs.getInt('pomo_short') ?? 5;
      _longBreak = prefs.getInt('pomo_long') ?? 15;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _showEditProfileDialog() {
    final tempNameController = TextEditingController(text: _nameController.text);
    final tempEmailController = TextEditingController(text: _emailController.text);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Cập nhật thông tin', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: tempNameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Họ và tên',
                  labelStyle: TextStyle(color: AppColors.textMuted),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: tempEmailController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Email',
                  labelStyle: TextStyle(color: AppColors.textMuted),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy', style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('user_name', tempNameController.text.trim());
                await prefs.setString('user_email', tempEmailController.text.trim());
                setState(() {
                  _nameController.text = tempNameController.text.trim();
                  _emailController.text = tempEmailController.text.trim();
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã cập nhật thông tin thành công!')));
              },
              child: const Text('Lưu', style: TextStyle(color: AppColors.background, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showAvatarPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
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
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setString('profile_image', index.toString());
                        setState(() {
                          _profileImagePath = index.toString();
                        });
                        Navigator.pop(context);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 15),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _profileImagePath == index.toString() ? AppColors.primary : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.grey.withValues(alpha: 0.2),
                          child: Icon(_getIconForIndex(index), size: 40, color: Colors.white),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              const Text('(Cần cài thêm image_picker để tải ảnh từ máy)', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
        );
      },
    );
  }

  IconData _getIconForIndex(int index) {
    switch (index) {
      case 1: return Icons.face_retouching_natural;
      case 2: return Icons.face_unlock_rounded;
      case 3: return Icons.face_6_rounded;
      case 4: return Icons.face_3_rounded;
      default: return Icons.person;
    }
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
              _buildPomoSlider('Tập trung', tempFocus, 10, 60, (val) => setDialogState(() => tempFocus = val.toInt())),
              _buildPomoSlider('Nghỉ ngắn', tempShort, 1, 15, (val) => setDialogState(() => tempShort = val.toInt())),
              _buildPomoSlider('Nghỉ dài', tempLong, 5, 30, (val) => setDialogState(() => tempLong = val.toInt())),
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
        Slider(
          value: value.toDouble(),
          min: min,
          max: max,
          activeColor: AppColors.primary,
          onChanged: onChanged,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    Color currentTextColor = Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87;
    Color cardBg = Theme.of(context).brightness == Brightness.dark ? AppColors.cardBg : Colors.white;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Settings & Profile', style: TextStyle(color: currentTextColor, fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 30),
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _showAvatarPicker,
                    child: Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.primary, width: 2)),
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor: cardBg,
                            child: Icon(_getIconForIndex(int.tryParse(_profileImagePath) ?? 0), size: 50, color: currentTextColor),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                            child: const Icon(Icons.camera_alt, size: 18, color: AppColors.background),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(_nameController.text, style: TextStyle(color: currentTextColor, fontSize: 22, fontWeight: FontWeight.bold)),
                  Text(_emailController.text, style: const TextStyle(color: AppColors.textMuted, fontSize: 14)),
                ],
              ),
            ),
            const SizedBox(height: 40),
            _buildSectionHeader('GIAO DIỆN'),
            Container(
              margin: const EdgeInsets.only(bottom: 16, top: 8),
              decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(20), boxShadow: [if(Theme.of(context).brightness == Brightness.light) BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]),
              child: ListTile(
                leading: const Icon(Icons.color_lens_outlined, color: AppColors.primary),
                title: Text('Chế độ tối (Dark Mode)', style: TextStyle(color: currentTextColor, fontWeight: FontWeight.bold)),
                trailing: Switch(
                  activeThumbColor: AppColors.primary,
                  value: _isDarkTheme,
                  onChanged: (value) async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('is_dark_theme', value);
                    setState(() => _isDarkTheme = value);
                    ThemeController.toggleTheme(value);
                  },
                ),
              ),
            ),
            _buildSectionHeader('CÁ NHÂN HÓA'),
            _buildSettingItem(Icons.edit_outlined, 'Cập nhật thông tin', 'Đổi tên và email hiển thị', cardBg, currentTextColor, _showEditProfileDialog),
            _buildSettingItem(Icons.lock_clock_outlined, 'Cài đặt Pomodoro', 'Tùy chỉnh thời gian tập trung: $_focusTime phút', cardBg, currentTextColor, _showPomoSettings),
            
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.redAccent, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.clear();
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const AuthScreen()), (route) => false);
                  }
                },
                icon: const Icon(Icons.logout, color: Colors.redAccent),
                label: const Text('Đăng xuất tài khoản', style: TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(title, style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
    );
  }

  Widget _buildSettingItem(IconData icon, String title, String subtitle, Color cardBg, Color textColor, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(20), boxShadow: [if(Theme.of(context).brightness == Brightness.light) BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        leading: Icon(icon, color: AppColors.primary),
        title: Text(title, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
      ),
    );
  }
}