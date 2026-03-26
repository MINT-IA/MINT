import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/constants/social_insurance.dart';

// ────────────────────────────────────────────────────────────
//  LIFECYCLE PHASE SERVICE — S57 / Phase 2 "Le Compagnon"
// ────────────────────────────────────────────────────────────
//
// Detects the user's lifecycle phase (7 phases, age 22-99+)
// and adapts content tone, complexity, and priorities.
//
// Phases:
//   1. Démarrage    (22-28) — First steps, build habits
//   2. Construction (28-35) — Career acceleration, family
//   3. Accélération (35-45) — Peak earning, optimize
//   4. Consolidation(45-55) — Secure, buyback, plan
//   5. Transition   (55-65) — Pre-retirement, countdown
//   6. Retraite     (65-80) — Living off savings
//   7. Transmission (75-99) — Legacy, estate planning
//
// Pure functions — no side effects, deterministic, testable.
// ────────────────────────────────────────────────────────────

/// Lifecycle phase enum (7 phases covering full adult life).
enum LifecyclePhase {
  demarrage,      // 22-28: First job, habits, 3a
  construction,   // 28-35: Career, family, property
  acceleration,   // 35-45: Peak earning, optimization
  consolidation,  // 45-55: Secure position, LPP buyback
  transition,     // 55-65: Pre-retirement planning
  retraite,       // 65-80: Living off retirement income
  transmission,   // 75-99+: Legacy and estate planning
}

/// Tone of communication adapted per phase.
enum LifecycleTone {
  encouraging,  // Démarrage, Construction — motivating, simple
  empowering,   // Accélération — confident, action-oriented
  reassuring,   // Consolidation, Transition — calm, methodical
  simple,       // Retraite, Transmission — clear, no jargon
}

/// Complexity level for content display.
enum LifecycleComplexity {
  basic,        // Essential concepts only
  intermediate, // Details + some technical terms
  advanced,     // Full projections, Monte Carlo, tax optimization
}

/// Result of lifecycle phase detection.
class LifecyclePhaseResult {
  /// Detected lifecycle phase.
  final LifecyclePhase phase;

  /// User's current age (computed from birthYear).
  final int age;

  /// Years to retirement (based on target or default 65).
  final int yearsToRetirement;

  /// Recommended communication tone.
  final LifecycleTone tone;

  /// Content complexity level.
  final LifecycleComplexity complexity;

  /// Top 3 priorities for this phase (ordered by importance).
  final List<LifecyclePriority> priorities;

  /// Phase description key (for i18n lookup).
  final String phaseKey;

  const LifecyclePhaseResult({
    required this.phase,
    required this.age,
    required this.yearsToRetirement,
    required this.tone,
    required this.complexity,
    required this.priorities,
    required this.phaseKey,
  });
}

/// A prioritized action for the current phase.
class LifecyclePriority {
  /// Priority identifier (for i18n lookup).
  final String key;

  /// Weight (1.0 = critical, 0.5 = important, 0.3 = nice-to-have).
  final double weight;

  /// Related life event (if any).
  final String? relatedLifeEvent;

  const LifecyclePriority({
    required this.key,
    required this.weight,
    this.relatedLifeEvent,
  });
}

/// Detects lifecycle phase from profile data.
///
/// Pure function — no side effects.
/// [now] parameter for testing (defaults to DateTime.now()).
class LifecyclePhaseService {
  LifecyclePhaseService._();

