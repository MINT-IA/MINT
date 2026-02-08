// Basic smoke test: verifies that core widgets compile and render.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/screens/landing_screen.dart';

void main() {
  testWidgets('LandingScreen renders without crash', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: LandingScreen()));
    await tester.pumpAndSettle();

    // LandingScreen should contain the hero text
    expect(find.textContaining('Financial OS'), findsWidgets);
  });
}
