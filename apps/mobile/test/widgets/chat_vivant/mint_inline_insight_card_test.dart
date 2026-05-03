// ────────────────────────────────────────────────────────────────────
//  MintInlineInsightCard — widget tests
// ────────────────────────────────────────────────────────────────────
//
//  Behavioural coverage (no goldens — those land in Phase 55 once
//  Fraunces is locked in CI fonts cache; see Handoff 2 06-test-plan.md
//  invariant « test la structure, pas le pixel ») :
//
//    1. Renders label uppercase + headline + supporting in 3 distinct
//       Text widgets at the expected text-content level.
//    2. Tone variants resolve to expected background color :
//        • porcelaine → MintColors.porcelaine
//        • sauge      → MintColors.saugeClaire
//        • peche      → MintColors.pecheDouce.withValues(alpha: 0.35)
//        • craie      → MintColors.craie
//    3. Sauge tone uses successAaa label accent (not corailDiscret) for
//       AAA contrast against saugeClaire surface.
//    4. Card has 16-radius + 0.5px border per Handoff 2 spec.
//    5. Headline accepts Text.rich for `em` accents (no exception).
//    6. Supporting omitted → no third Text rendered.
//    7. Default Semantics container wraps the card.
// ────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/chat_vivant/mint_inline_insight_card.dart';

Widget _harness(Widget child) => MaterialApp(
      home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: child)),
    );

void main() {
  group('MintInlineInsightCard', () {
    testWidgets('renders label uppercase + headline + supporting', (tester) async {
      await tester.pumpWidget(
        _harness(
          MintInlineInsightCard(
            label: 'Ce qui compte vraiment',
            headline: const Text('Tu n\'as pas besoin de choisir tout de suite.'),
            supporting: 'Tu dois décider 3 ans avant.',
          ),
        ),
      );

      // Label is uppercased internally by the widget.
      expect(find.text('CE QUI COMPTE VRAIMENT'), findsOneWidget);
      expect(
        find.text('Tu n\'as pas besoin de choisir tout de suite.'),
        findsOneWidget,
      );
      expect(find.text('Tu dois décider 3 ans avant.'), findsOneWidget);
    });

    testWidgets('omitting supporting hides the third text', (tester) async {
      await tester.pumpWidget(
        _harness(
          const MintInlineInsightCard(
            label: 'INSIGHT',
            headline: Text('Une seule ligne hero.'),
          ),
        ),
      );
      expect(find.text('INSIGHT'), findsOneWidget);
      expect(find.text('Une seule ligne hero.'), findsOneWidget);
      expect(find.byType(Text), findsNWidgets(2));
    });

    testWidgets('tone porcelaine → porcelaine background', (tester) async {
      await tester.pumpWidget(
        _harness(
          const MintInlineInsightCard(
            label: 'L',
            headline: Text('H'),
            tone: MintInsightTone.porcelaine,
          ),
        ),
      );
      final container = tester.widget<Container>(
        find.descendant(of: find.byType(MintInlineInsightCard), matching: find.byType(Container)).first,
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, MintColors.porcelaine);
    });

    testWidgets('tone sauge → saugeClaire background', (tester) async {
      await tester.pumpWidget(
        _harness(
          const MintInlineInsightCard(
            label: 'L',
            headline: Text('H'),
            tone: MintInsightTone.sauge,
          ),
        ),
      );
      final container = tester.widget<Container>(
        find.descendant(of: find.byType(MintInlineInsightCard), matching: find.byType(Container)).first,
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, MintColors.saugeClaire);
    });

    testWidgets('tone craie → craie background', (tester) async {
      await tester.pumpWidget(
        _harness(
          const MintInlineInsightCard(
            label: 'L',
            headline: Text('H'),
            tone: MintInsightTone.craie,
          ),
        ),
      );
      final container = tester.widget<Container>(
        find.descendant(of: find.byType(MintInlineInsightCard), matching: find.byType(Container)).first,
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, MintColors.craie);
    });

    testWidgets('tone peche → pecheDouce 35% background', (tester) async {
      await tester.pumpWidget(
        _harness(
          const MintInlineInsightCard(
            label: 'L',
            headline: Text('H'),
            tone: MintInsightTone.peche,
          ),
        ),
      );
      final container = tester.widget<Container>(
        find.descendant(of: find.byType(MintInlineInsightCard), matching: find.byType(Container)).first,
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, MintColors.pecheDouce.withValues(alpha: 0.35));
    });

    testWidgets('sauge label uses successAaa accent (AAA contrast)', (tester) async {
      // Direct color assertion via the Text widget's resolved style.
      await tester.pumpWidget(
        _harness(
          const MintInlineInsightCard(
            label: 'BONNE NOUVELLE',
            headline: Text('h'),
            tone: MintInsightTone.sauge,
          ),
        ),
      );
      final labelText = tester.widget<Text>(find.text('BONNE NOUVELLE'));
      expect(labelText.style?.color, MintColors.successAaa);
    });

    testWidgets('porcelaine label uses corailDiscret accent', (tester) async {
      await tester.pumpWidget(
        _harness(
          const MintInlineInsightCard(
            label: 'INSIGHT',
            headline: Text('h'),
          ),
        ),
      );
      final labelText = tester.widget<Text>(find.text('INSIGHT'));
      expect(labelText.style?.color, MintColors.corailDiscret);
    });

    testWidgets('card uses 16 radius + 0.5px border', (tester) async {
      await tester.pumpWidget(
        _harness(
          const MintInlineInsightCard(label: 'L', headline: Text('H')),
        ),
      );
      final container = tester.widget<Container>(
        find.descendant(of: find.byType(MintInlineInsightCard), matching: find.byType(Container)).first,
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(16));
      expect((decoration.border as Border).top.width, 0.5);
      expect((decoration.border as Border).top.color, MintColors.border);
    });

    testWidgets('headline accepts Text.rich for em accents', (tester) async {
      await tester.pumpWidget(
        _harness(
          const MintInlineInsightCard(
            label: 'L',
            headline: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: 'Tu as 58 ans. '),
                  TextSpan(
                    text: '7 ans avant la retraite.',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      // Both spans render as part of the same RichText.
      expect(find.byType(RichText), findsWidgets);
    });

    testWidgets('semanticsLabel override sets the wrapper label', (tester) async {
      await tester.pumpWidget(
        _harness(
          const MintInlineInsightCard(
            label: 'L',
            headline: Text('H'),
            semanticsLabel: 'custom a11y label',
          ),
        ),
      );
      // Find the outermost Semantics widget wrapping the card (it sets the
      // explicit label). The inner content emits its own implicit
      // semantics nodes, so we check the wrapper Semantics directly.
      final semantics = tester.widgetList<Semantics>(
        find.descendant(
          of: find.byType(MintInlineInsightCard),
          matching: find.byType(Semantics),
        ),
      );
      final hasCustomLabel = semantics.any(
        (s) => s.properties.label == 'custom a11y label',
      );
      expect(hasCustomLabel, isTrue,
          reason: 'Outer Semantics wrapper must carry the custom label');
    });
  });
}
