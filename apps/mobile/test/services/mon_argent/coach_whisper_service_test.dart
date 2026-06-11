import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/domain/budget/budget_inputs.dart';
import 'package:mint_mobile/domain/budget/budget_plan.dart';
import 'package:mint_mobile/models/budget_snapshot.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/mon_argent/coach_whisper_service.dart';
import 'package:mint_mobile/services/mon_argent/patrimoine_aggregator.dart';

void main() {
  group('CoachWhisperService', () {
    test('does not suggest 3a from clamped available when free cash is low',
        () {
      const inputs = BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 6000,
        housingCost: 2000,
        debtPayments: 0,
        taxProvision: 600,
        healthInsurance: 400,
      );
      const plan = BudgetPlan(
        available: 3000,
        variables: 100,
        future: 2900,
        stopRuleTriggered: false,
      );

      final whisper = CoachWhisperService.evaluate(
        budgetInputs: inputs,
        budgetPlan: plan,
        patrimoine: const PatrimoineSummary(
          epargneLiquide: PatrimoineField(value: 30000, source: 'userInput'),
          investissements: PatrimoineField(value: 10000, source: 'userInput'),
          dettes: PatrimoineField(value: 0, source: 'userInput'),
        ),
        profile: _profile(),
      );

      expect(whisper, isNull);
    });

    test('suggests 3a from signed monthly free cash when genuinely high', () {
      const inputs = BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 6000,
        housingCost: 2000,
        debtPayments: 0,
        taxProvision: 600,
        healthInsurance: 400,
      );
      const plan = BudgetPlan(
        available: 3000,
        variables: 2500,
        future: 500,
        stopRuleTriggered: false,
      );

      final whisper = CoachWhisperService.evaluate(
        budgetInputs: inputs,
        budgetPlan: plan,
        patrimoine: const PatrimoineSummary(
          epargneLiquide: PatrimoineField(value: 30000, source: 'userInput'),
          investissements: PatrimoineField(value: 10000, source: 'userInput'),
          dettes: PatrimoineField(value: 0, source: 'userInput'),
        ),
        profile: _profile(),
        now: DateTime(2026, 1, 15), // deterministic proration (12 months left)
      );

      // Signed monthly free is high \u2192 the clamp governs at the statutory
      // remaining ceiling / 12 = 7258/12 \u2248 604.83 \u2192 605. The raw round(free
      // \u00d7 0.25) = 625 is intentionally NO LONGER suggested (D10 clamp).
      expect(whisper, 'Bon mois. Tu pourrais verser 605\u00a0CHF en 3a.');
    });

    test('does not suggest 3a under material consumer debt priority', () {
      const inputs = BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 6000,
        housingCost: 2000,
        debtPayments: 900,
        taxProvision: 600,
        healthInsurance: 400,
      );
      const plan = BudgetPlan(
        available: 2100,
        variables: 1600,
        future: 500,
        stopRuleTriggered: false,
      );

      final whisper = CoachWhisperService.evaluate(
        budgetInputs: inputs,
        budgetPlan: plan,
        patrimoine: const PatrimoineSummary(
          epargneLiquide: PatrimoineField(value: 30000, source: 'userInput'),
          investissements: PatrimoineField(value: 10000, source: 'userInput'),
          dettes: PatrimoineField(value: 220000, source: 'userInput'),
        ),
        profile: _profile(
          dettes: const DetteProfile(
            creditConsommation: 220000,
            mensualiteCreditConso: 900,
          ),
        ),
      );

      expect(whisper, isNull);
    });

    test('keeps 3a whisper for mortgage-only profile', () {
      const inputs = BudgetInputs(
        payFrequency: PayFrequency.monthly,
        netIncome: 6000,
        housingCost: 2000,
        debtPayments: 0,
        taxProvision: 600,
        healthInsurance: 400,
      );
      const plan = BudgetPlan(
        available: 3000,
        variables: 2500,
        future: 500,
        stopRuleTriggered: false,
      );

      final whisper = CoachWhisperService.evaluate(
        budgetInputs: inputs,
        budgetPlan: plan,
        patrimoine: const PatrimoineSummary(
          epargneLiquide: PatrimoineField(value: 30000, source: 'userInput'),
          investissements: PatrimoineField(value: 10000, source: 'userInput'),
          dettes: PatrimoineField(value: 520000, source: 'userInput'),
        ),
        profile: _profile(
          dettes: const DetteProfile(
            hypotheque: 520000,
            mensualiteHypotheque: 1800,
          ),
        ),
        now: DateTime(2026, 1, 15),
      );

      // High signed monthly free \u2192 the clamp governs at the statutory remaining
      // ceiling / 12 = 7258/12 \u2248 604.83 \u2192 605. The mortgage (non-consumer debt)
      // does NOT suppress the whisper; the D10 clamp simply caps the figure.
      expect(whisper, 'Bon mois. Tu pourrais verser 605\u00a0CHF en 3a.');
    });

    // D10 device regression (FAIL #1): married swiss profile, monthlyFree 6164.
    // Pre-fix the whisper computed round(6164 * 0.25) = 1541 CHF (\u00d712 = 18'492
    // \u2248 2.55\u00d7 the 7258 statutory ceiling). The whisper MUST route through the
    // canonical clamp (BudgetLivingEngine.cappedMonthly3aSuggestion) like the
    // LLM-context path does \u2014 never the raw free margin.
    test('D10 \u2014 high free margin (6164) is clamped to remaining 3a ceiling, '
        'never 1541', () {
      // Snapshot carries the exact device margin (6164/mois).
      const snapshot = BudgetSnapshot(
        present: PresentBudget(
          monthlyNet: 7000,
          monthlyCharges: 836,
          monthlySavings: 0,
          monthlyFree: 6164,
        ),
        capImpacts: [],
        stage: BudgetStage.presentOnly,
        confidenceScore: 80,
      );

      final whisper = CoachWhisperService.evaluate(
        budgetSnapshot: snapshot,
        budgetInputs: null,
        budgetPlan: null,
        patrimoine: const PatrimoineSummary(
          epargneLiquide: PatrimoineField(value: 30000, source: 'userInput'),
          investissements: PatrimoineField(value: 10000, source: 'userInput'),
          dettes: PatrimoineField(value: 0, source: 'userInput'),
        ),
        profile: _profile(),
        now: DateTime(2026, 1, 15), // 12 months remaining \u2192 7258/12 \u2248 604.83
      );

      // The 1541 device illogism must be gone. Clamp \u2192 round(604.83) = 605.
      expect(whisper, isNotNull);
      expect(whisper, isNot(contains('1541')),
          reason: 'D10 device illogism: raw free margin must never be suggested');
      expect(whisper, 'Bon mois. Tu pourrais verser 605\u00a0CHF en 3a.');
    });

    // D10 corollary: US person (FATCA, plafond 0) gets NO 3a whisper at all \u2014
    // a 0-CHF suggestion would be a dissonant illogism.
    test('D10 \u2014 US person (cannot contribute 3a) gets no 3a whisper', () {
      const snapshot = BudgetSnapshot(
        present: PresentBudget(
          monthlyNet: 7000,
          monthlyCharges: 836,
          monthlySavings: 0,
          monthlyFree: 6164,
        ),
        capImpacts: [],
        stage: BudgetStage.presentOnly,
        confidenceScore: 80,
      );

      final whisper = CoachWhisperService.evaluate(
        budgetSnapshot: snapshot,
        budgetInputs: null,
        budgetPlan: null,
        patrimoine: const PatrimoineSummary(
          epargneLiquide: PatrimoineField(value: 30000, source: 'userInput'),
          investissements: PatrimoineField(value: 10000, source: 'userInput'),
          dettes: PatrimoineField(value: 0, source: 'userInput'),
        ),
        profile: _profile(usTaxPerson: true, nationality: 'US'),
        now: DateTime(2026, 1, 15),
      );

      // No 3a whisper. Falls through to silence (no other rule matches here).
      expect(whisper, isNull);
    });
  });
}

CoachProfile _profile({
  DetteProfile dettes = const DetteProfile(),
  bool usTaxPerson = false,
  String? nationality,
}) {
  return CoachProfile(
    birthYear: 1990,
    canton: 'VD',
    salaireBrutMensuel: 6000,
    dettes: dettes,
    usTaxPerson: usTaxPerson,
    nationality: nationality,
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2055),
      label: 'Retraite',
    ),
  );
}
