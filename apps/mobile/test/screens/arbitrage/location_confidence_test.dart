// ────────────────────────────────────────────────────────────
//  LOCATION VS PROPRIETE — confidence banner regression test
//
//  Codex W3 finding 3 (P2) : same leak as allocation — after the 50.0
//  floor removal (plan 11), a profile-less standalone what-if rendered a
//  « Résultat indicatif (0 %) » banner. Location is wired to
//  canonicalConfidence and hides the banner when there is no profile to
//  score (NO return of the fiction 50 floor).
// ────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/arbitrage/location_vs_propriete_screen.dart';
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
      home: LocationVsProprieteScreen(),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('compareLocationVsPropriete reflects the canonical profile score', () {
    final profile = _realProfile();
    final canonical = ConfidenceScorer.scoreEnhanced(profile).combined;

    final result = ArbitrageEngine.compareLocationVsPropriete(
      capitalDisponible: 200000,
      loyerMensuelActuel: 2000,
      prixBien: 800000,
      canonicalConfidence: canonical,
    );

    expect(result.confidenceScore, closeTo(canonical, 0.001),
        reason: 'with a profile the location arbitrage must reflect the '
            'canonical score (D12 generalised).');
  });

  testWidgets('NO profile → no 0% « Résultat indicatif » banner is shown',
      (tester) async {
    final provider = CoachProfileProvider(); // profile == null

    await tester.pumpWidget(_wrap(provider));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(IndicatifBanner, skipOffstage: false), findsNothing,
        reason: 'a profile-less standalone what-if must not render a 0% '
            'confidence banner.');
  });

  testWidgets('WITH profile → canonical confidence banner is shown',
      (tester) async {
    final provider = CoachProfileProvider();
    provider.updateProfile(_realProfile());

    await tester.pumpWidget(_wrap(provider));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(IndicatifBanner, skipOffstage: false), findsOneWidget,
        reason: 'with a profile below the 70 bar the canonical-confidence '
            'banner must be shown.');
  });
}
