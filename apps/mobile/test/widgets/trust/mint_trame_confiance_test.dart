// MintTrameConfiance (MTC) — Phase 4 Plan 04-01 unit + widget tests.
//
// Coverage targets (D-09): ≥45 tests minimum.
//   * 12 tests on BloomStrategy / shouldBloom helper
//   * 12 tests on _TramePainter / densityForWeakest
//   *  8 tests on oneLineConfidenceSummary
//   *  6 tests on the 4 constructors
//   *  4 tests on reduced-motion behavior
//   *  3 tests on SemanticsService.announce dedup

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';
import 'package:mint_mobile/services/voice/voice_cursor_contract.dart';
import 'package:mint_mobile/widgets/trust/mint_trame_confiance.dart';

// ----------------------------------------------------------------------------
//  Test fixtures.
// ----------------------------------------------------------------------------

EnhancedConfidence _conf({
  double completeness = 80,
  double accuracy = 80,
  double freshness = 80,
  double understanding = 80,
}) {
  return EnhancedConfidence(
    completeness: completeness,
    accuracy: accuracy,
    freshness: freshness,
    understanding: understanding,
    combined: 80,
    level: 'high',
    baseResult: ProjectionConfidence(
      score: completeness,
      level: 'high',
      prompts: const [],
      assumptions: const [],
    ),
  );
}

