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
    toneGuidance: 'Tu peux être direct et concret. Cite les montants exacts. '
        'Pas de précautions oratoires. '
        'Exemples\u00a0: "CHF\u00a085 d\'Uber Eats. Un mardi." '
        '"Ton 3a\u00a0: zéro. L\'État te remercie." '
        'Pas de "petit clin d\'œil" — la donnée EST le ton.',
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
    toneGuidance: 'Direct et factuel. Cite les CHF. '
        'Compare avec des repères concrets ("ça fait 2x ta moyenne mensuelle"). '
        'Tu peux utiliser des expressions régionales si le canton le permet.',
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
    toneGuidance: 'Précis et stratégique. Cite les montants, les pourcentages, les délais. '
        'Pas d\'humour gratuit — la clarté suffit. '
        'Vocabulaire financier complet avec calculs à l\'appui.',
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
    toneGuidance: 'Rassurant et précis. '
        'Chaque chiffre accompagné de contexte ("c\'est dans la norme" / "attention, c\'est en dessous"). '
        'Ton calme. Présente les scénarios de façon ordonnée (bas/moyen/haut).',
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
    toneGuidance: 'Calme et structuré. '
        'Présente les options une par une. Pas de pression. '
        'Chaque décision est posée. Évite l\'urgence artificielle.',
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
    toneGuidance: 'Serein. Langage clair, phrases courtes. '
        'Pas de jargon. Utilise les montants mensuels (jamais annuels). '
        'Respecte le rythme de l\'utilisateur.',
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
    toneGuidance: 'Respectueux et factuel. '
        'La succession est un sujet sensible — précision maximale, ton digne. '
        'Clarté sur les démarches légales. Un sujet à la fois.',
    complexityLevel: 0.4,
  ),
};