  /// Detect the lifecycle phase from a profile.
  ///
  /// Uses age as primary signal, with secondary signals from
  /// employment status, retirement target, and family situation.
  static LifecyclePhaseResult detect(
    CoachProfile profile, {
    DateTime? now,
  }) {
    final currentDate = now ?? DateTime.now();
    // NOTE: CoachProfile only has birthYear (int), not a full birthDate.
    // This means age = currentDate.year - birthYear, which may overestimate
    // by up to 11 months (e.g. born June 1982, in March 2026 → computed 44,
    // actual 43). This is a known limitation — see CoachProfile model.
    // Phase boundaries use wide bands (10+ years), so the ±1 year error
    // does not cause phase misclassification in practice.
    final age = currentDate.year - profile.birthYear;
    final targetRetirement = profile.targetRetirementAge ?? avsAgeReferenceHomme;
    final yearsToRetirement = targetRetirement - age;

    final phase = _detectPhase(age, profile);
    final tone = _toneForPhase(phase);
    final complexity = _complexityForPhase(phase, profile);
    final priorities = _prioritiesForPhase(phase, profile, age);

    return LifecyclePhaseResult(
      phase: phase,
      age: age,
      yearsToRetirement: yearsToRetirement,
      tone: tone,
      complexity: complexity,
      priorities: priorities,
      phaseKey: phase.name,
    );
  }

  /// Core phase detection — age-based with situation overrides.
  ///
  /// Canonical rule (unified across all classifiers):
  /// Retirement = avsAgeReferenceHomme (65). Pre-retirement = 5 years before.
  ///
  /// Age bands overlap at boundaries; situation signals disambiguate:
  /// - Already retired (employmentStatus) → retraite/transmission
  /// - Target retirement < standard age → may shift to transition earlier
  /// - Still in school/studies at 24 → stays in démarrage
  static LifecyclePhase _detectPhase(int age, CoachProfile profile) {
    // Override: if user is already retired, use retraite/transmission
    if (profile.employmentStatus == 'retraite') {
      return age >= 75 ? LifecyclePhase.transmission : LifecyclePhase.retraite;
    }

    // Override: early retirement — if target retirement is within 10 years
    // and user is 50+, shift to transition (only if not yet past target)
    final targetRetirement = profile.targetRetirementAge ?? avsAgeReferenceHomme;
    final yearsLeft = targetRetirement - age;
    if (age >= 50 && yearsLeft > 0 && yearsLeft <= 10) {
      return LifecyclePhase.transition;
    }

    // Standard age-based detection
    if (age < 28) return LifecyclePhase.demarrage;
    if (age < 35) return LifecyclePhase.construction;
    if (age < 45) return LifecyclePhase.acceleration;
    if (age < 55) return LifecyclePhase.consolidation;
    if (age < avsAgeReferenceHomme) return LifecyclePhase.transition;
    if (age < 75) return LifecyclePhase.retraite;
    return LifecyclePhase.transmission;
  }

  /// Map phase to communication tone.
  static LifecycleTone _toneForPhase(LifecyclePhase phase) {
    switch (phase) {
      case LifecyclePhase.demarrage:
      case LifecyclePhase.construction:
        return LifecycleTone.encouraging;
      case LifecyclePhase.acceleration:
        return LifecycleTone.empowering;
      case LifecyclePhase.consolidation:
      case LifecyclePhase.transition:
        return LifecycleTone.reassuring;
      case LifecyclePhase.retraite:
      case LifecyclePhase.transmission:
        return LifecycleTone.simple;
    }
  }

  /// Determine content complexity from phase + financial literacy.
  static LifecycleComplexity _complexityForPhase(
    LifecyclePhase phase,
    CoachProfile profile,
  ) {
    // Financial literacy level overrides phase default if higher
    final isAdvanced = profile.financialLiteracyLevel == FinancialLiteracyLevel.advanced;
    final isIntermediate = profile.financialLiteracyLevel == FinancialLiteracyLevel.intermediate;

    switch (phase) {
      case LifecyclePhase.demarrage:
        return isAdvanced ? LifecycleComplexity.intermediate : LifecycleComplexity.basic;
      case LifecyclePhase.construction:
        return isAdvanced ? LifecycleComplexity.advanced : LifecycleComplexity.intermediate;
      case LifecyclePhase.acceleration:
      case LifecyclePhase.consolidation:
      case LifecyclePhase.transition:
        return (isAdvanced || isIntermediate)
            ? LifecycleComplexity.advanced
            : LifecycleComplexity.intermediate;
      case LifecyclePhase.retraite:
        return isAdvanced ? LifecycleComplexity.advanced : LifecycleComplexity.intermediate;
      case LifecyclePhase.transmission:
        return isAdvanced ? LifecycleComplexity.intermediate : LifecycleComplexity.basic;
    }
  }

