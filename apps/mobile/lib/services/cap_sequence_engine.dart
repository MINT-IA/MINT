import 'package:mint_mobile/l10n/app_localizations.dart' show S;
import 'package:mint_mobile/models/cap_sequence.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/cap_memory_store.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';

// ────────────────────────────────────────────────────────────────
//  CAP SEQUENCE ENGINE
// ────────────────────────────────────────────────────────────────
//
//  Pure function. No side effects. No ML.
//
//  Job: "Given what the user has done and what we know about them,
//        show a coherent multi-step plan toward their declared goal."
//
//  Five goal families:
//    - retirement_choice  → 10 steps
//    - budget_overview    → 6 steps
//    - housing_purchase   → 7 steps
//    - first_job          → 5 steps
//    - new_job            → 5 steps
//
//  Completion detection uses memory.completedActions (string IDs).
//  Profile field presence is used as a secondary signal.
//
//  ARB keys follow the pattern:
//    capStep{Goal}{NN}Title / capStep{Goal}{NN}Desc
//  where {Goal} = Retirement | Budget | Housing | FirstJob | NewJob
//  and {NN} = 01..10
//
//  ARCH NOTE — intentTag values in CapStep:
//  The [CapStep.intentTag] field stores GoRouter route strings (e.g.
//  '/pilier-3a', '/rente-vs-capital'), NOT ScreenRegistry intent tags
//  (e.g. 'simulator_3a', 'retirement_choice'). This is intentional:
//  CapSequenceCard uses `context.go(step.intentTag!)` for direct navigation,
//  which requires the GoRouter route path. ScreenRegistry intent tags are used
//  by the CoachOrchestrator / RoutePlanner layer only. The field name is
//  misleading — a future refactor should rename it to `route` and add a
//  separate optional `intentTag` for coach routing context if needed.
//
//  Spec: docs/MINT_CAP_ENGINE_SPEC.md §14
// ────────────────────────────────────────────────────────────────

/// Goal intent tag constants — must match values used by PulseScreen.
const _kGoalRetirement = 'retirement_choice';
const _kGoalBudget = 'budget_overview';
const _kGoalHousing = 'housing_purchase';
const _kGoalFirstJob = 'first_job';
const _kGoalNewJob = 'new_job';

class CapSequenceEngine {
  CapSequenceEngine._();

  // ── PUBLIC API ────────────────────────────────────────────────

  /// Build a [CapSequence] for the user's current goal.
  ///
  /// Pure function — no side effects.
  ///
  /// [goalIntentTag] should be one of the three known goal types
  /// (see constants above). An unknown tag returns an empty sequence.
  ///
  /// [l] is required to validate ARB key availability in tests.
  /// The widget resolves labels via `S.of(context)` at render time —
  /// the engine only stores the ARB key strings.
  static CapSequence build({
    required CoachProfile profile,
    required CapMemory memory,
    required String goalIntentTag,
    // ignore: unused_element
    required S l,
  }) {
    return switch (goalIntentTag) {
      _kGoalRetirement => _buildRetirement(profile, memory),
      _kGoalBudget => _buildBudget(profile, memory),
      _kGoalHousing => _buildHousing(profile, memory),
      _kGoalFirstJob => _buildFirstJob(profile, memory),
      _kGoalNewJob => _buildNewJob(profile, memory),
      _ => CapSequence.fromSteps(goalId: goalIntentTag, steps: const []),
    };
  }

  // ── RETIREMENT SEQUENCE ───────────────────────────────────────

