import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/screens/tools_library_screen.dart';
import 'package:mint_mobile/widgets/common/safe_mode_gate.dart';

void main() {
  testWidgets('ToolsLibraryScreen renders all sections',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: ToolsLibraryScreen()));

    expect(find.text('Outils Avancés'), findsOneWidget);
    expect(find.text('Simulateur d\'Intérêt Réel'), findsOneWidget);
    expect(find.text('Stratégie Rachat LPP'), findsOneWidget);
    expect(find.text('Droits aux Prestations (PC)'), findsOneWidget);
    expect(find.text('Générateur de Lettres'), findsOneWidget);
  });

  testWidgets('ToolsLibraryScreen toggles Safe Mode',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: ToolsLibraryScreen()));

    // Default: Safe Mode OFF -> Content visible
    expect(find.byType(SafeModeGate), findsWidgets);
    // Finds generic lock text? No, content visible.

    // Toggle switch
    await tester.tap(find.byType(Switch));
    await tester.pump();

    // Now Safe Mode ON -> Should see "Concentration Prioritaire" (Lock title)
    expect(find.text('Concentration Prioritaire'), findsWidgets);
  });
}