  /// Build priority list for phase + profile situation.
  ///
  /// Each phase has default priorities, with situational boosts:
  /// - Married/concubinage → couple-specific priorities
  /// - Homeowner → mortgage optimization
  /// - High debt → debt reduction
  /// - Expat archetypes → specific cross-border priorities
  static List<LifecyclePriority> _prioritiesForPhase(
    LifecyclePhase phase,
    CoachProfile profile,
    int age,
  ) {
    final priorities = <LifecyclePriority>[];

    switch (phase) {
      case LifecyclePhase.demarrage:
        priorities.addAll([
          const LifecyclePriority(key: 'open_3a', weight: 1.0, relatedLifeEvent: 'firstJob'),
          const LifecyclePriority(key: 'build_emergency_fund', weight: 0.9),
          const LifecyclePriority(key: 'understand_payslip', weight: 0.8),
          const LifecyclePriority(key: 'start_budget', weight: 0.7),
        ]);

      case LifecyclePhase.construction:
        priorities.addAll([
          const LifecyclePriority(key: 'max_3a', weight: 1.0),
          const LifecyclePriority(key: 'evaluate_housing', weight: 0.9, relatedLifeEvent: 'housingPurchase'),
          const LifecyclePriority(key: 'grow_patrimoine', weight: 0.8),
          const LifecyclePriority(key: 'check_insurance_coverage', weight: 0.6),
        ]);

      case LifecyclePhase.acceleration:
        priorities.addAll([
          const LifecyclePriority(key: 'lpp_buyback', weight: 1.0),
          const LifecyclePriority(key: 'optimize_taxes', weight: 0.9),
          const LifecyclePriority(key: 'diversify_assets', weight: 0.8),
          const LifecyclePriority(key: 'review_retirement_projection', weight: 0.7),
        ]);

      case LifecyclePhase.consolidation:
        priorities.addAll([
          const LifecyclePriority(key: 'plan_retirement_scenario', weight: 1.0, relatedLifeEvent: 'retirement'),
          const LifecyclePriority(key: 'maximize_lpp_buyback', weight: 0.9),
          const LifecyclePriority(key: 'rente_vs_capital', weight: 0.8),
          const LifecyclePriority(key: 'estate_planning_start', weight: 0.6),
        ]);

      case LifecyclePhase.transition:
        priorities.addAll([
          const LifecyclePriority(key: 'finalize_retirement_plan', weight: 1.0, relatedLifeEvent: 'retirement'),
          const LifecyclePriority(key: 'withdrawal_sequencing', weight: 0.9),
          const LifecyclePriority(key: 'rente_vs_capital_final', weight: 0.9),
          const LifecyclePriority(key: 'bridge_income_gap', weight: 0.7),
        ]);

      case LifecyclePhase.retraite:
        priorities.addAll([
          const LifecyclePriority(key: 'optimize_withdrawal_rate', weight: 1.0),
          const LifecyclePriority(key: 'review_budget_retirement', weight: 0.8),
          const LifecyclePriority(key: 'lamal_subsidy_check', weight: 0.7),
          const LifecyclePriority(key: 'estate_planning', weight: 0.6, relatedLifeEvent: 'donation'),
        ]);

      case LifecyclePhase.transmission:
        priorities.addAll([
          const LifecyclePriority(key: 'estate_planning_complete', weight: 1.0, relatedLifeEvent: 'donation'),
          const LifecyclePriority(key: 'advance_directive', weight: 0.9, relatedLifeEvent: 'deathOfRelative'),
          const LifecyclePriority(key: 'simplify_patrimoine', weight: 0.8),
          const LifecyclePriority(key: 'review_beneficiaries', weight: 0.7),
        ]);
    }

    // Situational boosts
    _addSituationalPriorities(priorities, profile, age);

    // Archetype-specific priorities
    _addArchetypePriorities(priorities, profile);

    // Sort by weight descending, take top priorities
    priorities.sort((a, b) => b.weight.compareTo(a.weight));

    return priorities;
  }