  /// 10-step retirement planning sequence.
  static CapSequence _buildRetirement(CoachProfile profile, CapMemory memory) {
    final done = memory.completedActions;
    final prev = profile.prevoyance;

    // Step completion signals (profile + memory based).
    final hasSalary = profile.salaireBrutMensuel > 0;
    final hasAge = profile.birthYear > 0;
    final hasLpp = (prev.avoirLppTotal ?? 0) > 0 ||
        done.contains('lpp_verified') ||
        done.contains('lpp_scan');
    final hasReplacementRate = done.contains('replacement_rate') ||
        done.contains('rente_vs_capital') ||
        done.contains('replacement_rate_computed');
    final has3aCap = done.contains('pillar_3a') ||
        done.contains('3a_sim') ||
        done.contains('3a_completed');
    final hasRachat = done.contains('lpp_buyback') ||
        done.contains('rachat_lpp') ||
        done.contains('rachat_sim');
    final hasRenteCapital = done.contains('rente_vs_capital') ||
        done.contains('rente_capital_visited');
    final hasDecaissement = done.contains('decaissement') ||
        done.contains('decaissement_visited');
    final hasFiscal = done.contains('fiscal_cap') ||
        done.contains('fiscal_optimisation') ||
        done.contains('fiscal_completed');

    final steps = <CapStep>[
      CapStep(
        id: 'ret_01_salary',
        order: 1,
        titleKey: 'capStepRetirement01Title',
        descriptionKey: 'capStepRetirement01Desc',
        status: hasSalary ? CapStepStatus.completed : CapStepStatus.upcoming,
        intentTag: '/profile',
        impactEstimate: null,
      ),
      CapStep(
        id: 'ret_02_avs',
        order: 2,
        titleKey: 'capStepRetirement02Title',
        descriptionKey: 'capStepRetirement02Desc',
        status: hasAge ? CapStepStatus.completed : CapStepStatus.upcoming,
        intentTag: '/retraite',
        impactEstimate: _estimateAvsMonthly(profile),
      ),
      CapStep(
        id: 'ret_03_lpp',
        order: 3,
        titleKey: 'capStepRetirement03Title',
        descriptionKey: 'capStepRetirement03Desc',
        status: hasLpp ? CapStepStatus.completed : CapStepStatus.upcoming,
        intentTag: '/rachat-lpp',
        impactEstimate: _estimateLppMonthly(profile),
      ),
      CapStep(
        id: 'ret_04_rate',
        order: 4,
        titleKey: 'capStepRetirement04Title',
        descriptionKey: 'capStepRetirement04Desc',
        // Requires salary + LPP to compute meaningfully.
        status: hasReplacementRate
            ? CapStepStatus.completed
            : (hasSalary && hasLpp)
                ? CapStepStatus.upcoming
                : CapStepStatus.blocked,
        intentTag: '/rente-vs-capital',
        impactEstimate: null,
      ),
      CapStep(
        id: 'ret_05_3a',
        order: 5,
        titleKey: 'capStepRetirement05Title',
        descriptionKey: 'capStepRetirement05Desc',
        status: has3aCap
            ? CapStepStatus.completed
            : hasSalary
                ? CapStepStatus.upcoming
                : CapStepStatus.blocked,
        intentTag: '/pilier-3a',
        impactEstimate: _estimate3aImpact(profile),
      ),
      CapStep(
        id: 'ret_06_rachat',
        order: 6,
        titleKey: 'capStepRetirement06Title',
        descriptionKey: 'capStepRetirement06Desc',
        status: hasRachat
            ? CapStepStatus.completed
            : (prev.rachatMaximum ?? 0) > 0
                ? CapStepStatus.upcoming
                : CapStepStatus.blocked,
        intentTag: '/rachat-lpp',
        impactEstimate: _estimateRachatImpact(profile),
      ),
      CapStep(
        id: 'ret_07_rente_capital',
        order: 7,
        titleKey: 'capStepRetirement07Title',
        descriptionKey: 'capStepRetirement07Desc',
        status: hasRenteCapital
            ? CapStepStatus.completed
            : hasLpp
                ? CapStepStatus.upcoming
                : CapStepStatus.blocked,
        intentTag: '/rente-vs-capital',
        impactEstimate: null,
      ),
      CapStep(
        id: 'ret_08_decaissement',
        order: 8,
        titleKey: 'capStepRetirement08Title',
        descriptionKey: 'capStepRetirement08Desc',
        status: hasDecaissement
            ? CapStepStatus.completed
            : hasRenteCapital
                ? CapStepStatus.upcoming
                : CapStepStatus.blocked,
        intentTag: '/retirement',
        impactEstimate: null,
      ),
      CapStep(
        id: 'ret_09_fiscal',
        order: 9,
        titleKey: 'capStepRetirement09Title',
        descriptionKey: 'capStepRetirement09Desc',
        status: hasFiscal
            ? CapStepStatus.completed
            : hasSalary
                ? CapStepStatus.upcoming
                : CapStepStatus.blocked,
        intentTag: '/fiscal',
        impactEstimate: null,
      ),
      CapStep(
        id: 'ret_10_specialist',
        order: 10,
        titleKey: 'capStepRetirement10Title',
        descriptionKey: 'capStepRetirement10Desc',
        // Specialist step is always upcoming until manually marked.
        status: done.contains('specialist_consulted')
            ? CapStepStatus.completed
            : CapStepStatus.upcoming,
        intentTag: null, // Opens coach
        impactEstimate: null,
      ),
    ];

    return CapSequence.fromSteps(goalId: _kGoalRetirement, steps: steps);
  }

