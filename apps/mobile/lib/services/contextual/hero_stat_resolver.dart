import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/contextual_card.dart';
import 'package:mint_mobile/services/biography/biography_fact.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';

// ────────────────────────────────────────────────────────────
//  HERO STAT RESOLVER — Phase 05 / Interface Contextuelle
// ────────────────────────────────────────────────────────────
//
// Selects the most impactful metric for the hero card (slot 1).
//
// Priority: (1) 3a gap > (2) retirement income > (3) profile completeness
//
// Design: Pure static, zero side effects, zero async.
// See: CTX-01 requirement.
// ────────────────────────────────────────────────────────────

/// Max 3a for salarie with LPP (2025/2026).
const _max3aSalarieLpp = 7258.0;

/// Max 3a for independant without LPP (2025/2026).
const _max3aIndependantNoLpp = 36288.0;

/// Resolves the hero stat card based on profile data.
///
/// Pure static class — no state, no side effects.
class HeroStatResolver {
  HeroStatResolver._();

  /// Resolve the hero stat from profile and biography.
  ///
  /// Priority:
  /// 1. 3a contribution gap (if salary present and gap > 0)
  /// 2. Retirement income projection (if LPP data available)
  /// 3. Profile completeness (fallback)
  static ContextualHeroCard resolve({
    required CoachProfile profile,
    required List<BiographyFact> facts,
    DateTime? now,
  }) {
    // Priority 1: 3a contribution gap
    final gap = _compute3aGap(profile);
    if (gap != null && gap > 0 && profile.salaireBrutMensuel > 0) {
      return ContextualHeroCard(
        label: 'Tu laisses ${_formatSwiss(gap)} CHF/an sur la table en 3a',
        value: _formatSwiss(gap),
        narrative:
            'Soit ${_formatSwiss(gap / 12)} CHF/mois que tu pourrais deduire.',
        route: '/simulators/3a',
      );
    }

    // Priority 2: Retirement income projection
    final monthlyRetirement = _computeMonthlyRetirement(profile);
    if (monthlyRetirement != null && monthlyRetirement > 0) {
      final monthlyNet = profile.revenuBrutAnnuel / 12;
      final percent =
          monthlyNet > 0 ? (monthlyRetirement / monthlyNet * 100) : 0;
      return ContextualHeroCard(
        label: 'Ton revenu projete a la retraite',
        value: '${_formatSwiss(monthlyRetirement)} CHF/mois',
        narrative:
            'Soit ${percent.toStringAsFixed(0)}\u00a0% de ton revenu actuel.',
        route: '/retirement/projection',
      );
    }

    // Priority 3: Profile completeness (fallback)
    final confidence =
        ConfidenceScorer.scoreEnhanced(profile, now: now);
    final completeness = confidence.combined;
    return ContextualHeroCard(
      label: 'Ton profil MINT',
      value: '${completeness.toStringAsFixed(0)}\u00a0%',
      narrative: 'Plus ton profil est complet, plus MINT est precis.',
      route: '/onboarding/quick?section=profile',
    );
  }

  /// Compute the 3a contribution gap.
  ///
  /// Returns null if the user cannot contribute to 3a or has no salary.
  static double? _compute3aGap(CoachProfile profile) {
    if (!profile.canContribute3a) return null;
    if (profile.salaireBrutMensuel <= 0) return null;

    // Determine max 3a based on archetype
    final isIndependantNoLpp =
        profile.archetype == FinancialArchetype.independentNoLpp;

    final max3a = isIndependantNoLpp ? _max3aIndependantNoLpp : _max3aSalarieLpp;

    // Current annual 3a contribution from planned contributions
    final annual3a = profile.total3aMensuel * 12;

    final gap = max3a - annual3a;
    return gap > 0 ? gap : null;
  }

  /// Compute estimated monthly retirement income.
  ///
  /// Returns null if insufficient data for projection.
  static double? _computeMonthlyRetirement(CoachProfile profile) {
    final renteLpp = profile.prevoyance.projectedRenteLpp;
    final renteAvs = profile.prevoyance.renteAVSEstimeeMensuelle;

    if (renteLpp == null && renteAvs == null) return null;

    final monthlyLpp = (renteLpp ?? 0) / 12;
    final monthlyAvs = renteAvs ?? 0;

    final total = monthlyLpp + monthlyAvs;
    return total > 0 ? total : null;
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
