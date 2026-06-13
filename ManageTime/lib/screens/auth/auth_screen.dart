import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:manage_time/core/constants.dart';
import 'package:manage_time/main.dart';
import 'package:manage_time/screens/dashboard/dashboard_screen.dart';
import 'package:manage_time/screens/auth/register_screen.dart';
import 'package:manage_time/data/models/task_model.dart';
import 'package:manage_time/data/models/session_model.dart';
import 'package:manage_time/data/models/event_model.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _rememberMe = false;
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isDark = ThemeController.isDark;
  bool _showSuggestions = false;

  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _forgotEmailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();

  List<Map<String, String>> _savedAccounts = [];

  final String baseUrl = 'http://10.0.2.2:3000';

  @override
  void initState() {
    super.initState();
    _loadSavedAccounts();
    ThemeController.themeNotifier.addListener(_updateTheme);
  }

  void _updateTheme() {
    if (mounted) {
      setState(() => _isDark = ThemeController.isDark);
    }
  }

  Future<void> _loadSavedAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    String? rawData = prefs.getString('saved_accounts_list');

    if (rawData != null) {
      setState(() {
        _savedAccounts = List<Map<String, String>>.from(
          jsonDecode(rawData).map((item) => Map<String, String>.from(item)),
        );
      });
    }
  }

  Future<void> _saveAccount(String email, String password, String name) async {
    final prefs = await SharedPreferences.getInstance();

    _savedAccounts.removeWhere((item) => item['email'] == email);
    _savedAccounts.insert(0, {
      'email': email,
      'password': password,
      'name': name,
    });

    if (_savedAccounts.length > 5) {
      _savedAccounts = _savedAccounts.sublist(0, 5);
    }

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
      final response = await http
          .post(
        Uri.parse('$baseUrl/api/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _emailController.text.trim(),
          'password': _passwordController.text.trim(),
        }),
      )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (!mounted) return;

      if (response.statusCode == 200 && data['success'] == true) {
        String email = _emailController.text.trim();
        String name = data['user']?['fullName'] ?? email.split('@')[0];

        await _performLoginSuccess(
          email: email,
          name: name,
          password: _passwordController.text.trim(),
          remember: _rememberMe,
          title: 'Đăng nhập thành công!',
          content: 'Chào mừng $name quay trở lại.',
        );
      } else {
        _showErrorSnackBar(data['message']?.toString() ?? 'Sai tài khoản hoặc mật khẩu!');
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Không thể kết nối đến Backend Server ở cổng 3000!');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _performLoginSuccess({
    required String email,
    required String name,
    String password = '',
    bool remember = true,
    required String title,
    required String content,
  }) async {
    await TaskStorage.init(email);
    await HistoryStorage.init(email);
    await EventStorage.init(email);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', name);
    await prefs.setString('user_email', email);

    if (remember) {
      await prefs.setBool('is_logged_in', true);
      if (password.isNotEmpty) {
        await _saveAccount(email, password, name);
      }
    } else {
      await prefs.setBool('is_logged_in', false);
    }

    if (!mounted) return;

    _showLoginSuccessDialog(title, content);
  }

  Future<void> _handleForgotPassword() async {
    _forgotEmailController.clear();
    _otpController.clear();
    _newPasswordController.clear();

    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        int step = 1;
        bool dialogLoading = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> sendOtp() async {
              final email = _forgotEmailController.text.trim();

              if (email.isEmpty || !email.contains('@')) {
                _showErrorSnackBar('Vui lòng nhập email hợp lệ!');
                return;
              }

              setDialogState(() => dialogLoading = true);

              try {
                final response = await http
                    .post(
                  Uri.parse('$baseUrl/api/forgot-password'),
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode({'email': email}),
                )
                    .timeout(const Duration(seconds: 10));

                final data = jsonDecode(response.body);

                if (response.statusCode == 200 && data['success'] == true) {
                  setDialogState(() => step = 2);
                  _showInfoSnackBar(data['message']?.toString() ?? 'Đã gửi OTP về Gmail!');
                } else {
                  _showErrorSnackBar(data['message']?.toString() ?? 'Gửi OTP thất bại!');
                }
              } catch (e) {
                _showErrorSnackBar('Không kết nối được server!');
              } finally {
                setDialogState(() => dialogLoading = false);
              }
            }

            Future<void> verifyOtp() async {
              final email = _forgotEmailController.text.trim();
              final otp = _otpController.text.trim();

              if (otp.isEmpty) {
                _showErrorSnackBar('Vui lòng nhập OTP!');
                return;
              }

              setDialogState(() => dialogLoading = true);

              try {
                final response = await http
                    .post(
                  Uri.parse('$baseUrl/api/verify-forgot-otp'),
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode({
                    'email': email,
                    'otp': otp,
                  }),
                )
                    .timeout(const Duration(seconds: 10));

                final data = jsonDecode(response.body);

                if (response.statusCode == 200 && data['success'] == true) {
                  setDialogState(() => step = 3);
                  _showInfoSnackBar(data['message']?.toString() ?? 'OTP chính xác!');
                } else {
                  _showErrorSnackBar(data['message']?.toString() ?? 'OTP không đúng!');
                }
              } catch (e) {
                _showErrorSnackBar('Không kết nối được server!');
              } finally {
                setDialogState(() => dialogLoading = false);
              }
            }

            Future<void> resetPassword() async {
              final email = _forgotEmailController.text.trim();
              final newPassword = _newPasswordController.text.trim();
              final confirmPassword = confirmPasswordController.text.trim();

              if (newPassword.length < 6) {
                _showErrorSnackBar('Mật khẩu mới phải từ 6 ký tự!');
                return;
              }

              if (newPassword != confirmPassword) {
                _showErrorSnackBar('Mật khẩu xác nhận không trùng khớp!');
                return;
              }

              setDialogState(() => dialogLoading = true);

              try {
                final response = await http
                    .post(
                  Uri.parse('$baseUrl/api/reset-password'),
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode({
                    'email': email,
                    'newPassword': newPassword,
                    'confirmPassword': confirmPassword,
                  }),
                )
                    .timeout(const Duration(seconds: 10));

                final data = jsonDecode(response.body);

                if (response.statusCode == 200 && data['success'] == true) {
                  Navigator.pop(dialogContext);
                  _showInfoSnackBar(data['message']?.toString() ?? 'Đổi mật khẩu thành công!');
                } else {
                  _showErrorSnackBar(data['message']?.toString() ?? 'Đổi mật khẩu thất bại!');
                }
              } catch (e) {
                _showErrorSnackBar('Không kết nối được server!');
              } finally {
                setDialogState(() => dialogLoading = false);
              }
            }

            return AlertDialog(
              backgroundColor: _isDark ? AppColors.cardBg : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                step == 1
                    ? 'Quên Mật Khẩu'
                    : step == 2
                    ? 'Nhập OTP'
                    : 'Đặt mật khẩu mới',
                style: TextStyle(
                  color: _isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (step == 1) ...[
                    Text(
                      'Nhập email đã đăng ký để nhận mã OTP.',
                      style: TextStyle(
                        color: _isDark ? Colors.white70 : Colors.black54,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _forgotEmailController,
                      keyboardType: TextInputType.emailAddress,
                      style: TextStyle(color: _isDark ? Colors.white : Colors.black87),
                      decoration: const InputDecoration(
                        labelText: 'Email liên kết',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                  ],
                  if (step == 2) ...[
                    Text(
                      'Kiểm tra Gmail và nhập mã OTP 6 số.',
                      style: TextStyle(
                        color: _isDark ? Colors.white70 : Colors.black54,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: _isDark ? Colors.white : Colors.black87),
                      decoration: const InputDecoration(
                        labelText: 'Mã OTP',
                        prefixIcon: Icon(Icons.lock_clock_outlined),
                      ),
                    ),
                  ],
                  if (step == 3) ...[
                    Text(
                      'OTP chính xác. Hãy đặt mật khẩu mới.',
                      style: TextStyle(
                        color: _isDark ? Colors.white70 : Colors.black54,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _newPasswordController,
                      obscureText: true,
                      style: TextStyle(color: _isDark ? Colors.white : Colors.black87),
                      decoration: const InputDecoration(
                        labelText: 'Mật khẩu mới',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmPasswordController,
                      obscureText: true,
                      style: TextStyle(color: _isDark ? Colors.white : Colors.black87),
                      decoration: const InputDecoration(
                        labelText: 'Xác nhận mật khẩu mới',
                        prefixIcon: Icon(Icons.lock_reset_outlined),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: dialogLoading ? null : () => Navigator.pop(dialogContext),
                  child: const Text(
                    'Hủy',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  onPressed: dialogLoading
                      ? null
                      : () async {
                    if (step == 1) {
                      await sendOtp();
                    } else if (step == 2) {
                      await verifyOtp();
                    } else {
                      await resetPassword();
                    }
                  },
                  child: dialogLoading
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : Text(
                    step == 1
                        ? 'Gửi OTP'
                        : step == 2
                        ? 'Xác minh'
                        : 'Đổi mật khẩu',
                    style: const TextStyle(
                      color: AppColors.background,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(scopes: ['email']);
      await googleSignIn.signOut();

      final GoogleSignInAccount? account = await googleSignIn.signIn();

      if (account == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final response = await http
          .post(
        Uri.parse('$baseUrl/api/google-login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fullName': account.displayName ?? 'Google User',
          'email': account.email,
          'photoUrl': account.photoUrl ?? '',
        }),
      )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (!mounted) return;

      if (response.statusCode == 200 && data['success'] == true) {
        final user = data['user'];

        await _performLoginSuccess(
          email: user['email'],
          name: user['fullName'] ?? account.displayName ?? 'Google User',
          remember: true,
          title: 'Google Login thành công!',
          content: 'Chào mừng ${user['fullName'] ?? account.displayName ?? 'Google User'} đến với ManageTime.',
        );
      } else {
        _showErrorSnackBar(data['message']?.toString() ?? 'Google Login thất bại!');
      }
    } catch (e) {
      if (!mounted) return;
      print('GOOGLE LOGIN ERROR: $e');
      _showErrorSnackBar('Lỗi Google/backend: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: Colors.redAccent, content: Text(message)),
    );
  }

  void _showInfoSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: AppColors.primary, content: Text(message)),
    );
  }

  void _showLoginSuccessDialog(String title, String content) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _isDark ? AppColors.cardBg : Colors.white,
        title: Text(
          title,
          style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
        ),
        content: Text(
          content,
          style: TextStyle(color: _isDark ? Colors.white70 : Colors.black54),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const DashboardScreen()),
              );
            },
            child: const Text(
              'Tiếp tục',
              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
            ),
          ),
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
                  Text(
                    'ManageTime Flow',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'Làm chủ thời gian, tối ưu hiệu suất',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(_isDark ? 0.3 : 0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Đăng nhập tài khoản',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _emailController,
                            style: TextStyle(color: textColor),
                            onTap: () {
                              setState(() => _showSuggestions = _savedAccounts.isNotEmpty);
                            },
                            decoration: const InputDecoration(
                              labelText: 'Email Address',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            validator: (value) {
                              return (value == null || !value.contains('@'))
                                  ? 'Vui lòng nhập Email hợp lệ'
                                  : null;
                            },
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
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                  color: AppColors.textMuted,
                                ),
                                onPressed: () {
                                  setState(() => _obscurePassword = !_obscurePassword);
                                },
                              ),
                            ),
                            validator: (value) {
                              return (value == null || value.length < 6)
                                  ? 'Mật khẩu phải từ 6 ký tự'
                                  : null;
                            },
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
                                    onChanged: (value) {
                                      setState(() => _rememberMe = value ?? false);
                                    },
                                  ),
                                  Text(
                                    'Ghi nhớ tôi',
                                    style: TextStyle(
                                      color: textColor.withOpacity(0.7),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              TextButton(
                                onPressed: _handleForgotPassword,
                                child: const Text(
                                  'Quên mật khẩu?',
                                  style: TextStyle(color: AppColors.primary, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: _isLoading ? null : _handleSignIn,
                              child: _isLoading
                                  ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                                  : const Text(
                                'Sign In Now',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: OutlinedButton.icon(
                              onPressed: _isLoading ? null : _handleGoogleSignIn,
                              icon: const Icon(Icons.g_mobiledata, color: Colors.blue, size: 30),
                              label: Text(
                                'Continue with Google Account',
                                style: TextStyle(color: textColor, fontSize: 14),
                              ),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
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
                      Text(
                        'Bạn chưa có tài khoản? ',
                        style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 14),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const RegisterScreen()),
                          );
                        },
                        child: const Text(
                          'Đăng ký ngay',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_showSuggestions)
            Positioned(
              left: 30,
              right: 30,
              top: 350,
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
                        title: Text(
                          acc['email']!,
                          style: TextStyle(color: textColor, fontSize: 14),
                        ),
                        subtitle: Text(
                          acc['name']!,
                          style: const TextStyle(fontSize: 12),
                        ),
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
                            await prefs.setString(
                              'saved_accounts_list',
                              jsonEncode(_savedAccounts),
                            );
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