  // ── BUDGET SEQUENCE ───────────────────────────────────────────

  /// 6-step budget mastery sequence.
  static CapSequence _buildBudget(CoachProfile profile, CapMemory memory) {
    final done = memory.completedActions;

    final hasIncome = profile.salaireBrutMensuel > 0;
    final hasCharges = profile.depenses.loyer > 0 ||
        profile.depenses.assuranceMaladie > 0 ||
        done.contains('charges_entered');
    final hasBudget = done.contains('budget') ||
        done.contains('budget_computed') ||
        done.contains('budget_overview');
    final hasBudgetDeep = done.contains('budget_deep') ||
        done.contains('budget_savings_identified');
    final hasEpargne = profile.patrimoine.epargneLiquide > 0 ||
        done.contains('epargne_precaution');
    final has3a = done.contains('pillar_3a') ||
        done.contains('3a_completed') ||
        profile.prevoyance.totalEpargne3a > 0;

    final steps = <CapStep>[
      CapStep(
        id: 'bud_01_income',
        order: 1,
        titleKey: 'capStepBudget01Title',
        descriptionKey: 'capStepBudget01Desc',
        status: hasIncome ? CapStepStatus.completed : CapStepStatus.upcoming,
        intentTag: '/profile',
        impactEstimate: null,
      ),
      CapStep(
        id: 'bud_02_charges',
        order: 2,
        titleKey: 'capStepBudget02Title',
        descriptionKey: 'capStepBudget02Desc',
        status: hasCharges
            ? CapStepStatus.completed
            : hasIncome
                ? CapStepStatus.upcoming
                : CapStepStatus.blocked,
        intentTag: '/budget',
        impactEstimate: null,
      ),
      CapStep(
        id: 'bud_03_margin',
        order: 3,
        titleKey: 'capStepBudget03Title',
        descriptionKey: 'capStepBudget03Desc',
        status: hasBudget
            ? CapStepStatus.completed
            : (hasIncome && hasCharges)
                ? CapStepStatus.upcoming
                : CapStepStatus.blocked,
        intentTag: '/budget',
        impactEstimate: _estimateFreeMontly(profile),
      ),
      CapStep(
        id: 'bud_04_savings',
        order: 4,
        titleKey: 'capStepBudget04Title',
        descriptionKey: 'capStepBudget04Desc',
        status: hasBudgetDeep
            ? CapStepStatus.completed
            : hasBudget
                ? CapStepStatus.upcoming
                : CapStepStatus.blocked,
        intentTag: '/budget',
        impactEstimate: null,
      ),
      CapStep(
        id: 'bud_05_epargne',
        order: 5,
        titleKey: 'capStepBudget05Title',
        descriptionKey: 'capStepBudget05Desc',
        status: hasEpargne
            ? CapStepStatus.completed
            : hasBudget
                ? CapStepStatus.upcoming
                : CapStepStatus.blocked,
        intentTag: '/budget',
        impactEstimate: null,
      ),
      CapStep(
        id: 'bud_06_3a',
        order: 6,
        titleKey: 'capStepBudget06Title',
        descriptionKey: 'capStepBudget06Desc',
        status: has3a
            ? CapStepStatus.completed
            : hasEpargne
                ? CapStepStatus.upcoming
                : CapStepStatus.blocked,
        intentTag: '/pilier-3a',
        impactEstimate: _estimate3aImpact(profile),
      ),
    ];

    return CapSequence.fromSteps(goalId: _kGoalBudget, steps: steps);
  }

  // ── HOUSING SEQUENCE ──────────────────────────────────────────

