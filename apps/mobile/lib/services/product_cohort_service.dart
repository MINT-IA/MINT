/// Product cohort projection from LifecyclePhaseService.
///
/// NOT a new classification system. This is a read-only projection
/// of LifecyclePhase → 6 product cohorts for UI adaptation.
///
/// Source of truth: LifecyclePhaseService (lifecycle_phase_service.dart).
/// This service adds ZERO new detection logic.
///
/// See: COHORT_OS_SPEC.md, MINT_ANTI_BULLSHIT_MANIFESTO.md
library;

import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/lifecycle_phase_service.dart';

/// 6 product cohorts — UI labels for lifecycle phases.
enum ProductCohort {
  premiersPas,     // 18-27: démarrage
  construction,    // 28-35: construction
  densification,   // 35-52: accélération + consolidation
  preRetraite,     // 53-64: transition
  retraiteActive,  // 65-74: retraite
  transmission,    // 75+:   transmission
}

/// Result of cohort projection.
class ProductCohortResult {
  final ProductCohort cohort;
  final LifecyclePhaseResult lifecycle;

  /// Topics to NEVER suggest for this cohort (Anti-Bullshit rule §6).
  final Set<String> suppressedTopics;

  const ProductCohortResult({
    required this.cohort,
    required this.lifecycle,
    required this.suppressedTopics,
  });
}

/// Projects a LifecyclePhase into a ProductCohort.
///
/// Pure function. No state, no side effects, no new detection logic.
/// Uses LifecyclePhaseService as the sole source of truth.
class ProductCohortService {
  ProductCohortService._();

  static ProductCohortResult resolve(CoachProfile profile) {
    final lifecycle = LifecyclePhaseService.detect(profile);

    final cohort = switch (lifecycle.phase) {
      LifecyclePhase.demarrage => ProductCohort.premiersPas,
      LifecyclePhase.construction => ProductCohort.construction,
      LifecyclePhase.acceleration => ProductCohort.densification,
      LifecyclePhase.consolidation => ProductCohort.densification,
      LifecyclePhase.transition => ProductCohort.preRetraite,
      LifecyclePhase.retraite => ProductCohort.retraiteActive,
      LifecyclePhase.transmission => ProductCohort.transmission,
    };

    final suppressed = _suppressedTopics(cohort);

    return ProductCohortResult(
      cohort: cohort,
      lifecycle: lifecycle,
      suppressedTopics: suppressed,
    );
  }

  /// Topics to suppress per cohort (MINT_ANTI_BULLSHIT_MANIFESTO.md §6).
  /// These topics MUST NOT appear as caps, CTAs, or sequence suggestions.
  static Set<String> _suppressedTopics(ProductCohort cohort) {
    return switch (cohort) {
      ProductCohort.premiersPas => {
        'retirement_deep', 'succession', 'lpp_buyback',
        'withdrawal_sequencing', 'rente_vs_capital', 'estate_planning',
      },
      ProductCohort.construction => {
        'succession', 'estate_planning', 'withdrawal_sequencing',
      },
      ProductCohort.densification => const {},
      ProductCohort.preRetraite => {
        'first_job', 'unemployment_basics', 'birth_costs',
      },
      ProductCohort.retraiteActive => {
        'first_job', 'unemployment_basics', 'birth_costs',
        'job_comparison', 'housing_purchase',
      },
      ProductCohort.transmission => {
        'first_job', 'unemployment_basics', 'birth_costs',
        'job_comparison', 'housing_purchase', 'lpp_buyback',
      },
    };
  }
}
