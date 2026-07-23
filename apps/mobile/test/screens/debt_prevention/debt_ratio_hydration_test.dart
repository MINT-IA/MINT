// ────────────────────────────────────────────────────────────
//  DEBT RATIO — hydratation profil, zéro fiction (ILLOG-01)
//
//  Review PR #974 (beads MINT_nosync-64r) : surface jumelle de
//  RepaymentScreen — revenus 6000, charges 500, loyer 1500, autres 300
//  étaient hardcodés. Désormais hydratés du profil (revenu, mensualités
//  dettes, loyer, assurance maladie, état civil, enfants) ; sans provider
//  l'écran reste utilisable à zéro, sliders éditables.
// ────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/debt_prevention/debt_ratio_screen.dart';

Widget _wrap(Widget child, {CoachProfileProvider? provider}) {
  final app = MaterialApp(
    locale: const Locale('fr'),
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: S.supportedLocales,
    home: child,
  );
  if (provider == null) return app;
  return ChangeNotifierProvider<CoachProfileProvider>.value(
      value: provider, child: app);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('hydrate revenus + charges depuis le profil', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final provider = CoachProfileProvider();
    provider.updateProfile(CoachProfile(
      firstName: 'Sam',
      birthYear: 1990,
      canton: 'GE',
      salaireBrutMensuel: 8400, // x12 /12 -> 8'400
      dettes: const DetteProfile(
        mensualiteCreditConso: 320,
        mensualiteLeasing: 480,
      ),
      depenses: const DepensesProfile(loyer: 1900, assuranceMaladie: 420),
      goalA: GoalA(
        type: GoalAType.retraite,
        targetDate: DateTime(2045),
        label: 'Retraite',
      ),
    ));

    await tester.pumpWidget(_wrap(const DebtRatioScreen(), provider: provider));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining("8'400", skipOffstage: false), findsWidgets,
        reason: 'revenu mensuel hydraté du profil');
    expect(find.textContaining('800', skipOffstage: false), findsWidgets,
        reason: 'charges dettes = 320 + 480 du profil');
    // L'ancienne fiction ne doit plus apparaître.
    expect(find.textContaining("6'000", skipOffstage: false), findsNothing,
        reason: 'revenu fictif 6000 banni (ILLOG-01)');
  });

  testWidgets('sans provider : écran utilisable, valeurs à zéro',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(_wrap(const DebtRatioScreen()));
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull,
        reason: 'pas de crash sans CoachProfileProvider');
    expect(find.textContaining("6'000", skipOffstage: false), findsNothing);
    expect(find.textContaining("1'500", skipOffstage: false), findsNothing,
        reason: 'loyer fictif banni');
  });
}