  /// 7-step housing purchase sequence.
  static CapSequence _buildHousing(CoachProfile profile, CapMemory memory) {
    final done = memory.completedActions;

    final hasIncome = profile.salaireBrutMensuel > 0;
    final hasFonds = profile.patrimoine.epargneLiquide > 0 ||
        profile.prevoyance.totalEpargne3a > 0 ||
        done.contains('fonds_propres_entered');
    final hasAffordability = done.contains('affordability') ||
        done.contains('affordability_visited') ||
        done.contains('housing_purchase');
    final hasMortgage = done.contains('mortgage') ||
        done.contains('mortgage_visited') ||
        (profile.patrimoine.mortgageBalance ?? 0) > 0;
    final hasEpl = done.contains('epl') ||
        done.contains('epl_visited') ||
        done.contains('lpp_buyback');
    final hasLocationComp = done.contains('location_vs_propriete') ||
        done.contains('location_vs_achat');

    final steps = <CapStep>[
      CapStep(
        id: 'hou_01_income',
        order: 1,
        titleKey: 'capStepHousing01Title',
        descriptionKey: 'capStepHousing01Desc',
        status: hasIncome ? CapStepStatus.completed : CapStepStatus.upcoming,
        intentTag: '/profile',
        impactEstimate: null,
      ),
      CapStep(
        id: 'hou_02_fonds',
        order: 2,
        titleKey: 'capStepHousing02Title',
        descriptionKey: 'capStepHousing02Desc',
        status: hasFonds
            ? CapStepStatus.completed
            : hasIncome
                ? CapStepStatus.upcoming
                : CapStepStatus.blocked,
        intentTag: '/app/dossier',
        impactEstimate: null,
      ),
      CapStep(
        id: 'hou_03_capacity',
        order: 3,
        titleKey: 'capStepHousing03Title',
        descriptionKey: 'capStepHousing03Desc',
        status: hasAffordability
            ? CapStepStatus.completed
            : (hasIncome && hasFonds)
                ? CapStepStatus.upcoming
                : CapStepStatus.blocked,
        intentTag: '/hypotheque',
        impactEstimate: _estimateAffordability(profile),
      ),
      CapStep(
        id: 'hou_04_mortgage',
        order: 4,
        titleKey: 'capStepHousing04Title',
        descriptionKey: 'capStepHousing04Desc',
        status: hasMortgage
            ? CapStepStatus.completed
            : hasAffordability
                ? CapStepStatus.upcoming
                : CapStepStatus.blocked,
        intentTag: '/hypotheque',
        impactEstimate: null,
      ),
      CapStep(
        id: 'hou_05_epl',
        order: 5,
        titleKey: 'capStepHousing05Title',
        descriptionKey: 'capStepHousing05Desc',
        status: hasEpl
            ? CapStepStatus.completed
            : hasAffordability
                ? CapStepStatus.upcoming
                : CapStepStatus.blocked,
        intentTag: '/rachat-lpp',
        impactEstimate: _estimateEplImpact(profile),
      ),
      CapStep(
        id: 'hou_06_compare',
        order: 6,
        titleKey: 'capStepHousing06Title',
        descriptionKey: 'capStepHousing06Desc',
        status: hasLocationComp
            ? CapStepStatus.completed
            : hasMortgage
                ? CapStepStatus.upcoming
                : CapStepStatus.blocked,
        intentTag: '/arbitrage/location-vs-propriete',
        impactEstimate: null,
      ),
      CapStep(
        id: 'hou_07_specialist',
        order: 7,
        titleKey: 'capStepHousing07Title',
        descriptionKey: 'capStepHousing07Desc',
        status: done.contains('specialist_consulted')
            ? CapStepStatus.completed
            : CapStepStatus.upcoming,
        intentTag: null,
        impactEstimate: null,
      ),
    ];

    return CapSequence.fromSteps(goalId: _kGoalHousing, steps: steps);
  }

  // ── FIRST JOB SEQUENCE ───────────────────────────────────────

