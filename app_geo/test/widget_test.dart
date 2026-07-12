import 'package:flutter_test/flutter_test.dart';

import 'package:app_geo/main.dart';

void main() {
  testWidgets('App launches and shows home screen', (tester) async {
    await tester.pumpWidget(const AppGeo());
    await tester.pump();

    expect(find.text('Eco-tracer'), findsOneWidget);
    expect(find.text('Nouveau trajet'), findsOneWidget);
  });
}
