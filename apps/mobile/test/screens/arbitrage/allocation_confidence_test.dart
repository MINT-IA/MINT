// ────────────────────────────────────────────────────────────
//  ALLOCATION ANNUELLE — confidence banner regression test
//
//  Codex W3 finding 3 (P2) : plan 11 removed the misleading 50.0 floor
//  from ArbitrageEngine._computeArbitrageConfidence (it now returns 0.0
//  with empty/no dataSources). RvC was wired to canonicalConfidence, but
//  the OTHER arbitrage screens (allocation / location) call the engine
//  unchanged and render `result.confidenceScore` directly. A standalone
//  what-if (no profile in the tree) therefore showed a « Résultat
//  indicatif (0 % de fiabilité) » banner — a behavior change outside
//  plan 11's RvC scope.
//
//  Fix (honest, not fiction — NO return of the 50 floor) :
//   1. With a profile → the engine reflects the canonical profile score
//      (compareAllocationAnnuelle accepts canonicalConfidence).
//   2. Without a profile / dataSources → the screen does NOT render a 0%
//      confidence banner at all (a standalone calculator has no profile to
//      score).
// ────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/arbitrage/allocation_annuelle_screen.dart';
import 'package:mint_mobile/services/financial_core/arbitrage_engine.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';
import 'package:mint_mobile/widgets/coach/indicatif_banner.dart';

CoachProfile _realProfile() => CoachProfile(
      birthYear: DateTime.now().year - 40,
      canton: 'VD',
      salaireBrutMensuel: 90000 / 12,
      goalA: GoalA(
        type: GoalAType.retraite,
        targetDate: DateTime(DateTime.now().year + 25, 1, 1),
        label: 'Retraite',
      ),
    );

Widget _wrap(CoachProfileProvider provider) {
  return ChangeNotifierProvider<CoachProfileProvider>.value(
    value: provider,
    child: const MaterialApp(
      locale: Locale('fr'),
      localizationsDelegates: [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: AllocationAnnuelleScreen(),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Codex W3 finding 3 — engine canonical confidence', () {
    test('compareAllocationAnnuelle reflects the canonical profile score', () {
      final profile = _realProfile();
      final canonical = ConfidenceScorer.scoreEnhanced(profile).combined;

      final result = ArbitrageEngine.compareAllocationAnnuelle(
        montantDisponible: 7000,
        tauxMarginal: 0.25,
        canonicalConfidence: canonical,
      );

      expect(result.confidenceScore, closeTo(canonical, 0.001),
          reason: 'with a profile the allocation arbitrage must reflect the '
              'canonical score, not a divergent local engine (D12 generalised).');
    });

    test('no canonical + no dataSources → confidence is NOT the 50 floor', () {
      final result = ArbitrageEngine.compareAllocationAnnuelle(
        montantDisponible: 7000,
        tauxMarginal: 0.25,
        // no profile, no dataSources
      );
      // The misleading 50 floor must not return. (It is 0 here — the screen
      // is responsible for hiding the banner rather than showing 0%.)
      expect(result.confidenceScore, lessThan(50),
          reason: 'the fiction 50 floor must NOT come back.');
    });
  });

  group('Codex W3 finding 3 — allocation screen banner', () {
    testWidgets('NO profile → no 0% « Résultat indicatif » banner is shown',
        (tester) async {
      final provider = CoachProfileProvider(); // profile == null

      await tester.pumpWidget(_wrap(provider));
      await tester.pump(const Duration(milliseconds: 300));

      // The standalone calculator must NOT surface a 0% confidence banner.
      // (skipOffstage: false — the banner sits inside a SliverList and would
      // be off-screen even when present.)
      expect(find.byType(IndicatifBanner, skipOffstage: false), findsNothing,
          reason: 'a profile-less standalone what-if must not render a 0% '
              'confidence banner (no profile to score).');
      final ctx = tester.element(find.byType(AllocationAnnuelleScreen));
      final bannerTitle0 = S.of(ctx)!.indicativeBannerTitle('0');
      expect(find.text(bannerTitle0, skipOffstage: false), findsNothing,
          reason: 'the « Résultat indicatif (0 %) » text must not appear.');
    });

    testWidgets('WITH profile → canonical confidence banner is shown',
        (tester) async {
      final provider = CoachProfileProvider();
      provider.updateProfile(_realProfile());

      await tester.pumpWidget(_wrap(provider));
      await tester.pump(const Duration(milliseconds: 300));

      // A real (partial) profile yields combined ≈ 30 < 70 → the banner is
      // shown with the canonical score (not 0%, not the fiction 50 floor).
      // (skipOffstage: false — the banner sits inside a SliverList.)
      expect(find.byType(IndicatifBanner, skipOffstage: false), findsOneWidget,
          reason: 'with a profile below the 70 bar the canonical-confidence '
              'banner must be shown.');
    });
  });
}