  /// 5-step first job financial onboarding sequence.
  static CapSequence _buildFirstJob(CoachProfile profile, CapMemory memory) {
    final done = memory.completedActions;
    final prev = profile.prevoyance;

    final hasSalary = profile.salaireBrutMensuel > 0;
    final hasSalaryXray = done.contains('first_job_salary');
    final hasLpp = (prev.avoirLppTotal ?? 0) > 0 || done.contains('lpp_verified');
    final has3a = done.contains('pillar_3a') || (prev.totalEpargne3a) > 0;

    final steps = <CapStep>[
      CapStep(
        id: 'fj_01_income',
        order: 1,
        titleKey: 'capStepFirstJob01Title',
        descriptionKey: 'capStepFirstJob01Desc',
        status: hasSalary ? CapStepStatus.completed : CapStepStatus.upcoming,
        intentTag: '/profile',
        impactEstimate: null,
      ),
      CapStep(
        id: 'fj_02_salary_xray',
        order: 2,
        titleKey: 'capStepFirstJob02Title',
        descriptionKey: 'capStepFirstJob02Desc',
        status: hasSalaryXray
            ? CapStepStatus.completed
            : hasSalary
                ? CapStepStatus.upcoming
                : CapStepStatus.blocked,
        intentTag: '/first-job',
        impactEstimate: null,
      ),
      CapStep(
        id: 'fj_03_lpp',
        order: 3,
        titleKey: 'capStepFirstJob03Title',
        descriptionKey: 'capStepFirstJob03Desc',
        status: hasLpp
            ? CapStepStatus.completed
            : hasSalary
                ? CapStepStatus.upcoming
                : CapStepStatus.blocked,
        intentTag: '/rachat-lpp',
        impactEstimate: _estimateLppMonthly(profile),
      ),
      CapStep(
        id: 'fj_04_3a',
        order: 4,
        titleKey: 'capStepFirstJob04Title',
        descriptionKey: 'capStepFirstJob04Desc',
        status: has3a
            ? CapStepStatus.completed
            : hasSalary
                ? CapStepStatus.upcoming
                : CapStepStatus.blocked,
        intentTag: '/pilier-3a',
        impactEstimate: _estimate3aImpact(profile),
      ),
      CapStep(
        id: 'fj_05_specialist',
        order: 5,
        titleKey: 'capStepFirstJob05Title',
        descriptionKey: 'capStepFirstJob05Desc',
        status: done.contains('specialist_consulted')
            ? CapStepStatus.completed
            : CapStepStatus.upcoming,
        intentTag: null, // Opens coach
        impactEstimate: null,
      ),
    ];

    return CapSequence.fromSteps(goalId: _kGoalFirstJob, steps: steps);
  }

  // ── NEW JOB SEQUENCE ──────────────────────────────────────────

  /// 5-step new job / job change financial review sequence.
  static CapSequence _buildNewJob(CoachProfile profile, CapMemory memory) {
    final done = memory.completedActions;
    final prev = profile.prevoyance;

    final hasSalary = profile.salaireBrutMensuel > 0;
    final hasSalaryCompared = done.contains('salary_compared');
    final hasLppTransfer = done.contains('lpp_transfer_checked');
    final has3a = done.contains('3a_optimized') || prev.totalEpargne3a > 0;

    final steps = <CapStep>[
      CapStep(
        id: 'nj_01_income',
        order: 1,
        titleKey: 'capStepNewJob01Title',
        descriptionKey: 'capStepNewJob01Desc',
        status: hasSalary ? CapStepStatus.completed : CapStepStatus.upcoming,
        intentTag: '/profile',
        impactEstimate: null,
      ),
      CapStep(
        id: 'nj_02_compare',
        order: 2,
        titleKey: 'capStepNewJob02Title',
        descriptionKey: 'capStepNewJob02Desc',
        status: hasSalaryCompared
            ? CapStepStatus.completed
            : hasSalary
                ? CapStepStatus.upcoming
                : CapStepStatus.blocked,
        intentTag: '/rente-vs-capital',
        impactEstimate: null,
      ),
      CapStep(
        id: 'nj_03_lpp_transfer',
        order: 3,
        titleKey: 'capStepNewJob03Title',
        descriptionKey: 'capStepNewJob03Desc',
        status: hasLppTransfer
            ? CapStepStatus.completed
            : hasSalary
                ? CapStepStatus.upcoming
                : CapStepStatus.blocked,
        intentTag: '/rachat-lpp',
        impactEstimate: _estimateLppMonthly(profile),
      ),
      CapStep(
        id: 'nj_04_3a',
        order: 4,
        titleKey: 'capStepNewJob04Title',
        descriptionKey: 'capStepNewJob04Desc',
        status: has3a
            ? CapStepStatus.completed
            : hasSalary
                ? CapStepStatus.upcoming
                : CapStepStatus.blocked,
        intentTag: '/pilier-3a',
        impactEstimate: _estimate3aImpact(profile),
      ),
      CapStep(
        id: 'nj_05_specialist',
        order: 5,
        titleKey: 'capStepNewJob05Title',
        descriptionKey: 'capStepNewJob05Desc',
        status: done.contains('specialist_consulted')
            ? CapStepStatus.completed
            : CapStepStatus.upcoming,
        intentTag: null, // Opens coach
        impactEstimate: null,
      ),
    ];

    return CapSequence.fromSteps(goalId: _kGoalNewJob, steps: steps);
  }

