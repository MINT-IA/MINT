// ────────────────────────────────────────────────────────────
//  LIFECYCLE ADAPTATION — S57 / Phase 2 "Le Compagnon"
// ────────────────────────────────────────────────────────────
//
// Describes what content, tone, and complexity to apply
// for each of the 7 lifecycle phases.
//
// Used by LifecycleDetector.adapt() and ContentAdapterService.
// Pure data — no side effects.
// ────────────────────────────────────────────────────────────
library;

import 'package:mint_mobile/services/lifecycle/lifecycle_phase.dart';

/// Content adaptation hints for a given lifecycle phase.
///
/// Consumed by:
/// - Coach AI system prompt (toneGuidance)
/// - Dashboard curator (relevantScreens, priorityTopics)
/// - Educational inserts (complexityLevel)
/// - Notification service (toneGuidance)
class LifecycleAdaptation {
  /// The phase this adaptation applies to.
  final LifecyclePhase phase;

  /// Topic slugs to prioritize in this phase.
  ///
  /// Used to rank content, widgets, and coach suggestions.
  /// Values are internal slugs (not i18n keys).
  final List<String> priorityTopics;

  /// Intent tags from ScreenRegistry relevant to this phase.
  ///
  /// Used by RoutePlanner to pre-warm relevant screens.
  final List<String> relevantScreens;

  /// LLM system prompt guidance for tone in this phase.
  ///
  /// Injected into the coach AI context. Not shown to user.
  final String toneGuidance;

  /// Content complexity: 0.0 (simple) to 1.0 (expert).
  ///
  /// 0.0–0.3: essential concepts only, plain language.
  /// 0.4–0.6: standard financial vocabulary with brief explanations.
  /// 0.7–1.0: full technical depth, Monte Carlo, tax optimization.
  final double complexityLevel;

  const LifecycleAdaptation({
    required this.phase,
    required this.priorityTopics,
    required this.relevantScreens,
    required this.toneGuidance,
    required this.complexityLevel,
  });
}

/// Pre-computed adaptation map — one entry per phase.
///
/// Constructed once via [lifecycleAdaptations].
const Map<LifecyclePhase, LifecycleAdaptation> lifecycleAdaptations = {
  LifecyclePhase.demarrage: LifecycleAdaptation(
    phase: LifecyclePhase.demarrage,
    priorityTopics: ['budget', 'pillar_3a', 'first_job', 'emergency_fund'],
    relevantScreens: [
      'budget_overview',
      'pillar_3a_intro',
      'first_job',
      'payslip_explainer',
    ],
    toneGuidance: 'Encourageant et simple. C\u00e9l\u00e8bre chaque petit progr\u00e8s. '
        '\u00c9vite le jargon — explique avec des analogies du quotidien. '
        'Phrases courtes. Un concept \u00e0 la fois.',
    complexityLevel: 0.3,
  ),
  LifecyclePhase.construction: LifecycleAdaptation(
    phase: LifecyclePhase.construction,
    priorityTopics: [
      'pillar_3a',
      'housing_purchase',
      'patrimoine',
      'insurance_coverage',
    ],
    relevantScreens: [
      'pillar_3a_deep',
      'housing_simulator',
      'patrimoine_overview',
      'life_event_marriage',
    ],
    toneGuidance: 'Motivant et concret. L\u2019utilisateur b\u00e2tit son avenir — '
        'propose des \u00e9tapes actionnables. Vocabulaire financier standard '
        'avec explications br\u00e8ves.',
    complexityLevel: 0.5,
  ),
  LifecyclePhase.acceleration: LifecycleAdaptation(
    phase: LifecyclePhase.acceleration,
    priorityTopics: [
      'lpp_buyback',
      'tax_optimization',
      'asset_diversification',
      'retirement_projection',
    ],
    relevantScreens: [
      'lpp_deep',
      'rente_vs_capital',
      'tax_optimizer',
      'retirement_projection',
      'monte_carlo',
    ],
    toneGuidance: 'Strat\u00e9gique et orient\u00e9 action. L\u2019utilisateur est en phase '
        'd\u2019optimisation — propose des leviers concrets. Utilise le '
        'vocabulaire financier complet avec calculs \u00e0 l\u2019appui.',
    complexityLevel: 0.75,
  ),
  LifecyclePhase.consolidation: LifecycleAdaptation(
    phase: LifecyclePhase.consolidation,
    priorityTopics: [
      'lpp_buyback',
      'retirement_planning',
      'tax_optimization',
      'rente_vs_capital',
      'succession_prep',
    ],
    relevantScreens: [
      'lpp_deep',
      'rente_vs_capital',
      'retirement_projection',
      'monte_carlo',
      'tax_optimizer',
      'succession',
    ],
    toneGuidance: 'Rassurant et pr\u00e9cis. L\u2019utilisateur s\u00e9curise sa position — '
        'pr\u00e9sente les sc\u00e9narios de fa\u00e7on ordonn\u00e9e (bas/moyen/haut). '
        'Insiste sur ce qui est sous contr\u00f4le. Ton m\u00e9thodique.',
    complexityLevel: 0.85,
  ),
  LifecyclePhase.transition: LifecycleAdaptation(
    phase: LifecyclePhase.transition,
    priorityTopics: [
      'rente_vs_capital',
      'withdrawal_sequencing',
      'pre_retirement',
      'bridge_income',
    ],
    relevantScreens: [
      'rente_vs_capital',
      'retirement_projection',
      'withdrawal_sequencing',
      'lpp_deep',
      'tax_optimizer',
    ],
    toneGuidance: 'Calme et structur\u00e9. L\u2019utilisateur approche d\u2019une d\u00e9cision '
        'irr\u00e9versible — pr\u00e9sente chaque option clairement avec ses '
        'implications \u00e0 long terme. \u00c9vite l\u2019urgence artificielle.',
    complexityLevel: 0.9,
  ),
  LifecyclePhase.retraite: LifecycleAdaptation(
    phase: LifecyclePhase.retraite,
    priorityTopics: [
      'withdrawal_rate',
      'retirement_budget',
      'lamal_subsidy',
      'estate_planning',
    ],
    relevantScreens: [
      'budget_overview',
      'withdrawal_sequencing',
      'lamal_optimizer',
      'succession',
    ],
    toneGuidance: 'S\u00e9r\u00e8ne et de soutien. L\u2019utilisateur vit sa retraite — '
        'pr\u00e9sente les montants mensuels (pas annuels). Phrases courtes. '
        'Actions imm\u00e9diates et concr\u00e8tes. Pas de jargon.',
    complexityLevel: 0.5,
  ),
  LifecyclePhase.transmission: LifecycleAdaptation(
    phase: LifecyclePhase.transmission,
    priorityTopics: [
      'estate_planning',
      'donation',
      'advance_directive',
      'beneficiary_review',
    ],
    relevantScreens: [
      'succession',
      'donation_simulator',
      'advance_directive',
    ],
    toneGuidance: 'Sage et respectueux. L\u2019utilisateur pr\u00e9pare sa transmission — '
        'ton digne, sans euphémismes excessifs. Clarté sur les d\u00e9marches '
        'l\u00e9gales. Un sujet \u00e0 la fois.',
    complexityLevel: 0.4,
  ),
};
