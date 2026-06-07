import 'package:flutter/material.dart';
import '../../core/constants.dart';
import 'auth_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AuthScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Spacer(),
            Icon(Icons.flash_on, size: 60, color: AppColors.primary),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Focus', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                Text('Flow', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.primary)),
              ],
            ),
            SizedBox(height: 12),
            Text('Calm. Focused. Productive.', style: TextStyle(color: AppColors.textMuted, fontSize: 16)),
            Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(radius: 4, backgroundColor: AppColors.primary),
                SizedBox(width: 8),
                CircleAvatar(radius: 4, backgroundColor: AppColors.textMuted),
                SizedBox(width: 8),
                CircleAvatar(radius: 4, backgroundColor: AppColors.textMuted),
              ],
            ),
            SizedBox(height: 24),
            Text('Loading your workspace...', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}