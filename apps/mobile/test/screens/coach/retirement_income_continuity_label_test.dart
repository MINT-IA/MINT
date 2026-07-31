import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/screens/coach/retirement_dashboard_screen.dart';
import 'package:mint_mobile/widgets/coach/retirement_hero_zone.dart';

// ────────────────────────────────────────────────────────────
//  P2 #1144 — Honest label: income CONTINUITY vs replacement rate.
//
//  A retiree already in régime has no pre-retirement salary on file, so the
//  forecaster falls back to their own retirement income as the basis → the
//  « taux de remplacement » reads ~100% by construction. That is a CONTINUITY
//  indicator, NOT a forward replacement rate. The label must say so.
// ────────────────────────────────────────────────────────────

GoalA _retirementGoal() => GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2020, 12, 31),
      label: 'Retraite',
    );

CoachProfile _retiree({double salaireBrutMensuel = 0}) => CoachProfile(
      firstName: 'René',
      birthYear: 1955,
      canton: 'VD',
      salaireBrutMensuel: salaireBrutMensuel,
      employmentStatus: 'retraite',
      goalA: _retirementGoal(),
    );

CoachProfile _active() => CoachProfile(
      firstName: 'Marc',
      birthYear: 1985,
      canton: 'GE',
      salaireBrutMensuel: 8000,
      employmentStatus: 'salarie',
      goalA: _retirementGoal(),
    );

Widget _wrap(Widget child) => MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(child: child),
      ),
    );

// RetirementHeroZone packs a lot into a spaceBetween label Row; the default
// 800x600 test surface overflows it (the pre-existing reason the screen's
// profile tests were removed). A generous surface isolates the label swap.
void _largeSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1400, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  group('retirementIncomeIsContinuityBasis (pure predicate)', () {
    test('retiree in régime with zero salary and positive projection → true',
        () {
      expect(
        retirementIncomeIsContinuityBasis(
          profile: _retiree(),
          projectedAnnualRetirementIncome: 30000,
        ),
        isTrue,
      );
    });

    test('active salaried person → false (real forward replacement rate)', () {
      expect(
        retirementIncomeIsContinuityBasis(
          profile: _active(),
          projectedAnnualRetirementIncome: 30000,
        ),
        isFalse,
      );
    });

    test('retiree but no projected income yet → false (no continuity basis)',
        () {
      expect(
        retirementIncomeIsContinuityBasis(
          profile: _retiree(),
          projectedAnnualRetirementIncome: 0,
        ),
        isFalse,
      );
    });

    test('retiree who still declares a salary → false (has a real basis)', () {
      expect(
        retirementIncomeIsContinuityBasis(
          profile: _retiree(salaireBrutMensuel: 5000),
          projectedAnnualRetirementIncome: 30000,
        ),
        isFalse,
      );
    });
  });

  group('RetirementHeroZone — honest label swap', () {
    testWidgets('continuity basis (retiree) renders « Continuité de ton revenu »'
        ' and NOT « Taux de remplacement »', (tester) async {
      _largeSurface(tester);
      await tester.pumpWidget(_wrap(const RetirementHeroZone(
        monthlyIncome: 3000,
        replacementRate: 100,
        isContinuityBasis: true,
        decomposition: {'avs': 24000, 'lpp': 12000},
        monthlyPrudent: 2800,
        monthlyOptimiste: 3200,
        confidenceScore: 80,
        currentAge: 68,
        retirementAge: 65,
      )));
      await tester.pump();

      expect(find.textContaining('Continuité de ton revenu'), findsWidgets);
      expect(find.textContaining('Taux de remplacement'), findsNothing);
      // Honest context line — not a « bon niveau » replacement praise.
      expect(find.textContaining('continuité de ton revenu'), findsWidgets);
    });

    testWidgets('active worker still renders « Taux de remplacement »',
        (tester) async {
      _largeSurface(tester);
      await tester.pumpWidget(_wrap(const RetirementHeroZone(
        monthlyIncome: 5000,
        replacementRate: 65,
        isContinuityBasis: false,
        decomposition: {'avs': 30000, 'lpp': 24000},
        monthlyPrudent: 4600,
        monthlyOptimiste: 5400,
        confidenceScore: 80,
        currentAge: 68,
        retirementAge: 65,
      )));
      await tester.pump();

      expect(find.textContaining('Taux de remplacement'), findsWidgets);
      expect(find.textContaining('Continuité de ton revenu'), findsNothing);
    });
  });
}
