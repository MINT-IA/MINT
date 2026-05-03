// ────────────────────────────────────────────────────────────────────
//  MintSceneRachatLPP — widget + computation tests
// ────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mint_mobile/widgets/chat_vivant/mint_scene_rachat_lpp.dart';
import 'package:mint_mobile/widgets/chat_vivant/mint_scene_rente_capital.dart'
    show MintSceneVariant;

Widget _harness(Widget child) => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 500,
          child: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ),
    );

bool _treeContainsText(WidgetTester tester, String needle) {
  final lower = needle.toLowerCase();
  for (final t in tester.widgetList<Text>(find.byType(Text))) {
    if ((t.data ?? '').toLowerCase().contains(lower)) return true;
    final span = t.textSpan;
    if (span != null && span.toPlainText().toLowerCase().contains(lower)) {
      return true;
    }
  }
  for (final r in tester.widgetList<RichText>(find.byType(RichText))) {
    if (r.text.toPlainText().toLowerCase().contains(lower)) return true;
  }
  return false;
}

const _bannedTerms = [
  'garanti',
  'garantie',
  'optimal',
  'meilleur',
  'certain',
  'assuré',
  'sans risque',
  'parfait',
];

void main() {
  group('RachatLppSeed (deterministic)', () {
    test('default values match prototype', () {
      const seed = RachatLppSeed();
      expect(seed.tauxMarginal, 0.35);
      expect(seed.anneesEchelon, 4);
      expect(seed.tauxConversion, 0.048);
    });

    test('60k rachat → 21k économie totale, 240 CHF/mois rente add', () {
      const seed = RachatLppSeed();
      expect(seed.rachatAnnuel(60000), 15000);
      expect(seed.economieParAn(60000), closeTo(5250, 0.01)); // 15000 × 0.35
      expect(seed.economieTotale(60000), closeTo(21000, 0.01));
      expect(seed.coutReelNet(60000), closeTo(39000, 0.01));
      expect(seed.renteAddAnnuelle(60000), closeTo(2880, 0.01)); // 60000 × 0.048
      expect(seed.renteAddMensuelle(60000), closeTo(240, 0.01));
    });

    test('zero rachat → zero everything', () {
      const seed = RachatLppSeed();
      expect(seed.economieTotale(0), 0);
      expect(seed.renteAddMensuelle(0), 0);
      expect(seed.coutReelNet(0), 0);
    });
  });

  group('MintSceneRachatLPP widget', () {
    testWidgets('renders header + phrase signature + 2 cards + slider + recul + CTA',
        (tester) async {
      await tester.pumpWidget(
        _harness(const MintSceneRachatLPP()),
      );
      expect(find.text('SCÈNE'), findsOneWidget);
      expect(_treeContainsText(tester, 'rachat échelonné sur 4 ans'), isTrue);
      // Phrase signature with current montant 60'000
      expect(_treeContainsText(tester, '60’000'), isTrue);
      expect(_treeContainsText(tester, 'récupères'), isTrue);
      // Two cards
      expect(find.text('Économie fiscale'), findsOneWidget);
      expect(find.text('Rente en plus'), findsOneWidget);
      // Slider
      expect(find.text('Montant du rachat'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
      // Phrase de recul
      expect(_treeContainsText(tester, 'Coût réel net'), isTrue);
      expect(_treeContainsText(tester, 'l\'État qui finance'), isTrue);
      // CTA
      expect(_treeContainsText(tester, 'Voir le plan année par année'), isTrue);
    });

    testWidgets('embedded variant hides CTA', (tester) async {
      await tester.pumpWidget(
        _harness(
          const MintSceneRachatLPP(variant: MintSceneVariant.embedded),
        ),
      );
      expect(_treeContainsText(tester, 'Voir le plan année par année'), isFalse);
    });

    testWidgets('slider drag updates the displayed amounts', (tester) async {
      await tester.pumpWidget(
        _harness(
          const MintSceneRachatLPP(initialMontant: 60000),
        ),
      );
      expect(_treeContainsText(tester, '60’000'), isTrue);

      // Drive slider to 100k via onChanged
      final slider = tester.widget<Slider>(find.byType(Slider));
      slider.onChanged?.call(100000);
      await tester.pump();

      expect(_treeContainsText(tester, '100’000'), isTrue);
      // Économie totale at 100k = 100000 / 4 × 0.35 × 4 = 35000
      expect(_treeContainsText(tester, '35’000'), isTrue);
    });

    testWidgets('initial montant clamped to slider range', (tester) async {
      // Below min → clamped to min
      await tester.pumpWidget(
        _harness(
          const MintSceneRachatLPP(
            key: ValueKey('low'),
            initialMontant: 5000, // below 20000 min
          ),
        ),
      );
      expect(_treeContainsText(tester, '20’000'), isTrue);

      // Above max → clamped to max
      await tester.pumpWidget(
        _harness(
          const MintSceneRachatLPP(
            key: ValueKey('high'),
            initialMontant: 999999,
          ),
        ),
      );
      expect(_treeContainsText(tester, '150’000'), isTrue);
    });

    testWidgets('CTA fires onOpenCanvas', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        _harness(
          MintSceneRachatLPP(onOpenCanvas: () => tapped++),
        ),
      );
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(tapped, 1);
    });

    testWidgets('LSFin compliance — no banned terms', (tester) async {
      await tester.pumpWidget(_harness(const MintSceneRachatLPP()));
      // Walk all texts.
      for (final t in tester.widgetList<Text>(find.byType(Text))) {
        final s = (t.data ?? '').toLowerCase();
        for (final banned in _bannedTerms) {
          expect(s.contains(banned), isFalse,
              reason: 'Banned « $banned » in: $s');
        }
      }
      for (final r in tester.widgetList<RichText>(find.byType(RichText))) {
        final s = r.text.toPlainText().toLowerCase();
        for (final banned in _bannedTerms) {
          expect(s.contains(banned), isFalse,
              reason: 'Banned « $banned » in rich: $s');
        }
      }
    });

    testWidgets('CHF formatter uses Swiss apostrophe (U+2019)', (tester) async {
      await tester.pumpWidget(_harness(const MintSceneRachatLPP()));
      // Default 60000 → « 60’000 »
      expect(_treeContainsText(tester, '60’000'), isTrue);
    });
  });
}
