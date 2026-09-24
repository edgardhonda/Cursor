import 'package:cavando/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the digging game canvas', (tester) async {
    await tester.pumpWidget(const CavandoApp());
    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byTooltip('Reiniciar'), findsOneWidget);
  });
}
