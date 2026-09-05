import 'package:flutter_test/flutter_test.dart';
import 'package:starten_wir_a1/app.dart';

void main() {
  testWidgets('splash shows while db boots', (tester) async {
    await tester.pumpWidget(const StartenWirApp());
    expect(find.text('در حال آماده‌سازی واژه‌ها…'), findsOneWidget);
  });
}
