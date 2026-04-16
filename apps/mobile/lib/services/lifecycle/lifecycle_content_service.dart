// ────────────────────────────────────────────────────────────
//  LIFECYCLE CONTENT SERVICE — S57 / Phase 2 "Le Compagnon"
// ────────────────────────────────────────────────────────────
//
// Provides phase-aware content:
//   - i18n label for each phase (phaseLabel)
//   - i18n description for each phase (phaseDescription)
//   - Suggested intent tags for the coach to propose (suggestedTopics)
//
// All user-facing strings are routed through AppLocalizations (S).
// No hardcoded strings in output.
//
// Pure functions — no side effects, deterministic, testable.
// ────────────────────────────────────────────────────────────
library;

import 'package:mint_mobile/l10n/app_localizations.dart' show S;
import 'package:mint_mobile/services/lifecycle/lifecycle_phase.dart';

/// Provides phase-aware i18n content and topic suggestions.
class LifecycleContentService {
  LifecycleContentService._();

  /// Returns the i18n label for a lifecycle phase.
  ///
  /// Uses [S] (AppLocalizations) — keys defined in all 6 ARB files.
  /// Key pattern: `lifecyclePhase{PhaseName}` (e.g. `lifecyclePhaseDemarrage`).
  static String phaseLabel(LifecyclePhase phase, S l) {
    switch (phase) {
      case LifecyclePhase.demarrage:
        return l.lifecyclePhaseDemarrage;
      case LifecyclePhase.construction:
        return l.lifecyclePhaseConstruction;
      case LifecyclePhase.acceleration:
        return l.lifecyclePhaseAcceleration;
      case LifecyclePhase.consolidation:
        return l.lifecyclePhaseConsolidation;
      case LifecyclePhase.transition:
        return l.lifecyclePhaseTransition;
      case LifecyclePhase.retraite:
        return l.lifecyclePhaseRetraite;
      case LifecyclePhase.transmission:
        return l.lifecyclePhaseTransmission;
    }
  }

  /// Returns the i18n description for a lifecycle phase.
  ///
  /// Key pattern: `lifecyclePhase{PhaseName}Desc` (e.g. `lifecyclePhaseDemarrageDesc`).
  static String phaseDescription(LifecyclePhase phase, S l) {
    switch (phase) {
      case LifecyclePhase.demarrage:
        return l.lifecyclePhaseDemarrageDesc;
      case LifecyclePhase.construction:
        return l.lifecyclePhaseConstructionDesc;
      case LifecyclePhase.acceleration:
        return l.lifecyclePhaseAccelerationDesc;
      case LifecyclePhase.consolidation:
        return l.lifecyclePhaseConsolidationDesc;
      case LifecyclePhase.transition:
        return l.lifecyclePhaseTransitionDesc;
      case LifecyclePhase.retraite:
        return l.lifecyclePhaseRetraiteDesc;
      case LifecyclePhase.transmission:
        return l.lifecyclePhaseTransmissionDesc;
    }
  }

  /// Returns intent tags the coach should suggest for a given phase.
  ///
  /// Intent tags match [ScreenRegistry.intentTag] values — they are used
  /// by the RoutePlanner to pre-warm or surface relevant screens.
  ///
  /// Returns a non-empty list for every phase.
  static List<String> suggestedTopics(LifecyclePhase phase) {
    switch (phase) {
      case LifecyclePhase.demarrage:
        return [
          'budget_overview',
          'pillar_3a_intro',
          'first_job',
          'payslip_explainer',
        ];
      case LifecyclePhase.construction:
        return [
          'pillar_3a_deep',
          'housing_simulator',
          'patrimoine_overview',
          'life_event_marriage',
        ];
      case LifecyclePhase.acceleration:
        return [
          'lpp_deep',
          'rente_vs_capital',
          'tax_optimizer',
          'retirement_projection',
          'monte_carlo',
        ];
      case LifecyclePhase.consolidation:
        return [
          'lpp_deep',
          'rente_vs_capital',
          'retirement_projection',
          'monte_carlo',
          'tax_optimizer',
          'succession',
        ];
      case LifecyclePhase.transition:
        return [
          'rente_vs_capital',
          'retirement_projection',
          'withdrawal_sequencing',
          'lpp_deep',
          'tax_optimizer',
        ];
      case LifecyclePhase.retraite:
        return [
          'budget_overview',
          'withdrawal_sequencing',
          'lamal_optimizer',
          'succession',
        ];
      case LifecyclePhase.transmission:
        return [
          'succession',
          'donation_simulator',
          'advance_directive',
        ];
    }
  }
}
