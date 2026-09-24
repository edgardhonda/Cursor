import 'package:flutter_test/flutter_test.dart';

import 'package:bombas/main.dart';

void main() {
  testWidgets('game shows its controls', (WidgetTester tester) async {
    await tester.pumpWidget(const BombasApp());
    await tester.pump();

    expect(find.text('Fixar'), findsOneWidget);
    expect(find.text('Reiniciar'), findsOneWidget);
    expect(find.text('Parar'), findsOneWidget);
  });
}
