import 'package:flutter_test/flutter_test.dart';

import 'package:ache_a_figura/main.dart';

void main() {
  testWidgets('game displays its controls', (WidgetTester tester) async {
    await tester.pumpWidget(const AcheAFiguraApp());
    await tester.pump();

    expect(find.text('Fixar'), findsOneWidget);
    expect(find.text('Reiniciar'), findsOneWidget);
    expect(find.text('Parar'), findsOneWidget);
  });
}
