import 'package:flutter_test/flutter_test.dart';
import 'package:manage_time/main.dart';
import 'package:manage_time/screens/auth/splash_screen.dart';

void main() {
  testWidgets('App splash screen smoke test', (WidgetTester tester) async {
    // Sửa lỗi: Truyền initialScreen vào MyApp để test màn hình Splash
    await tester.pumpWidget(const MyApp(initialScreen: SplashScreen()));

    expect(find.text('Focus'), findsOneWidget);
    expect(find.text('Flow'), findsOneWidget);
    expect(find.text('Calm. Focused. Productive.'), findsOneWidget);
  });
}
