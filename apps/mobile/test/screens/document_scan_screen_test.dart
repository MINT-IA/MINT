import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/document_scan/document_scan_screen.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';

Widget _wrap(Widget child) {
  return ChangeNotifierProvider(
    create: (_) => CoachProfileProvider(),
    child: MaterialApp(home: child),
  );
}

void main() {
  testWidgets('Document scan screen renders production CTAs', (tester) async {
    await tester.pumpWidget(_wrap(const DocumentScanScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Prendre une photo'), findsOneWidget);
    expect(find.text('Depuis la galerie'), findsOneWidget);
    expect(find.textContaining('MODE PROTOTYPE'), findsNothing);
  });

  testWidgets('Manual OCR path opens input sheet', (tester) async {
    await tester.pumpWidget(_wrap(const DocumentScanScreen()));
    await tester.pumpAndSettle();

    final scrollable = find.byType(Scrollable);
    final pasteButton = find.text('Coller le texte OCR');
    await tester.scrollUntilVisible(
      pasteButton,
      300,
      scrollable: scrollable,
    );
    await tester.pumpAndSettle();

    expect(pasteButton, findsOneWidget);
    await tester.tap(pasteButton);
    await tester.pumpAndSettle();

    expect(find.text('Texte OCR'), findsOneWidget);
    expect(find.text('Analyser'), findsOneWidget);
  });

  testWidgets('Initial type preselects matching document description',
      (tester) async {
    await tester.pumpWidget(
      _wrap(const DocumentScanScreen(initialType: DocumentType.avsExtract)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Extrait de compte AVS'), findsWidgets);
    final hasAccented =
        find.text('Années de cotisation, RAMD, lacunes').evaluate().isNotEmpty;
    final hasUnaccented =
        find.text('Annees de cotisation, RAMD, lacunes').evaluate().isNotEmpty;
    expect(hasAccented || hasUnaccented, isTrue);
  });
}
