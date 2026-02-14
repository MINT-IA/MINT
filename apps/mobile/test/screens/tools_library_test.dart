import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/screens/tools_library_screen.dart';

void main() {
  testWidgets('ToolsLibraryScreen renders without crashing',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: ToolsLibraryScreen()));
    await tester.pumpAndSettle();

    // App bar title
    expect(find.text('Tous les outils'), findsOneWidget);
  });

  testWidgets('ToolsLibraryScreen shows search field',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: ToolsLibraryScreen()));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('ToolsLibraryScreen shows category headers in uppercase',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: ToolsLibraryScreen()));
    await tester.pumpAndSettle();

    // Categories are displayed with .toUpperCase()
    expect(find.text('PREVOYANCE'), findsOneWidget);
  });
}
