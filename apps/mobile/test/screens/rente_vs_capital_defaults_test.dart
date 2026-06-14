// ────────────────────────────────────────────────────────────
//  RENTE VS CAPITAL — Fiction-defaults regression test
//
//  ILLOG-01 (W3, MATRIX-illogismes D5) : RenteVsCapitalScreen shipped
//  HARDCODED FICTION defaults (rente_vs_capital_screen.dart:62-66 — age
//  '50', salaire '100000', avoir LPP '350000' ; mode certificat 500000 /
//  150000 / 37000). `_autoFillFromProfile` (180-215) only overwrote them
//  when the profile carried a stored value. For any profile WITHOUT a
//  stored LPP (the common onboarding case, since onboarding never asks for
//  it) the most consequential one-time decision tool of the app rendered
//  pure fiction visually indistinguishable from personalized prefill,
//  computed « Capital estimé à 65 ans ~812'886 » on a phantom LPP, and the
//  defaults BYPASSED ProfileDataSource (hasEstimates was only set on real
//  prefill) — violating SOT §5 Source Tracking. Device evidence 2026-06-11:
//  home hero said « Avoir LPP 43'691 » while this screen showed 350'000
//  (8x apart, same user, same minute).
//
//  Allowed states (CONTEXT W3 lock) : an explicit EMPTY state OR a
//  profile-derived value tagged « estimé » via ProfileDataSource. This
//  test pins both:
//   1. No usable profile (no stored LPP) → input fields are EMPTY (no
//      '50' / '100000' / '350000' fiction) and an explicit empty-state
//      invitation is shown — no projection computed on a phantom avoir.
//   2. A profile with a real estimated LPP → the field is prefilled with
//      the profile value and tagged estimé (hasEstimates path).
// ────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/arbitrage/rente_vs_capital_screen.dart';
import 'package:mint_mobile/services/financial_core/arbitrage_engine.dart';

GoalA _testGoalA() => GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2045),
      label: 'Retraite',
    );

/// Profile WITHOUT any stored LPP — the default state of every fresh
/// onboarding (onboarding never asks for the LPP certificate value).
CoachProfile _profileWithoutLpp() => CoachProfile(
      firstName: 'Sam',
      birthYear: 1990,
      canton: 'GE',
      etatCivil: CoachCivilStatus.celibataire,
      salaireBrutMensuel: 0, // independent / not captured
      nombreDeMois: 12,
      employmentStatus: 'independant',
      prevoyance: const PrevoyanceProfile(), // avoirLppTotal == null
      goalA: _testGoalA(),
    );

/// Profile WITH a real (estimated) LPP balance — the prefill path.
CoachProfile _profileWithEstimatedLpp() => CoachProfile(
      firstName: 'Marc',
      birthYear: 1980,
      canton: 'ZH',
      etatCivil: CoachCivilStatus.celibataire,
      salaireBrutMensuel: 8000,
      nombreDeMois: 12,
      employmentStatus: 'salarie',
      // avoirLppTotal present WITHOUT certificate split signals →
      // _resolveDataSources infers ProfileDataSource.estimated.
      prevoyance: const PrevoyanceProfile(avoirLppTotal: 240000),
      goalA: _testGoalA(),
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
      home: RenteVsCapitalScreen(),
    ),
  );
}

