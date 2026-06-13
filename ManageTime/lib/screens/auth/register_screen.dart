import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/constants.dart';
import '../../main.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _otpController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isDark = ThemeController.isDark;

  final String baseUrl = 'http://10.0.2.2:3000';

  @override
  void initState() {
    super.initState();
    ThemeController.themeNotifier.addListener(_updateTheme);
  }

  void _updateTheme() {
    if (mounted) {
      setState(() => _isDark = ThemeController.themeNotifier.value);
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();
    ThemeController.themeNotifier.removeListener(_updateTheme);
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await http
          .post(
        Uri.parse('$baseUrl/api/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fullName': _fullNameController.text.trim(),
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim(),
          'password': _passwordController.text.trim(),
        }),
      )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (!mounted) return;

      if (response.statusCode == 200 && data['success'] == true) {
        _showInfoSnackBar(data['message']?.toString() ?? 'Đã gửi OTP về Gmail!');
        _showVerifyOtpDialog();
      } else {
        _showErrorSnackBar(data['message']?.toString() ?? 'Đăng ký thất bại!');
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Không thể kết nối đến Backend Server ở cổng 3000!');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showVerifyOtpDialog() {
    _otpController.clear();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool dialogLoading = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> verifyOtp() async {
              final otp = _otpController.text.trim();

              if (otp.isEmpty) {
                _showErrorSnackBar('Vui lòng nhập mã OTP!');
                return;
              }

              setDialogState(() => dialogLoading = true);

              try {
                final response = await http
                    .post(
                  Uri.parse('$baseUrl/api/verify-register-otp'),
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode({
                    'email': _emailController.text.trim(),
                    'otp': otp,
                  }),
                )
                    .timeout(const Duration(seconds: 10));

                final data = jsonDecode(response.body);

                if (response.statusCode == 201 && data['success'] == true) {
                  if (!mounted) return;
                  Navigator.pop(dialogContext);
                  _showSuccessDialog(
                    'Đăng ký thành công!',
                    'Email đã được xác minh. Bạn có thể đăng nhập ngay.',
                  );
                } else {
                  _showErrorSnackBar(data['message']?.toString() ?? 'Xác minh OTP thất bại!');
                }
              } catch (e) {
                _showErrorSnackBar('Không thể kết nối server để xác minh OTP!');
              } finally {
                setDialogState(() => dialogLoading = false);
              }
            }

            return AlertDialog(
              backgroundColor: _isDark ? AppColors.cardBg : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                'Xác minh Gmail',
                style: TextStyle(
                  color: _isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Mã OTP đã được gửi về Gmail:\n${_emailController.text.trim()}',
                    textAlign: TextAlign.center,
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
                      labelText: 'Nhập mã OTP 6 số',
                      prefixIcon: Icon(Icons.mark_email_read_outlined),
                    ),
                  ),
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
                  onPressed: dialogLoading ? null : verifyOtp,
                  child: dialogLoading
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : const Text(
                    'Xác minh',
                    style: TextStyle(
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

  void _showSuccessDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text(
              'Đăng nhập ngay',
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Create Account',
                style: TextStyle(
                  color: textColor,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Đăng ký thông tin để tối ưu hiệu suất công việc',
                style: TextStyle(color: AppColors.textMuted, fontSize: 14),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: _isDark ? 0.3 : 0.05),
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
                        'Full Name',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _fullNameController,
                        style: TextStyle(color: textColor),
                        decoration: const InputDecoration(
                          hintText: 'Nhập họ và tên của bạn',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (value) {
                          return (value == null || value.trim().isEmpty)
                              ? 'Vui lòng nhập Họ và tên'
                              : null;
                        },
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Email Address',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _emailController,
                        style: TextStyle(color: textColor),
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          hintText: 'E.g., kien@gmail.com',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (value) {
                          return (value == null || !value.contains('@'))
                              ? 'Vui lòng nhập Email hợp lệ'
                              : null;
                        },
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Phone Number',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _phoneController,
                        style: TextStyle(color: textColor),
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          hintText: 'Nhập số điện thoại liên hệ',
                          prefixIcon: Icon(Icons.phone_android_outlined),
                        ),
                        validator: (value) {
                          return (value == null || value.length < 10)
                              ? 'Số điện thoại không hợp lệ'
                              : null;
                        },
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Password',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          hintText: 'Tạo mật khẩu bảo mật',
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
                              ? 'Mật khẩu phải từ 6 ký tự trở lên'
                              : null;
                        },
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Confirm Password',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          hintText: 'Nhập lại mật khẩu phía trên',
                          prefixIcon: const Icon(Icons.lock_reset_outlined),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                              color: AppColors.textMuted,
                            ),
                            onPressed: () {
                              setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value != _passwordController.text) {
                            return 'Mật khẩu xác nhận không trùng khớp!';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _isLoading ? null : _handleRegister,
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
                            'Sign Up Now',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}