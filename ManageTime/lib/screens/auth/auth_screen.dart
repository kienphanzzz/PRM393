import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:manage_time/core/constants.dart';
import 'package:manage_time/main.dart';
import 'package:manage_time/screens/dashboard/dashboard_screen.dart';
import 'package:manage_time/screens/auth/register_screen.dart';
import 'package:manage_time/data/models/task_model.dart';
import 'package:manage_time/data/models/session_model.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _rememberMe = false;
  bool _obscurePassword = true;
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _forgotEmailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _isDark = ThemeController.isDark;
  List<Map<String, String>> _savedAccounts = [];
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _loadSavedAccounts();
    ThemeController.themeNotifier.addListener(_updateTheme);
  }

  void _updateTheme() {
    if (mounted) setState(() => _isDark = ThemeController.isDark);
  }

  Future<void> _loadSavedAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    String? rawData = prefs.getString('saved_accounts_list');
    if (rawData != null) {
      setState(() {
        _savedAccounts = List<Map<String, String>>.from(
            jsonDecode(rawData).map((item) => Map<String, String>.from(item)));
      });
    }
  }

  Future<void> _saveAccount(String email, String password, String name) async {
    final prefs = await SharedPreferences.getInstance();
    // Xóa account cũ nếu trùng email để cập nhật pass mới
    _savedAccounts.removeWhere((item) => item['email'] == email);
    _savedAccounts.insert(0, {'email': email, 'password': password, 'name': name});
    
    // Chỉ lưu tối đa 5 account
    if (_savedAccounts.length > 5) _savedAccounts = _savedAccounts.sublist(0, 5);
    
    await prefs.setString('saved_accounts_list', jsonEncode(_savedAccounts));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _forgotEmailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    ThemeController.themeNotifier.removeListener(_updateTheme);
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('http://10.0.2.2:3000/api/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _emailController.text.trim(),
          'password': _passwordController.text.trim(),
        }),
      );

      final data = jsonDecode(response.body);

      if (!mounted) return;

      if (response.statusCode == 200 && data['success'] == true) {
        String email = _emailController.text.trim();
        String name = data['user']?['fullName'] ?? email.split('@')[0];
        
        // KHỞI TẠO DỮ LIỆU RIÊNG CHO USER NÀY
        await TaskStorage.init(email);
        await HistoryStorage.init(email);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_name', name);
        await prefs.setString('user_email', email);

        if (_rememberMe) {
          await prefs.setBool('is_logged_in', true);
          await _saveAccount(email, _passwordController.text, name);
        } else {
          await prefs.setBool('is_logged_in', false);
        }
        
        _showSuccessDialog('Đăng nhập thành công!', 'Chào mừng $name quay trở lại.');
      } else {
        _showErrorSnackBar(data['message']?.toString() ?? 'Sai tài khoản hoặc mật khẩu!');
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Lỗi kết nối đến máy chủ!');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: _isDark ? AppColors.cardBg : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Chọn tài khoản để tiếp tục', style: TextStyle(color: _isDark ? Colors.white : Colors.black87, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _buildGoogleAccountItem('Phan Hữu Kiên', 'kien.phan.fpt@gmail.com', 'https://i.pravatar.cc/150?u=kien'),
            _buildGoogleAccountItem('Kien Phan (Student)', 'kienpzz@gmail.com', 'https://i.pravatar.cc/150?u=student'),
            ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: const Text('Sử dụng một tài khoản khác'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    ).then((_) {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  Widget _buildGoogleAccountItem(String name, String email, String avatar) {
    return ListTile(
      leading: CircleAvatar(backgroundImage: NetworkImage(avatar)),
      title: Text(name, style: TextStyle(color: _isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w500)),
      subtitle: Text(email, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
      onTap: () async {
        Navigator.pop(context);
        setState(() => _isLoading = true);
        
        // PHÂN TÁCH DỮ LIỆU RIÊNG CHO GOOGLE ACCOUNT
        await TaskStorage.init(email);
        await HistoryStorage.init(email);
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_logged_in', true);
        await prefs.setString('user_name', name);
        await prefs.setString('user_email', email);
        
        if (mounted) {
          _showSuccessDialog('Google Login thành công!', 'Chào mừng $name đến với ManageTime.');
        }
      },
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: Colors.redAccent, content: Text(message)),
    );
  }

  void _showSuccessDialog(String title, String content) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _isDark ? AppColors.cardBg : Colors.white,
        title: Text(title, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
        content: Text(content, style: TextStyle(color: _isDark ? Colors.white70 : Colors.black54)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.pushReplacement(
                context, 
                MaterialPageRoute(builder: (context) => const DashboardScreen()),
              );
            },
            child: const Text('Tiếp tục', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Color textColor = _isDark ? Colors.white : Colors.black87;
    Color cardBg = _isDark ? AppColors.cardBg : Colors.white;

    return Scaffold(
      backgroundColor: _isDark ? AppColors.background : const Color(0xFFF8F9FA),
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.bolt, color: AppColors.primary, size: 48),
                  const SizedBox(height: 16),
                  Text('ManageTime Flow', style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.bold)),
                  const Text('Làm chủ thời gian, tối ưu hiệu suất', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(_isDark ? 0.3 : 0.05), blurRadius: 20, offset: const Offset(0, 10))],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Đăng nhập tài khoản', style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 20),
                          
                          // FIELD EMAIL VỚI GỢI Ý TÀI KHOẢN ĐÃ LƯU
                          TextFormField(
                            controller: _emailController,
                            style: TextStyle(color: textColor),
                            onTap: () => setState(() => _showSuggestions = _savedAccounts.isNotEmpty),
                            decoration: const InputDecoration(labelText: 'Email Address', prefixIcon: Icon(Icons.email_outlined)),
                            validator: (value) => (value == null || !value.contains('@')) ? 'Vui lòng nhập Email hợp lệ' : null,
                          ),
                          const SizedBox(height: 16),
                          
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: TextStyle(color: textColor),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: AppColors.textMuted),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            validator: (value) => (value == null || value.length < 6) ? 'Mật khẩu phải từ 6 ký tự' : null,
                          ),
                          const SizedBox(height: 12),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Checkbox(
                                    value: _rememberMe,
                                    activeColor: AppColors.primary,
                                    onChanged: (value) => setState(() => _rememberMe = value ?? false),
                                  ),
                                  Text('Ghi nhớ tôi', style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 13)),
                                ],
                              ),
                              TextButton(onPressed: () {}, child: const Text('Quên mật khẩu?', style: TextStyle(color: AppColors.primary, fontSize: 13))),
                            ],
                          ),
                          const SizedBox(height: 24),
                          
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                              onPressed: _isLoading ? null : _handleSignIn,
                              child: _isLoading 
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Text('Sign In Now', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: OutlinedButton.icon(
                              onPressed: _isLoading ? null : _handleGoogleSignIn,
                              icon: const Icon(Icons.g_mobiledata, color: Colors.blue, size: 30),
                              label: Text('Continue with Google Account', style: TextStyle(color: textColor, fontSize: 14)),
                              style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Bạn chưa có tài khoản? ', style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 14)),
                      GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterScreen())),
                        child: const Text('Đăng ký ngay', style: TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // OVERLAY GỢI Ý TÀI KHOẢN (Garena Style)
          if (_showSuggestions)
            Positioned(
              left: 30,
              right: 30,
              top: 350, // Điều chỉnh vị trí phù hợp với ô email
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                color: _isDark ? AppColors.cardBg : Colors.white,
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _savedAccounts.length,
                    itemBuilder: (context, index) {
                      final acc = _savedAccounts[index];
                      return ListTile(
                        leading: const Icon(Icons.history, size: 20),
                        title: Text(acc['email']!, style: TextStyle(color: textColor, fontSize: 14)),
                        subtitle: Text(acc['name']!, style: const TextStyle(fontSize: 12)),
                        onTap: () {
                          setState(() {
                            _emailController.text = acc['email']!;
                            _passwordController.text = acc['password']!;
                            _showSuggestions = false;
                            _rememberMe = true;
                          });
                        },
                        trailing: IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () async {
                            setState(() => _savedAccounts.removeAt(index));
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setString('saved_accounts_list', jsonEncode(_savedAccounts));
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}