  // ── IMPACT ESTIMATES ─────────────────────────────────────────

  /// Rough monthly AVS estimate (max rente / 44 * years contributed).
  static double? _estimateAvsMonthly(CoachProfile profile) {
    final years = profile.prevoyance.anneesContribuees;
    if (years == null || years <= 0) return null;
    // Max rente mensuelle AVS = 2'520 CHF (2025/2026)
    const maxRenteMensuelle = 2520.0;
    return (maxRenteMensuelle * years / 44).clamp(0, maxRenteMensuelle);
  }

  /// Rough monthly LPP estimate from current avoir and conversion rate.
  static double? _estimateLppMonthly(CoachProfile profile) {
    final avoir = profile.prevoyance.avoirLppTotal;
    if (avoir == null || avoir <= 0) return null;
    final taux = profile.prevoyance.tauxConversion; // default 0.068
    return avoir * taux / 12;
  }

  /// Annual 3a tax saving estimate using canton-aware marginal rate.
  static double? _estimate3aImpact(CoachProfile profile) {
    if (profile.salaireBrutMensuel <= 0) return null;
    final grossAnnual = profile.salaireBrutMensuel * 12;
    final canton = profile.canton.isNotEmpty ? profile.canton : 'ZH';
    final annualSaving = RetirementTaxCalculator.estimate3aTaxSaving(
      grossAnnualSalary: grossAnnual,
      canton: canton,
    );
    // Monthly impact = annual savings / 12
    return annualSaving / 12;
  }

  /// Rough LPP buyback monthly benefit (rachat × taux conversion / 12).
  static double? _estimateRachatImpact(CoachProfile profile) {
    final rachat = profile.prevoyance.rachatMaximum ?? 0;
    if (rachat <= 0) return null;
    final taux = profile.prevoyance.tauxConversion;
    return rachat * taux / 12;
  }

  /// Monthly free margin estimate.
  static double? _estimateFreeMontly(CoachProfile profile) {
    if (profile.salaireBrutMensuel <= 0) return null;
    final depenses = profile.depenses.totalMensuel;
    if (depenses <= 0) return null;
    // Rough net = brut * 0.78 (average Swiss tax + social charges)
    final net = profile.salaireBrutMensuel * 0.78;
    final libre = net - depenses;
    return libre > 0 ? libre : null;
  }

  /// Housing affordability estimate: 80% of 4.5× annual gross (FINMA 20% down).
  static double? _estimateAffordability(CoachProfile profile) {
    if (profile.salaireBrutMensuel <= 0) return null;
    // Rough capacity = annual gross × 4.5 (FINMA 1/3 rule at 5% theoretical)
    final annualGross = profile.salaireBrutMensuel * 12;
    return annualGross * 4.5;
  }

  /// EPL (retrait LPP anticipé): 10% of LPP avoir, capped at available.
  static double? _estimateEplImpact(CoachProfile profile) {
    final avoir = profile.prevoyance.avoirLppTotal;
    if (avoir == null || avoir < 20000) return null; // OPP2 art. 5 minimum
    return avoir * 0.1;
  }
}

// S is a required parameter on CapSequenceEngine.build() to enforce the i18n
// contract at call site — the caller must have a localization context.
// The engine only stores ARB key strings; the widget resolves them at render.
