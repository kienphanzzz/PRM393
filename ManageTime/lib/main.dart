import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:manage_time/core/constants.dart';
import 'package:manage_time/screens/auth/auth_screen.dart';
import 'package:manage_time/screens/dashboard/dashboard_screen.dart';
import 'package:manage_time/data/models/session_model.dart';
import 'package:manage_time/data/models/task_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();

  bool savedTheme = prefs.getBool('is_dark_theme') ?? true;
  ThemeController.isDark = savedTheme;
  ThemeController.themeNotifier.value = savedTheme;

  try {
    await HistoryStorage.loadHistoryFromDisk();
    await TaskStorage.loadTasks();
    await initializeBackgroundService();
  } catch (e) {
    debugPrint('Lỗi khởi tạo hệ thống: $e');
  }

  bool isLoggedIn = prefs.getBool('is_logged_in') ?? false;

  runApp(MyApp(
    initialScreen: isLoggedIn ? const DashboardScreen() : const AuthScreen(),
  ));
}

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'managetime_pomo_channel',
    'ManageTime Pomodoro Service',
    description: 'Thanh trạng thái đếm ngược Pomodoro',
    importance: Importance.max,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStartBackgroundLogic,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'managetime_pomo_channel',
      initialNotificationTitle: '⚡ ĐANG TẬP TRUNG CAO ĐỘ',
      initialNotificationContent: 'Đang khởi động vòng lặp...',
      // KHÔNG CẦN CHỈ ĐỊNH TYPE Ở ĐÂY NẾU MANIFEST ĐÃ CÓ VÀ DÙNG BẢN 5.0.0
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStartBackgroundLogic,
      onBackground: (ServiceInstance service) => true,
    ),
  );
}

@pragma('vm:entry-point')
void onStartBackgroundLogic(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final FlutterLocalNotificationsPlugin notificationPlugin = FlutterLocalNotificationsPlugin();

  int secondsRemaining = 25 * 60;
  bool isRunning = true;
  String taskTitle = "Phiên tập trung";

  service.on('start').listen((event) {
    if (event != null) {
      secondsRemaining = event['seconds'] ?? (25 * 60);
      taskTitle = event['taskTitle'] ?? "Phiên tập trung";
    }
    isRunning = true;
  });

  service.on('pause').listen((event) => isRunning = false);
  service.on('resume').listen((event) => isRunning = true);
  service.on('stop').listen((event) => service.stopSelf());

  Timer.periodic(const Duration(seconds: 1), (timer) async {
    if (!isRunning) {
      notificationPlugin.show(
        888,
        '⏸️ ĐANG TẠM DỪNG PHIÊN',
        'Nhiệm vụ: $taskTitle (Đang chờ tiếp tục)',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'managetime_pomo_channel',
            'ManageTime Pomodoro Service',
            ongoing: true,
            onlyAlertOnce: true,
            importance: Importance.max,
            icon: '@mipmap/ic_launcher',
          ),
        ),
      );
      return;
    }

    if (secondsRemaining > 0) {
      secondsRemaining--;
      int mins = secondsRemaining ~/ 60;
      int secs = secondsRemaining % 60;
      String timeStr = '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

      service.invoke('update', {'seconds': secondsRemaining});

      notificationPlugin.show(
        888,
        '⏳ FOCUS FLOW: $timeStr',
        'Đang thực hiện: $taskTitle',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'managetime_pomo_channel',
            'ManageTime Pomodoro Service',
            ongoing: true,
            onlyAlertOnce: true,
            importance: Importance.max,
            icon: '@mipmap/ic_launcher',
          ),
        ),
      );
    } else {
      service.invoke('finished');
      timer.cancel();
      service.stopSelf();
    }
  });
}

class MyApp extends StatelessWidget {
  final Widget initialScreen;
  const MyApp({super.key, required this.initialScreen});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.themeNotifier,
      builder: (context, child) {
        bool isDark = ThemeController.themeNotifier.value;
        return MaterialApp(
          title: 'ManageTime',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: Brightness.light,
            scaffoldBackgroundColor: const Color(0xFFF8F9FA),
            primaryColor: AppColors.primary,
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: AppColors.background,
            primaryColor: AppColors.primary,
          ),
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          home: initialScreen,
        );
      },
    );
  }
}

class ThemeController {
  static bool isDark = true;
  static final ValueNotifier<bool> themeNotifier = ValueNotifier<bool>(true);
  static void toggleTheme(bool val) {
    isDark = val;
    themeNotifier.value = val;
  }
  static ValueChanged<bool>? onThemeChanged;
}