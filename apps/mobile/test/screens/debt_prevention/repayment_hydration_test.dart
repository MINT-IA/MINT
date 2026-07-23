// ────────────────────────────────────────────────────────────
//  REPAYMENT — hydratation profil, zéro dette fictive (ILLOG-01)
//
//  beads MINT_nosync-64r (audit T05-F15) : l'écran embarquait deux dettes
//  MOCK (Credit conso 15'000 @ 9.9 %, Leasing auto 8'000 @ 4.5 %),
//  _budgetMensuel=800 et monthlyIncome=6000 en dur ; initState ne lisait
//  jamais profile.dettes. Le DebtSurvivalWidget rendait « libéré/critique »
//  sur du fictif indiscernable du réel.
//
//  Verrouille : (1) profil AVEC dettes -> liste hydratée depuis
//  profile.dettes (noms ARB, montants réels) + widget survie visible ;
//  (2) profil SANS dettes -> AUCUNE dette fictive, widget survie absent,
//  état vide explicite affiché.
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

CoachProfile _profile({DetteProfile dettes = const DetteProfile()}) =>
    CoachProfile(
      firstName: 'Sam',
      birthYear: 1990,
      canton: 'GE',
      salaireBrutMensuel: 7800,
      dettes: dettes,
      goalA: GoalA(
        type: GoalAType.retraite,
        targetDate: DateTime(2045),
        label: 'Retraite',
      ),
    );

Widget _app(CoachProfile profile) {
  final provider = CoachProfileProvider();
  provider.updateProfile(profile);
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
      home: RepaymentScreen(),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('profil avec dettes -> hydratation réelle + widget survie',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(_app(_profile(
      dettes: const DetteProfile(
        creditConsommation: 12000,
        tauxCreditConso: 8.5,
        mensualiteCreditConso: 280,
        leasing: 9000,
        mensualiteLeasing: 310,
      ),
    )));
    await tester.pump(const Duration(milliseconds: 400));

    // Les dettes du PROFIL sont affichées (noms ARB), pas la fiction.
    expect(find.text('Crédit conso', skipOffstage: false), findsOneWidget);
    expect(find.text('Leasing', skipOffstage: false), findsOneWidget);
    expect(find.text('Credit conso', skipOffstage: false), findsNothing,
        reason: 'l\'ancien nom fictif hardcodé ne doit plus exister');
    expect(find.text('Leasing auto', skipOffstage: false), findsNothing);
    // Montants hydratés depuis le profil (12'000 apparaît formaté quelque
    // part : champ, total ou chiffre choc).
    expect(find.textContaining("12'000", skipOffstage: false), findsWidgets,
        reason: 'montant crédit conso du profil attendu');
    expect(
        find.byType(DebtSurvivalWidget, skipOffstage: false), findsOneWidget);
  });

  testWidgets(
      'profil sans dettes -> zéro fiction, pas de widget survie, état vide',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(_app(_profile()));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Credit conso', skipOffstage: false), findsNothing,
        reason: 'aucune dette fictive (ILLOG-01)');
    expect(find.text('Leasing auto', skipOffstage: false), findsNothing);
    expect(find.byType(DebtSurvivalWidget, skipOffstage: false), findsNothing,
        reason: 'pas de statut « libéré/critique » sur du vide');
    final l10n = await S.delegate.load(const Locale('fr'));
    expect(find.text(l10n.repaymentEmptyState, skipOffstage: false),
        findsWidgets, reason: 'état vide explicite attendu');
  });
}
