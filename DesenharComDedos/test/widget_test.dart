import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:desenhar_com_dedos/main.dart';

void main() {
  testWidgets('App abre na tela de desenho', (WidgetTester tester) async {
    await tester.pumpWidget(const DesenharComDedosApp());
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });
}
