import 'package:batalha/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('mostra paletas e custos iniciais', (tester) async {
    await tester.pumpWidget(const BatalhaApp());
    await tester.pump();
    expect(find.text('Lutar!'), findsOneWidget);
    expect(find.text('Azul  15'), findsOneWidget);
    expect(find.text('Vermelho  15'), findsOneWidget);
    expect(find.text('Cachorro'), findsWidgets);
    expect(find.text('Canhão'), findsWidgets);
    expect(find.byTooltip('Lenta'), findsOneWidget);
    expect(find.byTooltip('Média'), findsOneWidget);
    expect(find.byTooltip('Rápida'), findsOneWidget);
  });
}
