import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/biography/biography_fact.dart';
import 'package:mint_mobile/services/coach/compliance_guard.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';

// ────────────────────────────────────────────────────────────
//  COACH OPENER SERVICE — Phase 05 / Interface Contextuelle
// ────────────────────────────────────────────────────────────
//
// Generates biography-aware coach greeting text for the
// Aujourd'hui tab. Selects the most relevant opener based on
// recent financial events, then validates via ComplianceGuard.
//
// Priority (first match wins):
//   1. Salary increase (document scan, within 90 days)
//   2. Recent document scan (any fact, within 30 days)
//   3. 3a contribution gap (if salary present and gap > 0)
//   4. Profile completeness < 50%
//   5. Fallback greeting
//
// Design: Pure static, zero side effects, injectable DateTime.
// All text uses conditional language (never imperatives).
// Non-breaking space before ? and : (French typography).
//
// See: CTX-03 requirement.
// Threat: T-05-04 (local-only data), T-05-05 (anonymized values).
// ────────────────────────────────────────────────────────────

/// Max days for a salary fact to be considered "recent".
const _salaryFreshnessThresholdDays = 90;

/// Max days for a document scan to be considered "recent".
const _documentFreshnessThresholdDays = 30;

/// Max 3a for salarie with LPP (2025/2026).
const _max3aSalarieLpp = 7258.0;

/// Max 3a for independant without LPP (2025/2026).
const _max3aIndependantNoLpp = 36288.0;

/// French month names for opener text.
const _frenchMonths = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];

/// Fallback opener text (safe, always compliant).
const _fallbackOpener = 'Bienvenue. Voici ton aperçu financier.';

/// Biography-aware coach opener generation with compliance validation.
///
/// Pure static class — no state, no side effects.
class CoachOpenerService {
  CoachOpenerService._();

  /// Generate a biography-aware coach opener.
  ///
  /// Selects the most relevant opener based on profile state and
  /// recent biography events. Validates via [ComplianceGuard] before
  /// returning. Falls back to safe greeting if validation fails.
  ///
  /// All text uses conditional language ("pourrait", "envisager"),
  /// never imperatives. Non-breaking space (\u00a0) before ? and :.
  static String generate({
    required CoachProfile profile,
    required List<BiographyFact> facts,
    DateTime? now,
  }) {
    final effectiveNow = now ?? DateTime.now();

    // Try each opener in priority order (first match wins)
    final opener = _trySalaryIncrease(facts, effectiveNow) ??
        _tryRecentDocument(facts, effectiveNow) ??
        _try3aGap(profile) ??
        _tryProfileCompleteness(profile, effectiveNow) ??
        _fallbackOpener;

    // Validate via ComplianceGuard (layers 1-2: banned terms + prescriptive)
    final result = ComplianceGuard.validateAlert(opener);
    if (!result.isCompliant) {
      return _fallbackOpener;
    }

    return opener;
  }

  // ── Priority 1: Salary increase (document scan, within 90 days) ──

  static String? _trySalaryIncrease(
    List<BiographyFact> facts,
    DateTime effectiveNow,
  ) {
    final salaryFacts = facts.where(
      (f) =>
          f.factType == FactType.salary &&
          f.source == FactSource.document &&
          !f.isDeleted,
    );

    for (final fact in salaryFacts) {
      final daysSinceUpdate =
          effectiveNow.difference(fact.updatedAt).inDays;
      if (daysSinceUpdate <= _salaryFreshnessThresholdDays) {
        final month = _frenchMonths[fact.updatedAt.month - 1];
        return 'Ton salaire a progressé depuis $month. '
            'Voici ce que cela change.';
      }
    }

    return null;
  }

  // ── Priority 2: Recent document scan (within 30 days) ──

  static String? _tryRecentDocument(
    List<BiographyFact> facts,
    DateTime effectiveNow,
  ) {
    final documentFacts = facts.where(
      (f) => f.source == FactSource.document && !f.isDeleted,
    );

    for (final fact in documentFacts) {
      final daysSinceUpdate =
          effectiveNow.difference(fact.updatedAt).inDays;
      if (daysSinceUpdate <= _documentFreshnessThresholdDays) {
        final typeLabel = _factTypeLabel(fact.factType);
        return 'Ton certificat $typeLabel affine tes projections. '
            'Voici ton tableau de bord.';
      }
    }

    return null;
  }

  // ── Priority 3: 3a contribution gap ──

  static String? _try3aGap(CoachProfile profile) {
    if (!profile.canContribute3a) return null;
    if (profile.salaireBrutMensuel <= 0) return null;

    final isIndependantNoLpp =
        profile.archetype == FinancialArchetype.independentNoLpp;
    final max3a =
        isIndependantNoLpp ? _max3aIndependantNoLpp : _max3aSalarieLpp;
    final annual3a = profile.total3aMensuel * 12;
    final gap = max3a - annual3a;

    if (gap > 0) {
      return 'Tu pourrais optimiser ${_formatSwiss(gap)}\u00a0CHF cette année. '
          'On regarde ensemble\u00a0?';
    }

    return null;
  }

  // ── Priority 4: Profile completeness < 50% ──

  static String? _tryProfileCompleteness(
    CoachProfile profile,
    DateTime effectiveNow,
  ) {
    final confidence =
        ConfidenceScorer.scoreEnhanced(profile, now: effectiveNow);
    if (confidence.completeness < 50) {
      return 'Quelques données de plus et MINT devient vraiment précis.';
    }
    return null;
  }

  // ── Helpers ──

  /// Map FactType to a user-friendly French label for the opener.
  static String _factTypeLabel(FactType factType) {
    switch (factType) {
      case FactType.salary:
        return 'de salaire';
      case FactType.lppCapital:
      case FactType.lppRachatMax:
        return 'LPP';
      case FactType.threeACapital:
        return '3a';
      case FactType.avsContributionYears:
        return 'AVS';
      case FactType.taxRate:
        return 'fiscal';
      case FactType.mortgageDebt:
        return 'hypothécaire';
      case FactType.canton:
      case FactType.civilStatus:
      case FactType.employmentStatus:
      case FactType.lifeEvent:
      case FactType.userDecision:
      case FactType.coachPreference:
      case FactType.alertAcknowledged:
        return 'de profil';
    }
  }

  /// Format a number with Swiss apostrophe separator (e.g., 7'258).
  static String _formatSwiss(double value) {
    final rounded = value.round();
    final str = rounded.toString();
    final buffer = StringBuffer();
    final offset = str.length % 3;
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (i - offset) % 3 == 0 && i != str.length) {
        buffer.write("'");
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }
}
