import 'package:flutter_test/flutter_test.dart';

import 'package:destruir/main.dart';

void main() {
  testWidgets('Destruir app shows Pronto button', (WidgetTester tester) async {
    await tester.pumpWidget(const DestruirApp());
    expect(find.text('Pronto!'), findsOneWidget);
  });
}
