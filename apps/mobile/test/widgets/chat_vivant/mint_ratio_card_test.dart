// ────────────────────────────────────────────────────────────────────
//  MintRatioCard — widget tests
// ────────────────────────────────────────────────────────────────────
//
//  Behavioural coverage :
//    1. Renders label uppercase + percentage + sub-label + explainer.
//    2. Percentage = round(numerator/denominator * 100), clamped 0..100.
//    3. Denominator ≤ 0 → 0 % (no divide-by-zero crash).
//    4. CHF format uses Swiss apostrophe U+2019 separator.
//    5. Gradient bar fill width = percentage / 100.
//    6. Semantics exposes « label : N pour cent. explainer ».
//    7. Card uses porcelaine bg + 16 radius + 0.5px border.
// ────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/chat_vivant/mint_ratio_card.dart';

Widget _harness(Widget child) => MaterialApp(
      home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: child)),
    );

void main() {
  group('MintRatioCard', () {
    testWidgets('renders label uppercase + percentage + sub-label + explainer',
        (tester) async {
      await tester.pumpWidget(
        _harness(
          const MintRatioCard(
            label: 'ton train de vie couvert',
            numerator: 4416,
            denominator: 7000,
            explainer: 'Au taux actuel, ta rente AVS + LPP couvre cette part.',
          ),
        ),
      );

      // Label uppercased.
      expect(find.text('TON TRAIN DE VIE COUVERT'), findsOneWidget);
      // Percentage 4416/7000 = 63.08 → 63
      expect(find.textContaining('63'), findsWidgets);
      // Sub-label with Swiss apostrophe (U+2019)
      expect(find.text('4’416 sur 7’000 CHF/mois'), findsOneWidget);
      expect(
        find.text('Au taux actuel, ta rente AVS + LPP couvre cette part.'),
        findsOneWidget,
      );
    });

    testWidgets('percentage rounds to nearest integer', (tester) async {
      await tester.pumpWidget(
        _harness(
          const MintRatioCard(
            label: 'L',
            numerator: 65.6, // → 65.6%
            denominator: 100,
            explainer: 'e',
          ),
        ),
      );
      // Round(65.6) = 66
      expect(find.textContaining('66'), findsWidgets);
    });

    testWidgets('percentage clamped 0..100', (tester) async {
      await tester.pumpWidget(
        _harness(
          const MintRatioCard(
            label: 'L',
            numerator: 200,
            denominator: 100, // → 200% would be over-clamp
            explainer: 'e',
          ),
        ),
      );
      // Clamped to 100
      expect(find.textContaining('100'), findsWidgets);
    });

    testWidgets('denominator ≤ 0 renders 0% without crash', (tester) async {
      await tester.pumpWidget(
        _harness(
          const MintRatioCard(
            label: 'L',
            numerator: 50,
            denominator: 0, // edge case — guarded
            explainer: 'e',
          ),
        ),
      );
      // Should render 0, not crash.
      expect(find.textContaining('0'), findsWidgets);
    });

    testWidgets('CHF formatter uses Swiss apostrophe (U+2019)', (tester) async {
      await tester.pumpWidget(
        _harness(
          const MintRatioCard(
            label: 'L',
            numerator: 1234567,
            denominator: 2000000,
            explainer: 'e',
          ),
        ),
      );
      // 1234567 → 1’234’567 (Swiss style)
      expect(find.text('1’234’567 sur 2’000’000 CHF/mois'), findsOneWidget);
    });

    testWidgets('gradient bar fill width matches percentage', (tester) async {
      await tester.pumpWidget(
        _harness(
          const MintRatioCard(
            label: 'L',
            numerator: 50,
            denominator: 100, // → 50%
            explainer: 'e',
          ),
        ),
      );
      final fractional = tester.widget<FractionallySizedBox>(
        find.byType(FractionallySizedBox),
      );
      expect(fractional.widthFactor, 0.5);
    });

    testWidgets('card uses porcelaine bg + 16 radius + 0.5px border',
        (tester) async {
      await tester.pumpWidget(
        _harness(
          const MintRatioCard(
            label: 'L',
            numerator: 1,
            denominator: 2,
            explainer: 'e',
          ),
        ),
      );
      final container = tester.widget<Container>(
        find.descendant(of: find.byType(MintRatioCard), matching: find.byType(Container)).first,
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, MintColors.porcelaine);
      expect(decoration.borderRadius, BorderRadius.circular(16));
      expect((decoration.border as Border).top.width, 0.5);
    });

    testWidgets('default Semantics exposes percentage + explainer',
        (tester) async {
      await tester.pumpWidget(
        _harness(
          const MintRatioCard(
            label: 'PROPORTION',
            numerator: 30,
            denominator: 60, // 50%
            explainer: 'mon explication',
          ),
        ),
      );
      expect(
        find.bySemanticsLabel('PROPORTION : 50 pour cent. mon explication'),
        findsOneWidget,
      );
    });
  });
}
