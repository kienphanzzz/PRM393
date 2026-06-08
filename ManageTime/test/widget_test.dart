import 'package:flutter_test/flutter_test.dart';
import 'package:manage_time/main.dart';
import 'package:manage_time/screens/auth/splash_screen.dart';

void main() {
  testWidgets('App splash screen smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const FocusFlowApp(initialScreen: SplashScreen()));

    // Verify that Splash Screen content is shown.
    expect(find.text('Focus'), findsOneWidget);
    expect(find.text('Flow'), findsOneWidget);
    expect(find.text('Calm. Focused. Productive.'), findsOneWidget);
  });
}