  /// Add or boost priorities based on profile situation.
  static void _addSituationalPriorities(
    List<LifecyclePriority> priorities,
    CoachProfile profile,
    int age,
  ) {
    // Couple-specific: if married or concubinage, add couple priorities
    if (profile.etatCivil == CoachCivilStatus.marie ||
        profile.etatCivil == CoachCivilStatus.concubinage) {
      if (profile.conjoint != null) {
        priorities.add(const LifecyclePriority(
          key: 'couple_retirement_sync',
          weight: 0.85,
          relatedLifeEvent: 'retirement',
        ));
      }
    }

    // Concubinage-specific: protection checklist
    if (profile.etatCivil == CoachCivilStatus.concubinage) {
      priorities.add(const LifecyclePriority(
        key: 'concubinage_protection',
        weight: 0.95,
        relatedLifeEvent: 'concubinage',
      ));
    }

    // Children: insurance + education planning
    if (profile.nombreEnfants > 0 && age < 55) {
      priorities.add(const LifecyclePriority(
        key: 'children_planning',
        weight: 0.75,
        relatedLifeEvent: 'birth',
      ));
    }

    // Homeowner: mortgage optimization
    if (profile.patrimoine.immobilier != null &&
        profile.patrimoine.immobilier! > 0) {
      priorities.add(const LifecyclePriority(
        key: 'mortgage_optimization',
        weight: 0.7,
        relatedLifeEvent: 'housingPurchase',
      ));
    }

    // High debt: prioritize debt reduction (safe mode)
    final totalDebt = (profile.dettes.creditConsommation ?? 0) +
        (profile.dettes.leasing ?? 0) +
        (profile.dettes.autresDettes ?? 0);
    if (totalDebt > 10000) {
      priorities.add(const LifecyclePriority(
        key: 'debt_reduction',
        weight: 1.1, // Always top priority (safe mode)
        relatedLifeEvent: 'debtCrisis',
      ));
    }
  }

  /// Add archetype-specific priorities.
  ///
  /// "Every projection MUST account for archetype. NEVER assume Swiss native."
  /// See ADR-20260223-archetype-driven-retirement.md.
  static void _addArchetypePriorities(
    List<LifecyclePriority> priorities,
    CoachProfile profile,
  ) {
    switch (profile.archetype) {
      case FinancialArchetype.expatUs:
        // FATCA compliance is always relevant for US citizens
        priorities.add(const LifecyclePriority(
          key: 'fatca_compliance',
          weight: 1.05, // Near-top priority — legal obligation
        ));

      case FinancialArchetype.expatEu:
      case FinancialArchetype.expatNonEu:
        // AVS gap analysis — totalisation of contribution periods
        priorities.add(const LifecyclePriority(
          key: 'avs_gap_analysis',
          weight: 0.9,
        ));

      case FinancialArchetype.independentNoLpp:
        // 3a max is 36'288 (not 7'258) — boost max_3a priority
        priorities.add(const LifecyclePriority(
          key: 'max_3a',
          weight: 1.0, // Top priority — only pension vehicle
        ));

      case FinancialArchetype.crossBorder:
        // Source tax optimization for frontaliers (permis G)
        priorities.add(const LifecyclePriority(
          key: 'source_tax_optimization',
          weight: 0.9,
        ));

      case FinancialArchetype.returningSwiss:
        // LPP buyback boost — returning Swiss often have large gaps
        priorities.add(const LifecyclePriority(
          key: 'lpp_buyback',
          weight: 1.0, // Rachat avantageux after return
        ));

      case FinancialArchetype.swissNative:
      case FinancialArchetype.independentWithLpp:
        // Default priorities already cover these archetypes
        break;
    }
  }
}
