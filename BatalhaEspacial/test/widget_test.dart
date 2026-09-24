import 'package:batalha_espacial/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows Pronto button before game starts', (tester) async {
    await tester.pumpWidget(const BatalhaEspacialApp());
    expect(find.text('Pronto!'), findsOneWidget);
    expect(find.text('Batalha Espacial'), findsOneWidget);
  });
}
