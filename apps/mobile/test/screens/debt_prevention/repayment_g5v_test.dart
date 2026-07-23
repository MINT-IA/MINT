// ────────────────────────────────────────────────────────────
//  REPAYMENT — suivis panel -64r (beads MINT_nosync-g5v)
//
//  (1) Quand Σ mensualités minimales > budget saisi, le plan calcule sur
//      max(budget, Σmin) : l'UI doit le DIRE (note budget effectif) et la
//      marge survie ne doit jamais être un négatif fictif basé sur le
//      placeholder 800.
//  (4) Profil chargé APRÈS la première frame -> ré-hydratation tant que
//      l'utilisateur n'a pas édité.
// ────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/debt_prevention/repayment_screen.dart';
import 'package:mint_mobile/widgets/coach/debt_survival_widget.dart';

CoachProfile _heavyDebtProfile() => CoachProfile(
      firstName: 'Sam',
      birthYear: 1990,
      canton: 'GE',
      salaireBrutMensuel: 7000,
      dettes: const DetteProfile(
        creditConsommation: 40000,
        mensualiteCreditConso: 900,
        leasing: 30000,
        mensualiteLeasing: 600,
      ),
      goalA: GoalA(
        type: GoalAType.retraite,
        targetDate: DateTime(2045),
        label: 'Retraite',
      ),
    );

Widget _wrap(CoachProfileProvider provider) =>
    ChangeNotifierProvider<CoachProfileProvider>.value(
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
        home: RepaymentScreen(),
      ),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
      'Σ minimums (1500) > budget (800) -> la note budget effectif est rendue',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final provider = CoachProfileProvider();
    provider.updateProfile(_heavyDebtProfile());
    await tester.pumpWidget(_wrap(provider));
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.textContaining('mensualités minimales totalisent', skipOffstage: false),
      findsOneWidget,
      reason: 'le plan calcule sur 1500 (Σmin), pas 800 — le dire',
    );
    expect(
      find.textContaining("1'500", skipOffstage: false),
      findsWidgets,
      reason: 'le montant effectif est affiché',
    );
  });

  testWidgets('double notify -> AUCUNE duplication de dettes (idempotence)',
      (tester) async {
    // Panel -g5v : sans clear, chaque notifyListeners ré-appendait les
    // mêmes dettes (Σmin doublée -> tous les chiffres faux).
    tester.view.physicalSize = const Size(1080, 2800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final provider = CoachProfileProvider();
    provider.updateProfile(_heavyDebtProfile());
    await tester.pumpWidget(_wrap(provider));
    await tester.pump(const Duration(milliseconds: 400));

    provider.notifyListeners(); // re-notify même profil
    await tester.pump(const Duration(milliseconds: 400));

    final survival = tester.widget<DebtSurvivalWidget>(
        find.byType(DebtSurvivalWidget, skipOffstage: false));
    expect(survival.totalDebt, 70000,
        reason: '40k + 30k une seule fois — pas 140k dupliqué');
  });

  testWidgets('marge survie = budget effectif − Σmin (placeholder, jamais négatif fictif)',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final provider = CoachProfileProvider();
    provider.updateProfile(_heavyDebtProfile());
    await tester.pumpWidget(_wrap(provider));
    await tester.pump(const Duration(milliseconds: 400));

    final survival = tester.widget<DebtSurvivalWidget>(
        find.byType(DebtSurvivalWidget, skipOffstage: false));
    // Budget placeholder 800, Σmin 1500 -> effectif 1500 -> marge 0
    // (pas −700 fictif : l'utilisateur n'a rien saisi).
    expect(survival.monthlyMargin, 0,
        reason: 'panel -g5v : le mode critique ne se déclenche pas sur un '
            'placeholder ; le déficit réel exige un budget SAISI');
  });

  testWidgets('éditer un TAUX seul ne déclenche pas le déficit du placeholder',
      (tester) async {
    // Review #992 : _hasUserInteracted global aurait fait basculer la
    // marge sur 800 − 1500 = −700 alors que le budget reste le défaut.
    tester.view.physicalSize = const Size(1080, 2800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final provider = CoachProfileProvider();
    provider.updateProfile(_heavyDebtProfile());
    await tester.pumpWidget(_wrap(provider));
    await tester.pump(const Duration(milliseconds: 400));

    final state = tester.state(find.byType(RepaymentScreen)) as dynamic;
    // simule une interaction non-budget (le gate hydratation se ferme,
    // mais _budgetTouched reste false)
    state.setState(() {});

    final survival = tester.widget<DebtSurvivalWidget>(
        find.byType(DebtSurvivalWidget, skipOffstage: false));
    expect(survival.monthlyMargin, greaterThanOrEqualTo(0),
        reason: 'le déficit réel exige un BUDGET saisi (_budgetTouched), '
            'pas n\'importe quelle interaction');
  });

  testWidgets('dette supprimée + notify -> ne ressuscite pas', (tester) async {
    tester.view.physicalSize = const Size(1080, 2800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final provider = CoachProfileProvider();
    provider.updateProfile(_heavyDebtProfile());
    await tester.pumpWidget(_wrap(provider));
    await tester.pump(const Duration(milliseconds: 400));

    // Supprime la première dette via son icône delete
    final deleteIcons = find.byIcon(Icons.close, skipOffstage: false);
    if (deleteIcons.evaluate().isEmpty) {
      // autre icône possible
      final alt = find.byIcon(Icons.delete_outline, skipOffstage: false);
      expect(alt, findsWidgets, reason: 'icône de suppression trouvable');
      await tester.tap(alt.first, warnIfMissed: false);
    } else {
      await tester.tap(deleteIcons.first, warnIfMissed: false);
    }
    await tester.pump(const Duration(milliseconds: 200));

    provider.notifyListeners();
    await tester.pump(const Duration(milliseconds: 400));

    final survival = tester.widget<DebtSurvivalWidget>(
        find.byType(DebtSurvivalWidget, skipOffstage: false));
    expect(survival.totalDebt, lessThan(70000),
        reason: 'review #992 : la dette supprimée ne doit pas ressusciter '
            'au prochain notify (gate interaction sur delete)');
  });

  testWidgets('profil chargé APRÈS la 1re frame -> ré-hydratation',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final provider = CoachProfileProvider();
    await tester.pumpWidget(_wrap(provider)); // écran monté AVANT le profil
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining("40'000", skipOffstage: false), findsNothing,
        reason: 'pas encore de profil : état vide');

    provider.updateProfile(_heavyDebtProfile()); // chargement tardif
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining("40'000", skipOffstage: false), findsWidgets,
        reason: 'beads -g5v (4) : le listener ré-hydrate les dettes '
            'du profil chargé après la première frame');
  });
}
