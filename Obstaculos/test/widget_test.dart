import 'package:flutter_test/flutter_test.dart';
import 'package:obstaculos/main.dart';

void main() {
  testWidgets('app builds', (tester) async {
    await tester.pumpWidget(const ObstaculosApp());
    expect(find.textContaining('Obstáculos'), findsOneWidget);
  });
}