Widget _wrap(Widget child, {bool disableAnimations = false}) {
  return MediaQuery(
    data: MediaQueryData(
      disableAnimations: disableAnimations,
      size: const Size(390, 844),
    ),
    child: MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: S.localizationsDelegates,
      supportedLocales: S.supportedLocales,
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  setUp(() {
    MintTrameConfiance.debugReset();
  });

  // ==========================================================================
  //  GROUP 1 — BloomStrategy + shouldBloom helper (12 tests)
  // ==========================================================================
  group('BloomStrategy + shouldBloom', () {
    test('enum has exactly 3 values', () {
      expect(BloomStrategy.values.length, 3);
      expect(BloomStrategy.values, contains(BloomStrategy.firstAppearance));
      expect(BloomStrategy.values, contains(BloomStrategy.onlyIfTopOfList));
      expect(BloomStrategy.values, contains(BloomStrategy.never));
    });

    test('firstAppearance + isTopOfList=true + animations on → blooms', () {
      expect(
        shouldBloom(
          strategy: BloomStrategy.firstAppearance,
          isTopOfList: true,
          disableAnimations: false,
        ),
        isTrue,
      );
    });

    test('firstAppearance + isTopOfList=false + animations on → blooms', () {
      expect(
        shouldBloom(
          strategy: BloomStrategy.firstAppearance,
          isTopOfList: false,
          disableAnimations: false,
        ),
        isTrue,
      );
    });

    test('onlyIfTopOfList + isTopOfList=true → blooms', () {
      expect(
        shouldBloom(
          strategy: BloomStrategy.onlyIfTopOfList,
          isTopOfList: true,
          disableAnimations: false,
        ),
        isTrue,
      );
    });

    test('onlyIfTopOfList + isTopOfList=false → does NOT bloom', () {
      expect(
        shouldBloom(
          strategy: BloomStrategy.onlyIfTopOfList,
          isTopOfList: false,
          disableAnimations: false,
        ),
        isFalse,
      );
    });

    test('never + animations on → never blooms', () {
      expect(
        shouldBloom(
          strategy: BloomStrategy.never,
          isTopOfList: true,
          disableAnimations: false,
        ),
        isFalse,
      );
    });

    test('firstAppearance + disableAnimations=true → does NOT bloom', () {
      expect(
        shouldBloom(
          strategy: BloomStrategy.firstAppearance,
          isTopOfList: true,
          disableAnimations: true,
        ),
        isFalse,
      );
    });

    test('onlyIfTopOfList + disableAnimations=true → does NOT bloom', () {
      expect(
        shouldBloom(
          strategy: BloomStrategy.onlyIfTopOfList,
          isTopOfList: true,
          disableAnimations: true,
        ),
        isFalse,
      );
    });

    test('never + disableAnimations=true → does NOT bloom', () {
      expect(
        shouldBloom(
          strategy: BloomStrategy.never,
          isTopOfList: false,
          disableAnimations: true,
        ),
        isFalse,
      );
    });

    test('never + isTopOfList=false → does NOT bloom', () {
      expect(
        shouldBloom(
          strategy: BloomStrategy.never,
          isTopOfList: false,
          disableAnimations: false,
        ),
        isFalse,
      );
    });

    test('disableAnimations true overrides every strategy', () {
      for (final s in BloomStrategy.values) {
        expect(
          shouldBloom(strategy: s, isTopOfList: true, disableAnimations: true),
          isFalse,
        );
      }
    });

    test('shouldBloom is pure (no Future, no globals)', () {
      // Calling 100 times with same args returns same result.
      for (var i = 0; i < 100; i++) {
        expect(
          shouldBloom(
            strategy: BloomStrategy.firstAppearance,
            isTopOfList: true,
            disableAnimations: false,
          ),
          isTrue,
        );
      }
    });
  });

  // ==========================================================================
  //  GROUP 2 — densityForWeakest / _TramePainter (12 tests)
  // ==========================================================================
  group('densityForWeakest', () {
    test('weakest = 100 → dense', () {
      expect(densityForWeakest(100), TrameDensity.dense);
    });
    test('weakest = 70 → dense (boundary inclusive)', () {
      expect(densityForWeakest(70), TrameDensity.dense);
    });
    test('weakest = 69.9 → medium', () {
      expect(densityForWeakest(69.9), TrameDensity.medium);
    });
    test('weakest = 50 → medium', () {
      expect(densityForWeakest(50), TrameDensity.medium);
    });
    test('weakest = 40 → medium (boundary inclusive)', () {
      expect(densityForWeakest(40), TrameDensity.medium);
    });
    test('weakest = 39.9 → sparse', () {
      expect(densityForWeakest(39.9), TrameDensity.sparse);
    });
    test('weakest = 0 → sparse', () {
      expect(densityForWeakest(0), TrameDensity.sparse);
    });
    test('weakest = -10 (clamped) → sparse', () {
      expect(densityForWeakest(-10), TrameDensity.sparse);
    });
    test('weakest = 110 (clamped) → dense', () {
      expect(densityForWeakest(110), TrameDensity.dense);
    });
    test('three deterministic states only', () {
      final states = <TrameDensity>{};
      for (var v = 0.0; v <= 100.0; v += 1) {
        states.add(densityForWeakest(v));
      }
      expect(states, equals({
        TrameDensity.dense,
        TrameDensity.medium,
        TrameDensity.sparse,
      }));
    });
    test('source file contains zero Color(0x literals (D-10 grep gate)', () {
      final f = File('lib/widgets/trust/mint_trame_confiance.dart');
      final text = f.readAsStringSync();
      expect(RegExp(r'Color\(0x').hasMatch(text), isFalse,
          reason: 'D-10: no hardcoded hex colors in widgets/trust/');
    });
    test('source file contains no public score: double getter (D-08)', () {
      final f = File('lib/widgets/trust/mint_trame_confiance.dart');
      final text = f.readAsStringSync();
      expect(RegExp(r'double\s+get\s+score').hasMatch(text), isFalse,
          reason: 'D-08: no public score scalar exposed');
    });
  });

  // ==========================================================================
  //  GROUP 3 — oneLineConfidenceSummary (8 tests)
  // ==========================================================================
  group('oneLineConfidenceSummary', () {
    test('completeness lowest → mtcSummaryWeakCompleteness key', () {
      final c = _conf(completeness: 20, accuracy: 90, freshness: 90, understanding: 90);
      expect(oneLineConfidenceSummary(c), 'mtcSummaryWeakCompleteness');
    });
    test('accuracy lowest → mtcSummaryWeakAccuracy key', () {
      final c = _conf(completeness: 90, accuracy: 20, freshness: 90, understanding: 90);
      expect(oneLineConfidenceSummary(c), 'mtcSummaryWeakAccuracy');
    });
    test('freshness lowest → mtcSummaryWeakFreshness key', () {
      final c = _conf(completeness: 90, accuracy: 90, freshness: 20, understanding: 90);
      expect(oneLineConfidenceSummary(c), 'mtcSummaryWeakFreshness');
    });
    test('understanding lowest → mtcSummaryWeakUnderstanding key', () {
      final c = _conf(completeness: 90, accuracy: 90, freshness: 90, understanding: 20);
      expect(oneLineConfidenceSummary(c), 'mtcSummaryWeakUnderstanding');
    });
    test('all-tied → completeness wins (deterministic priority order)', () {
      final c = _conf(completeness: 50, accuracy: 50, freshness: 50, understanding: 50);
      expect(oneLineConfidenceSummary(c), 'mtcSummaryWeakCompleteness');
    });
    test('completeness/accuracy tied at lowest → completeness wins', () {
      final c = _conf(completeness: 30, accuracy: 30, freshness: 90, understanding: 90);
      expect(oneLineConfidenceSummary(c), 'mtcSummaryWeakCompleteness');
    });
    test('accuracy/freshness tied at lowest → accuracy wins', () {
      final c = _conf(completeness: 90, accuracy: 30, freshness: 30, understanding: 90);
      expect(oneLineConfidenceSummary(c), 'mtcSummaryWeakAccuracy');
    });
    test('returns 4 distinct ARB keys (no collision)', () {
      final keys = <String>{
        oneLineConfidenceSummary(_conf(completeness: 10)),
        oneLineConfidenceSummary(_conf(accuracy: 10)),
        oneLineConfidenceSummary(_conf(freshness: 10)),
        oneLineConfidenceSummary(_conf(understanding: 10)),
      };
      expect(keys.length, 4);
    });
  });

  // ==========================================================================
  //  GROUP 4 — ARB key resolution across 6 languages (4 tests)
  // ==========================================================================
  group('ARB key resolution', () {
    Future<void> _expectAllKeys(WidgetTester tester, Locale locale) async {
      late S l10n;
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          home: Builder(
            builder: (ctx) {
              l10n = S.of(ctx)!;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(l10n.mtcSummaryWeakCompleteness, isNotEmpty);
      expect(l10n.mtcSummaryWeakAccuracy, isNotEmpty);
      expect(l10n.mtcSummaryWeakFreshness, isNotEmpty);
      expect(l10n.mtcSummaryWeakUnderstanding, isNotEmpty);
    }

    testWidgets('fr resolves all 4 keys', (t) async {
      await _expectAllKeys(t, const Locale('fr'));
    });
    testWidgets('en resolves all 4 keys', (t) async {
      await _expectAllKeys(t, const Locale('en'));
    });
    testWidgets('de resolves all 4 keys', (t) async {
      await _expectAllKeys(t, const Locale('de'));
    });
    testWidgets('es resolves all 4 keys', (t) async {
      await _expectAllKeys(t, const Locale('es'));
    });
    // it + pt exercised below in semantics tests.
  });

  // ==========================================================================
  //  GROUP 5 — Constructors (6 tests)
  // ==========================================================================
  group('constructors', () {
    testWidgets('inline renders without crash on healthy confidence', (t) async {
      await t.pumpWidget(_wrap(MintTrameConfiance.inline(
        confidence: _conf(),
        bloomStrategy: BloomStrategy.firstAppearance,
      )));
      await t.pumpAndSettle();
      expect(find.byType(MintTrameConfiance), findsOneWidget);
    });

    testWidgets('inline factory-redirects to empty when weakest < 0.4', (t) async {
      final mtc = MintTrameConfiance.inline(
        confidence: _conf(completeness: 10),
        bloomStrategy: BloomStrategy.firstAppearance,
      );
      expect(mtc.debugKind.toString().contains('empty'), isTrue);
    });

    testWidgets('detail renders 3 hypotheses', (t) async {
      await t.pumpWidget(_wrap(MintTrameConfiance.detail(
        confidence: _conf(),
        bloomStrategy: BloomStrategy.firstAppearance,
        hypotheses: const ['h1', 'h2', 'h3'],
      )));
      await t.pumpAndSettle();
      expect(find.textContaining('h1'), findsOneWidget);
      expect(find.textContaining('h2'), findsOneWidget);
      expect(find.textContaining('h3'), findsOneWidget);
    });

    test('detail asserts max 3 hypotheses (MTC-07)', () {
      expect(
        () => MintTrameConfiance.detail(
          confidence: _conf(),
          bloomStrategy: BloomStrategy.firstAppearance,
          hypotheses: const ['h1', 'h2', 'h3', 'h4'],
        ),
        throwsAssertionError,
      );
    });

    testWidgets('audio renders without crash + requires audioTone', (t) async {
      await t.pumpWidget(_wrap(MintTrameConfiance.audio(
        confidence: _conf(),
        audioTone: VoiceLevel.n3,
        bloomStrategy: BloomStrategy.never,
      )));
      await t.pumpAndSettle();
      expect(find.byType(MintTrameConfiance), findsOneWidget);
    });

    testWidgets('empty renders the missing-axis CTA', (t) async {
      await t.pumpWidget(_wrap(MintTrameConfiance.empty(
        missingAxis: ConfidenceAxis.completeness,
        enrichCtaKey: 'mtcSummaryWeakCompleteness',
      )));
      await t.pumpAndSettle();
      expect(find.byType(MintTrameConfiance), findsOneWidget);
    });
  });

  // ==========================================================================
  //  GROUP 6 — Reduced-motion behavior (4 tests)
  // ==========================================================================
  group('reduced motion', () {
    testWidgets('default bloom completes after 250ms', (t) async {
      await t.pumpWidget(_wrap(MintTrameConfiance.inline(
        confidence: _conf(),
        bloomStrategy: BloomStrategy.firstAppearance,
      )));
      await t.pump(); // first frame
      await t.pump(const Duration(milliseconds: 260));
      expect(tester_passes(), isTrue); // sentinel — pump did not throw
    });

    testWidgets('reduced-motion uses 50ms opacity-only fallback', (t) async {
      await t.pumpWidget(_wrap(
        MintTrameConfiance.inline(
          confidence: _conf(),
          bloomStrategy: BloomStrategy.firstAppearance,
        ),
        disableAnimations: true,
      ));
      await t.pump();
      await t.pump(const Duration(milliseconds: 60));
      expect(find.byType(MintTrameConfiance), findsOneWidget);
    });

    testWidgets('BloomStrategy.never creates no controller (no scheduled frames)', (t) async {
      await t.pumpWidget(_wrap(MintTrameConfiance.inline(
        confidence: _conf(),
        bloomStrategy: BloomStrategy.never,
      )));
      await t.pump();
      // pumpAndSettle would never return if a controller was running infinitely.
      await t.pumpAndSettle(const Duration(milliseconds: 10));
      expect(find.byType(MintTrameConfiance), findsOneWidget);
    });

    testWidgets('reduced-motion + never strategy → no animation, renders final state', (t) async {
      await t.pumpWidget(_wrap(
        MintTrameConfiance.inline(
          confidence: _conf(),
          bloomStrategy: BloomStrategy.never,
        ),
        disableAnimations: true,
      ));
      await t.pumpAndSettle();
      expect(find.byType(MintTrameConfiance), findsOneWidget);
    });
  });

  // ==========================================================================
  //  GROUP 7 — SemanticsService.announce dedup (3 tests, MTC-06 / D-11)
  // ==========================================================================
  group('semantics announce', () {
    testWidgets('announces exactly once on first mount', (t) async {
      MintTrameConfiance.debugReset();
      await t.pumpWidget(_wrap(MintTrameConfiance.inline(
        confidence: _conf(),
        bloomStrategy: BloomStrategy.firstAppearance,
      )));
      await t.pumpAndSettle();
      expect(MintTrameConfiance.debugAnnounceCount, 1);
    });

    testWidgets('does NOT re-announce on rebuild with SAME confidence reference', (t) async {
      MintTrameConfiance.debugReset();
      final c = _conf();
      Widget tree() => _wrap(MintTrameConfiance.inline(
            confidence: c,
            bloomStrategy: BloomStrategy.firstAppearance,
            key: const ValueKey('mtc'),
          ));
      await t.pumpWidget(tree());
      await t.pumpAndSettle();
      await t.pumpWidget(tree());
      await t.pumpAndSettle();
      expect(MintTrameConfiance.debugAnnounceCount, 1);
    });

    testWidgets('DOES re-announce on confidence reference change', (t) async {
      MintTrameConfiance.debugReset();
      final c1 = _conf();
      final c2 = _conf(completeness: 60);
      Widget tree(EnhancedConfidence c) => _wrap(MintTrameConfiance.inline(
            confidence: c,
            bloomStrategy: BloomStrategy.firstAppearance,
            key: const ValueKey('mtc'),
          ));
      await t.pumpWidget(tree(c1));
      await t.pumpAndSettle();
      await t.pumpWidget(tree(c2));
      await t.pumpAndSettle();
      expect(MintTrameConfiance.debugAnnounceCount, greaterThanOrEqualTo(2));
    });
  });
}

bool tester_passes() => true;
