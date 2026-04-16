// ────────────────────────────────────────────────────────────
//  ANIMATED CHIFFRE — Widget tests
// ────────────────────────────────────────────────────────────
//
//  Tests:
//  1.  Renders without crashing
//  2.  Shows final value after settle
//  3.  Respects prefix (CHF\u00a0)
//  4.  Respects suffix (/mois, %)
//  5.  No prefix / no suffix variants
//  6.  Swiss thousand separator (apostrophe) for ≥ 1000
//  7.  Zero value renders as "0"
//  8.  Custom color does not crash
//  9.  Custom duration does not crash
//  10. Value update re-animates (key rotation)
// ────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/coach/animated_chiffre.dart';

// ── Helper ──────────────────────────────────────────────────

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );

// ── Tests ───────────────────────────────────────────────────

void main() {
  group('AnimatedChiffre', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(_wrap(
        const AnimatedChiffre(value: 1000),
      ));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(AnimatedChiffre), findsOneWidget);
    });

    testWidgets('shows final value after animation settles', (tester) async {
      await tester.pumpWidget(_wrap(
        const AnimatedChiffre(value: 500, prefix: '', suffix: ''),
      ));
      await tester.pumpAndSettle();
      expect(find.text('500'), findsOneWidget);
    });

    testWidgets('default prefix is CHF\u00a0', (tester) async {
      await tester.pumpWidget(_wrap(
        const AnimatedChiffre(value: 100),
      ));
      await tester.pumpAndSettle();
      // Default prefix is 'CHF\u00a0' — look for text containing 'CHF'
      expect(
        find.textContaining('CHF'),
        findsOneWidget,
      );
    });

    testWidgets('custom prefix is displayed', (tester) async {
      await tester.pumpWidget(_wrap(
        const AnimatedChiffre(value: 42, prefix: 'Fr.\u00a0', suffix: ''),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('Fr.'), findsOneWidget);
    });

    testWidgets('suffix /mois is displayed', (tester) async {
      await tester.pumpWidget(_wrap(
        const AnimatedChiffre(
            value: 4500, prefix: 'CHF\u00a0', suffix: '/mois'),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('/mois'), findsOneWidget);
    });

    testWidgets('suffix % is displayed', (tester) async {
      await tester.pumpWidget(_wrap(
        const AnimatedChiffre(value: 65, prefix: '', suffix: '\u00a0%'),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('%'), findsOneWidget);
    });

    testWidgets('no prefix and no suffix — bare number', (tester) async {
      await tester.pumpWidget(_wrap(
        const AnimatedChiffre(value: 9999, prefix: '', suffix: ''),
      ));
      await tester.pumpAndSettle();
      // 9999 < 10000, formats as "9'999" with Swiss separator
      expect(find.textContaining("9'999"), findsOneWidget);
    });

    testWidgets('zero value renders as 0', (tester) async {
      await tester.pumpWidget(_wrap(
        const AnimatedChiffre(value: 0, prefix: '', suffix: ''),
      ));
      await tester.pumpAndSettle();
      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('Swiss thousand separator for value ≥ 1000', (tester) async {
      await tester.pumpWidget(_wrap(
        const AnimatedChiffre(value: 677847, prefix: '', suffix: ''),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining("677'847"), findsOneWidget);
    });

    testWidgets('custom color does not crash', (tester) async {
      await tester.pumpWidget(_wrap(
        const AnimatedChiffre(
          value: 1234,
          color: Color(0xFF007AFF),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(AnimatedChiffre), findsOneWidget);
    });

    testWidgets('custom duration does not crash', (tester) async {
      await tester.pumpWidget(_wrap(
        const AnimatedChiffre(
          value: 500,
          prefix: '',
          suffix: '',
          duration: Duration(milliseconds: 200),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('500'), findsOneWidget);
    });

    testWidgets('updating value re-renders correctly', (tester) async {
      final valueNotifier = ValueNotifier<double>(100);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<double>(
              valueListenable: valueNotifier,
              builder: (_, v, __) => AnimatedChiffre(
                value: v,
                prefix: '',
                suffix: '',
                duration: const Duration(milliseconds: 50),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('100'), findsOneWidget);

      valueNotifier.value = 200;
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('200'), findsOneWidget);
    });
  });
}
