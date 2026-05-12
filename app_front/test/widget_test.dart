import 'package:flutter_test/flutter_test.dart';
import 'package:app_front/main.dart';

void main() {
  testWidgets('App starts correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const EcoGuideApp());
    await tester.pump();

    // Verify app starts (shows loading or login screen)
    expect(find.byType(EcoGuideApp), findsOneWidget);
  });
}
