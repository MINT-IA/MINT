import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/confidence_point.dart';
import 'package:mint_mobile/widgets/aujourdhui/confidence_evolution_card.dart';

// ────────────────────────────────────────────────────────────
//  CONFIDENCE EVOLUTION CARD TEST — D5 « évolution visible »
//
//  Contract:
//   1. confidenceRunningMax → non-decreasing (monotonicity lives at render).
//   2. namedMilestone → latest explicit-trigger point, null when only passive.
//   3. 0 points → renders nothing (no empty section, D4).
//   4. 1 point → calm invite, no line.
//   5. ≥ 2 points → curve + current value.
//   6. render monotonicity → a raw dip shows the running-max, never the drop.
//   7. milestone from an explicit trigger is named; passive-only → no milestone.
// ────────────────────────────────────────────────────────────

Widget _buildApp(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('fr')],
    home: Scaffold(
      body: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: child,
      ),
    ),
  );
}

ConfidencePoint _pt(
  int daysAgo,
  double combined, {
  String trigger = 'profile_load',
}) {
  final d = DateTime(2026, 3, 20).subtract(Duration(days: daysAgo));
  return ConfidencePoint(
    date: d,
    combined: combined,
    completeness: combined,
    accuracy: combined,
    freshness: combined,
    understanding: combined,
    trigger: trigger,
  );
}

const _cardKey = Key('confidence-evolution-card');
const _curveKey = Key('confidence-evolution-curve');
const _singleKey = Key('confidence-evolution-single');
const _valueKey = Key('confidence-evolution-value');
const _milestoneKey = Key('confidence-evolution-milestone');

void main() {
  group('confidenceRunningMax (monotonicity)', () {
    test('a dipping raw series yields a non-decreasing running max', () {
      final series = confidenceRunningMax([
        _pt(4, 50),
        _pt(3, 40), // dip (freshness decay)
        _pt(2, 60),
        _pt(1, 55), // dip
        _pt(0, 70),
      ]);
      expect(series, [50, 50, 60, 60, 70]);
      for (var i = 1; i < series.length; i++) {
        expect(series[i], greaterThanOrEqualTo(series[i - 1]));
      }
    });

    test('non-finite combined values never reach the output (no throw)', () {
      final series = confidenceRunningMax([
        _pt(2, double.nan),
        _pt(1, 60),
        _pt(0, double.infinity),
      ]);
      expect(series.length, 3);
      for (final v in series) {
        expect(v.isFinite, isTrue);
      }
      // The finite 60 sets the max; the Infinity never raises it.
      expect(series.last, 60);
      // round() must not throw on any element.
      expect(() => series.map((v) => v.round()).toList(), returnsNormally);
    });
  });

  group('namedMilestone', () {
    test('returns the most recent explicit-trigger point', () {
      final m = namedMilestone([
        _pt(3, 50, trigger: 'profile_load'),
        _pt(2, 60, trigger: 'document_scan'),
        _pt(1, 62, trigger: 'check_in'),
        _pt(0, 63, trigger: 'profile_load'),
      ]);
      expect(m, isNotNull);
      expect(m!.trigger, 'check_in');
    });

    test('returns null when history holds only passive captures', () {
      final m = namedMilestone([
        _pt(1, 50, trigger: 'profile_load'),
        _pt(0, 55, trigger: 'profile_load'),
      ]);
      expect(m, isNull);
    });
  });

  group('ConfidenceEvolutionCard states', () {
    testWidgets('0 points renders nothing (no empty section)', (tester) async {
      await tester.pumpWidget(_buildApp(
        const ConfidenceEvolutionCard(points: []),
      ));
      await tester.pump();
      expect(find.byKey(_cardKey), findsNothing);
      expect(find.byKey(_curveKey), findsNothing);
    });

    testWidgets('1 point renders the calm invite, no curve', (tester) async {
      await tester.pumpWidget(_buildApp(
        ConfidenceEvolutionCard(points: [_pt(0, 55)]),
      ));
      await tester.pump();
      expect(find.byKey(_cardKey), findsOneWidget);
      expect(find.byKey(_singleKey), findsOneWidget);
      expect(find.byKey(_curveKey), findsNothing);
      expect(find.text('Ta lucidité grandit'), findsOneWidget);
    });

    testWidgets('>= 2 points renders the curve + current value',
        (tester) async {
      await tester.pumpWidget(_buildApp(
        ConfidenceEvolutionCard(points: [_pt(1, 60), _pt(0, 72)]),
      ));
      await tester.pump();
      expect(find.byKey(_cardKey), findsOneWidget);
      expect(find.byKey(_curveKey), findsOneWidget);
      expect(find.byKey(_valueKey), findsOneWidget);
      expect(find.byKey(_singleKey), findsNothing);
    });

    testWidgets('render shows the running-max, never the raw drop',
        (tester) async {
      // Raw last = 65, but the running max peaked at 72 earlier. A passive
      // user must never see the curve regress → the value is 72, not 65.
      await tester.pumpWidget(_buildApp(
        ConfidenceEvolutionCard(
          points: [_pt(2, 60), _pt(1, 72), _pt(0, 65)],
        ),
      ));
      await tester.pump();
      final valueText =
          tester.widget<Text>(find.byKey(_valueKey)).data;
      expect(valueText, '72');
      expect(find.text('65'), findsNothing);
    });

    testWidgets('names the milestone from an explicit trigger',
        (tester) async {
      await tester.pumpWidget(_buildApp(
        ConfidenceEvolutionCard(
          points: [
            _pt(2, 60, trigger: 'profile_load'),
            _pt(1, 68, trigger: 'document_scan'),
            _pt(0, 70, trigger: 'profile_load'),
          ],
        ),
      ));
      await tester.pump();
      expect(find.byKey(_milestoneKey), findsOneWidget);
      final label = tester.widget<Text>(find.byKey(_milestoneKey)).data;
      expect(label, contains('document'));
    });

    testWidgets('no milestone when history is only passive', (tester) async {
      await tester.pumpWidget(_buildApp(
        ConfidenceEvolutionCard(
          points: [_pt(1, 60), _pt(0, 70)],
        ),
      ));
      await tester.pump();
      expect(find.byKey(_curveKey), findsOneWidget);
      expect(find.byKey(_milestoneKey), findsNothing);
    });
  });
}
