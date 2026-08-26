import 'package:flutter_test/flutter_test.dart';
import 'package:starten_wir_a1/main.dart';

void main() {
  testWidgets('application starts', (tester) async {
    await tester.pumpWidget(const StartenWirApp());
    expect(find.text('خانه'), findsOneWidget);
  });
}
