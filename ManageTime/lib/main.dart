import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/constants.dart';
import 'package:manage_time/screens/auth/auth_screen.dart';
import 'package:manage_time/screens/dashboard/dashboard_screen.dart';
import 'data/models/session_model.dart';
import 'data/models/task_model.dart';
import 'data/models/event_model.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
void onNotificationAction(NotificationResponse response) {
  final service = FlutterBackgroundService();

  if (response.actionId == 'pause') {
    service.invoke('pause');
  } else if (response.actionId == 'resume') {
    service.invoke('resume');
  } else if (response.actionId == 'stop') {
    service.invoke('kill');
    ThemeController.requestToStop = true;
    ThemeController.requestToFocus = true;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();

  ThemeController.isDark = prefs.getBool('is_dark_theme') ?? true;
  ThemeController.themeNotifier.value = ThemeController.isDark;

  final bool isLoggedIn = prefs.getBool('is_logged_in') ?? false;
  final String email = prefs.getString('user_email') ?? '';

  if (isLoggedIn && email.isNotEmpty) {
    await TaskStorage.init(email);
    await HistoryStorage.init(email);
    await EventStorage.init(email);
  }

  await initializeBackgroundService();

  final notificationPlugin = FlutterLocalNotificationsPlugin();

  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

  await notificationPlugin.initialize(
    const InitializationSettings(android: androidSettings),
    onDidReceiveNotificationResponse: (response) {
      final service = FlutterBackgroundService();

      if (response.actionId == 'pause') {
        service.invoke('pause');
      } else if (response.actionId == 'resume') {
        service.invoke('resume');
      } else if (response.actionId == 'stop') {
        service.invoke('kill');
        ThemeController.requestToStop = true;
        ThemeController.requestToFocus = true;
      } else {
        ThemeController.requestToFocus = true;
      }
    },
    onDidReceiveBackgroundNotificationResponse: onNotificationAction,
  );

  runApp(
    MyApp(
      initialScreen: isLoggedIn ? const DashboardScreen() : const AuthScreen(),
    ),
  );
}

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'pomo_action_channel',
    'Pomodoro Actions',
    description: 'Pomodoro timer controls',
    importance: Importance.max,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStartBackgroundLogic,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'pomo_action_channel',
      initialNotificationTitle: 'POMODORO READY',
      initialNotificationContent: 'Ready to focus',
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStartBackgroundLogic,
    ),
  );
}

@pragma('vm:entry-point')
void onStartBackgroundLogic(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final notificationPlugin = FlutterLocalNotificationsPlugin();

  int secondsRemaining = 25 * 60;
  bool isRunning = false;
  String taskTitle = 'Nhiệm vụ tập trung';
  String musicTitle = '';
  Timer? timer;

  void stopTimerOnly() {
    timer?.cancel();
    timer = null;
  }

  void sendUpdate(bool running) {
    service.invoke('update', {
      'seconds': secondsRemaining,
      'isRunning': running,
    });

    final String title = running ? '⏳ ĐANG CHẠY' : '⏸️ ĐÃ TẠM DỪNG';

    _updateNotify(
      notificationPlugin,
      title,
      taskTitle,
      musicTitle,
      secondsRemaining,
      running,
    );
  }

  void startCountdown() {
    stopTimerOnly();

    isRunning = true;

    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (secondsRemaining > 0) {
        secondsRemaining--;
        sendUpdate(true);
      } else {
        isRunning = false;
        t.cancel();
        timer = null;

        service.invoke('finished');
        sendUpdate(false);
      }
    });

    sendUpdate(true);
  }

  service.on('start').listen((event) {
    if (event != null) {
      secondsRemaining = event['seconds'] ?? 25 * 60;
      taskTitle = event['taskTitle'] ?? 'Nhiệm vụ tập trung';
      musicTitle = event['musicTitle'] ?? '';
    }

    startCountdown();
  });

  service.on('pause').listen((event) {
    if (!isRunning) return;

    isRunning = false;
    stopTimerOnly();
    sendUpdate(false);
  });

  service.on('resume').listen((event) {
    if (isRunning) return;
    if (secondsRemaining <= 0) return;

    startCountdown();
  });

  service.on('kill').listen((event) {
    isRunning = false;
    stopTimerOnly();
    service.stopSelf();
  });
}

void _updateNotify(
    FlutterLocalNotificationsPlugin plugin,
    String title,
    String body,
    String music,
    int seconds,
    bool running,
    ) {
  final int mins = seconds ~/ 60;
  final int secs = seconds % 60;

  final String timeStr =
      '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

  final String musicText = music.isNotEmpty ? ' | 🎵 $music' : '';

  plugin.show(
    888,
    '$title ($timeStr)',
    'Target: $body$musicText',
    NotificationDetails(
      android: AndroidNotificationDetails(
        'pomo_action_channel',
        'Pomodoro Actions',
        channelDescription: 'Pomodoro timer controls',
        ongoing: true,
        onlyAlertOnce: true,
        showWhen: false,
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        actions: [
          AndroidNotificationAction(
            running ? 'pause' : 'resume',
            running ? 'Tạm dừng' : 'Tiếp tục',
            showsUserInterface: false,
          ),
          const AndroidNotificationAction(
            'stop',
            'Dừng hẳn',
            showsUserInterface: true,
          ),
        ],
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  final Widget initialScreen;

  const MyApp({
    super.key,
    required this.initialScreen,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.themeNotifier,
      builder: (context, child) {
        return MaterialApp(
          title: 'ManageTime',
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: Brightness.light,
            primaryColor: AppColors.primary,
            scaffoldBackgroundColor: const Color(0xFFF8F9FA),
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primary,
              brightness: Brightness.light,
            ),
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primaryColor: AppColors.primary,
            scaffoldBackgroundColor: AppColors.background,
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primary,
              brightness: Brightness.dark,
            ),
          ),
          themeMode: ThemeController.themeNotifier.value
              ? ThemeMode.dark
              : ThemeMode.light,
          home: initialScreen,
        );
      },
    );
  }
}

class ThemeController {
  static bool isDark = true;

  static bool requestToFocus = false;
  static bool requestToStop = false;

  static final ValueNotifier<bool> themeNotifier = ValueNotifier<bool>(true);

  static void toggleTheme(bool val) {
    isDark = val;
    themeNotifier.value = val;
  }
}