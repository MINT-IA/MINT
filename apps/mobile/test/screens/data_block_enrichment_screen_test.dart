import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/onboarding/data_block_enrichment_screen.dart';

Widget _wrap(Widget child) {
  return ChangeNotifierProvider(
    create: (_) => CoachProfileProvider(),
    child: MaterialApp(home: child),
  );
}

void main() {
  testWidgets('maps pension alias to LPP block metadata', (tester) async {
    await tester.pumpWidget(
      _wrap(const DataBlockEnrichmentScreen(blockType: 'pension')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Prévoyance LPP'), findsOneWidget);
    expect(find.text('Ajouter mon certificat LPP'), findsOneWidget);
  });

  testWidgets('maps accented prevoyance alias to LPP block metadata',
      (tester) async {
    await tester.pumpWidget(
      _wrap(const DataBlockEnrichmentScreen(blockType: 'Prévoyance-LPP')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Prévoyance LPP'), findsOneWidget);
    expect(find.text('Ajouter mon certificat LPP'), findsOneWidget);
  });

  testWidgets('unknown block shows migration-safe fallback', (tester) async {
    await tester.pumpWidget(
      _wrap(const DataBlockEnrichmentScreen(blockType: 'legacy_unknown')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Données'), findsWidgets);
    expect(find.textContaining('n’est plus à jour'), findsOneWidget);
    expect(find.text('Ouvrir le diagnostic'), findsOneWidget);
  });
}
