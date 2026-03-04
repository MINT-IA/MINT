// Basic smoke test: verifies that core widgets compile and render.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/screens/landing_screen.dart';

void main() {
  testWidgets('LandingScreen renders without crash',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: LandingScreen()));
    await tester.pumpAndSettle();

    expect(find.byType(LandingScreen), findsOneWidget);
    expect(find.text('Ton plan en 30 secondes'), findsOneWidget);
    expect(find.text('Decouvrir MINT'), findsOneWidget);
  });
}