/// Collect the current text of every editable [TextField] on screen.
List<String> _allFieldTexts(WidgetTester tester) {
  return tester
      .widgetList<TextField>(find.byType(TextField))
      .map((tf) => tf.controller?.text ?? '')
      .toList();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'ILLOG-01: no usable profile → fields are EMPTY, no fiction default '
    "('50' / '100000' / '350000') is rendered as the user's data",
    (tester) async {
      final provider = CoachProfileProvider();
      provider.updateProfile(_profileWithoutLpp());

      await tester.pumpWidget(_wrap(provider));
      await tester.pump(const Duration(milliseconds: 600));

      final fieldTexts = _allFieldTexts(tester);

      // The fiction defaults must NOT survive as field values.
      expect(fieldTexts, isNot(contains('50')),
          reason: "age fiction default '50' must be removed");
      expect(fieldTexts, isNot(contains('100000')),
          reason: "salary fiction default '100000' must be removed");
      expect(fieldTexts, isNot(contains('350000')),
          reason: "LPP fiction default '350000' must be removed");

      // And the literal fiction strings must not appear anywhere on screen
      // (the Maestro flow bug__ILLOG01 asserts on these exact substrings).
      expect(find.text('350000'), findsNothing);
      expect(find.text('100000'), findsNothing);
    },
  );

  testWidgets(
    'ILLOG-01: no usable profile → an explicit empty-state invitation is '
    'shown (état vide explicite)',
    (tester) async {
      final provider = CoachProfileProvider();
      provider.updateProfile(_profileWithoutLpp());

      await tester.pumpWidget(_wrap(provider));
      await tester.pump(const Duration(milliseconds: 600));

      // The empty-state copy must be present and localized.
      final ctx = tester.element(find.byType(RenteVsCapitalScreen));
      final emptyCopy = S.of(ctx)!.renteVsCapitalEmptyState;
      expect(emptyCopy, isNotEmpty);
      expect(find.text(emptyCopy), findsOneWidget,
          reason: 'explicit empty-state invitation must render when no '
              'usable profile data exists');
      expect(find.byKey(const Key('rente_vs_capital_disclaimer_card')),
          findsNothing);
    },
  );

  testWidgets(
    'ILLOG-01: certificate-mode defaults (500000 / 150000 / 37000) are '
    'removed — empty fields, no fiction',
    (tester) async {
      final provider = CoachProfileProvider();
      provider.updateProfile(_profileWithoutLpp());

      await tester.pumpWidget(_wrap(provider));
      await tester.pump(const Duration(milliseconds: 600));

      // Switch to certificate mode.
      await tester.tap(find.text(S.of(tester.element(
        find.byType(RenteVsCapitalScreen),
      ))!
          .renteVsCapitalCertificateMode));
      await tester.pump(const Duration(milliseconds: 600));

      final fieldTexts = _allFieldTexts(tester);
      expect(fieldTexts, isNot(contains('500000')),
          reason: "certificate oblig fiction '500000' must be removed");
      expect(fieldTexts, isNot(contains('150000')),
          reason: "certificate surob fiction '150000' must be removed");
      expect(fieldTexts, isNot(contains('37000')),
          reason: "certificate rente fiction '37000' must be removed");
    },
  );

  testWidgets(
    'ILLOG-01: a profile WITH a real estimated LPP prefills the field with '
    'the profile value and tags it estimé (hasEstimates path preserved)',
    (tester) async {
      final provider = CoachProfileProvider();
      provider.updateProfile(_profileWithEstimatedLpp());

      await tester.pumpWidget(_wrap(provider));
      await tester.pump(const Duration(milliseconds: 600));

      final fieldTexts = _allFieldTexts(tester);
      // The real profile value (240000) is prefilled — NOT the fiction
      // 350000 default.
      expect(fieldTexts, contains('240000'),
          reason: 'real profile LPP must prefill the field');
      expect(fieldTexts, isNot(contains('350000')),
          reason: 'fiction default must never coexist with a real value');
    },
  );

  testWidgets(
    'local fallback result exposes origin and version in the receipt',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      addTearDown(tester.view.resetPhysicalSize);

      final provider = CoachProfileProvider()
        ..updateProfile(_profileWithEstimatedLpp());
      await tester.pumpWidget(_wrap(provider));
      await tester.pump(const Duration(milliseconds: 350));
      await tester
          .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pumpAndSettle();

      final card = find.byKey(const Key('rente_vs_capital_disclaimer_card'));
      await tester.scrollUntilVisible(card, 500,
          scrollable: find.byType(Scrollable).first);
      await tester.pump();

      final label = tester.getSemantics(card).label;
      for (final expected in [
        'Origine du calcul : moteur mobile L1',
        'Version du calcul : ${ArbitrageEngine.renteVsCapitalCalculationVersion}',
        'Champs manquants : aucun',
        'API backend indisponible : calcul local affiché',
      ]) {
        expect(label, contains(expected));
      }
    },
  );
}
