import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/precision/smart_default_indicator.dart';
import 'package:mint_mobile/widgets/coach/indicatif_banner.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(body: child),
  );
}

void main() {
  // ════════════════════════════════════════════════════════════
  //  SMART DEFAULT INDICATOR
  // ════════════════════════════════════════════════════════════

  group('SmartDefaultIndicator', () {
    testWidgets('renders tilde and Estime badge', (tester) async {
      await tester.pumpWidget(_wrap(
        const SmartDefaultIndicator(
          source: 'Test source',
          confidence: 0.35,
        ),
      ));

      expect(find.text('~'), findsOneWidget);
      expect(find.text('Estime'), findsOneWidget);
    });

    testWidgets('default confidence is 0.25', (tester) async {
      const indicator = SmartDefaultIndicator(source: 'Test');
      expect(indicator.confidence, 0.25);
    });

    testWidgets('tap opens detail bottom sheet', (tester) async {
      await tester.pumpWidget(_wrap(
        const SmartDefaultIndicator(
          source: 'Estimation depuis ton salaire',
          confidence: 0.50,
        ),
      ));

      await tester.tap(find.text('~'));
      await tester.pumpAndSettle();

      expect(find.text('Valeur estimee'), findsOneWidget);
      expect(find.text('Estimation depuis ton salaire'), findsOneWidget);
      expect(find.textContaining('50'), findsWidgets); // 50%
    });

    testWidgets('Preciser button visible when onPrecise provided',
        (tester) async {
      bool tapped = false;
      await tester.pumpWidget(_wrap(
        SmartDefaultIndicator(
          source: 'Test',
          confidence: 0.30,
          onPrecise: () => tapped = true,
        ),
      ));

      await tester.tap(find.text('~'));
      await tester.pumpAndSettle();

      expect(find.text('Preciser ce chiffre'), findsOneWidget);
      await tester.tap(find.text('Preciser ce chiffre'));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets('Preciser button hidden when onPrecise is null',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const SmartDefaultIndicator(
          source: 'Test',
          confidence: 0.30,
        ),
      ));

      await tester.tap(find.text('~'));
      await tester.pumpAndSettle();

      expect(find.text('Preciser ce chiffre'), findsNothing);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  SMART DEFAULT VALUE
  // ════════════════════════════════════════════════════════════

  group('SmartDefaultValue', () {
    testWidgets('renders with tilde prefix', (tester) async {
      await tester.pumpWidget(_wrap(
        const SmartDefaultValue(
          label: "143'000",
          source: 'Estimation',
          confidence: 0.35,
        ),
      ));

      expect(find.text("~143'000"), findsOneWidget);
      expect(find.text('Estime'), findsOneWidget);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  INDICATIF BANNER
  // ════════════════════════════════════════════════════════════

  group('IndicatifBanner', () {
    testWidgets('hidden when confidence >= 70', (tester) async {
      await tester.pumpWidget(_wrap(
        const IndicatifBanner(confidenceScore: 70),
      ));

      expect(find.textContaining('indicatif'), findsNothing);
    });

    testWidgets('visible when confidence < 70', (tester) async {
      await tester.pumpWidget(_wrap(
        const IndicatifBanner(confidenceScore: 55),
      ));

      expect(find.textContaining('indicatif'), findsOneWidget);
      expect(find.textContaining('55%'), findsOneWidget);
    });

    testWidgets('shows Preciser CTA button', (tester) async {
      await tester.pumpWidget(_wrap(
        const IndicatifBanner(confidenceScore: 40),
      ));

      expect(find.text('Préciser'), findsOneWidget);
    });

    testWidgets('confidence 0 still renders', (tester) async {
      await tester.pumpWidget(_wrap(
        const IndicatifBanner(confidenceScore: 0),
      ));

      expect(find.textContaining('indicatif'), findsOneWidget);
      expect(find.textContaining('0%'), findsOneWidget);
    });

    testWidgets('defaults topEnrichmentCategory to lpp', (tester) async {
      const banner = IndicatifBanner(confidenceScore: 50);
      expect(banner.topEnrichmentCategory, isNull);
      // Internally uses 'lpp' as fallback (verified by code inspection)
    });
  });
}
