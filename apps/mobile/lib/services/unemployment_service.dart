import 'package:mint_mobile/services/financial_core/unemployment_calculator.dart';

// ────────────────────────────────────────────────────────────
//  UNEMPLOYMENT SERVICE — Sprint S19 / Chomage (LACI) + Premier emploi
// ────────────────────────────────────────────────────────────
//
// Pure Dart service for unemployment benefits (LACI art. 28-30).
//   1. calculateBenefits — eligibility, rate, duration, timeline
//
// All constants match the backend exactly. UI copy is localized by callers.
// ────────────────────────────────────────────────────────────

/// Result of unemployment benefits calculation.
class UnemploymentResult {
  final bool eligible;
  final UnemploymentIneligibilityReason? ineligibilityReason;
  final String? raisonNonEligible;
  final double tauxIndemnite;
  final double gainAssureRetenu;
  final double indemniteJournaliere;
  final double indemniteMensuelle;
  final int nombreIndemnites;
  final double dureeMois;
  final int delaiCarenceJours;
  final double perteMensuelle;
  final String premierEclairage;
  final List<UnemploymentTimelineItem> timeline;

  const UnemploymentResult({
    required this.eligible,
    this.ineligibilityReason,
    this.raisonNonEligible,
    required this.tauxIndemnite,
    required this.gainAssureRetenu,
    required this.indemniteJournaliere,
    required this.indemniteMensuelle,
    required this.nombreIndemnites,
    required this.dureeMois,
    required this.delaiCarenceJours,
    required this.perteMensuelle,
    required this.premierEclairage,
    required this.timeline,
  });
}

/// A single step in the unemployment timeline.
class UnemploymentTimelineItem {
  final int jour;
  final UnemploymentTimelineStep step;
  final UnemploymentTimelineUrgency urgence;

  const UnemploymentTimelineItem({
    required this.jour,
    required this.step,
    required this.urgence,
  });
}

enum UnemploymentTimelineStep {
  registerOrp,
  fileClaim,
  waitingPeriodEnds,
  budgetReview,
  lppTransfer,
  pause3a,
  lamalReview,
  orpReview,
}

enum UnemploymentTimelineUrgency {
  immediate,
  week1,
  month1,
  months2to3,
}

/// Service for unemployment (LACI) calculations.
///
/// All constants match the backend exactly.
class UnemploymentService {
  UnemploymentService._();

  /// Calculate unemployment benefits (LACI art. 28-30).
  static UnemploymentResult calculateBenefits({
    required double gainAssureMensuel,
    required int age,
    required int moisCotisation,
    bool hasChildren = false,
    bool hasDisability = false,
  }) {
    final core = UnemploymentCalculator.compute(
      monthlyInsuredEarnings: gainAssureMensuel,
      age: age,
      contributionMonths: moisCotisation,
      hasChildren: hasChildren,
      hasDisability: hasDisability,
    );

    if (!core.eligible &&
        core.ineligibilityReason ==
            UnemploymentIneligibilityReason.invalidMonthlyEarnings) {
      return UnemploymentResult(
        eligible: false,
        ineligibilityReason: core.ineligibilityReason,
        tauxIndemnite: 0,
        gainAssureRetenu: 0,
        indemniteJournaliere: 0,
        indemniteMensuelle: 0,
        nombreIndemnites: 0,
        dureeMois: 0,
        delaiCarenceJours: core.waitingPeriodDays,
        perteMensuelle: 0,
        premierEclairage: '',
        timeline: _buildTimeline(),
      );
    }

    if (!core.eligible &&
        core.ineligibilityReason ==
            UnemploymentIneligibilityReason.insufficientContributions) {
      return UnemploymentResult(
        eligible: false,
        ineligibilityReason: core.ineligibilityReason,
        tauxIndemnite: 0,
        gainAssureRetenu: 0,
        indemniteJournaliere: 0,
        indemniteMensuelle: 0,
        nombreIndemnites: 0,
        dureeMois: 0,
        delaiCarenceJours: core.waitingPeriodDays,
        perteMensuelle: 0,
        premierEclairage: '',
        timeline: _buildTimeline(),
      );
    }

    return UnemploymentResult(
      eligible: true,
      tauxIndemnite: core.rate,
      gainAssureRetenu: core.retainedMonthlyEarnings,
      indemniteJournaliere: core.dailyBenefit,
      indemniteMensuelle: core.monthlyBenefit,
      nombreIndemnites: core.dailyBenefitCount,
      dureeMois: core.coverageMonths,
      delaiCarenceJours: core.waitingPeriodDays,
      perteMensuelle: core.monthlyLoss,
      premierEclairage: '',
      timeline: _buildTimeline(),
    );
  }

  /// Build the unemployment action timeline.
  static List<UnemploymentTimelineItem> _buildTimeline() {
    return const [
      UnemploymentTimelineItem(
        jour: 0,
        step: UnemploymentTimelineStep.registerOrp,
        urgence: UnemploymentTimelineUrgency.immediate,
      ),
      UnemploymentTimelineItem(
        jour: 1,
        step: UnemploymentTimelineStep.fileClaim,
        urgence: UnemploymentTimelineUrgency.immediate,
      ),
      UnemploymentTimelineItem(
        jour: 5,
        step: UnemploymentTimelineStep.waitingPeriodEnds,
        urgence: UnemploymentTimelineUrgency.week1,
      ),
      UnemploymentTimelineItem(
        jour: 7,
        step: UnemploymentTimelineStep.budgetReview,
        urgence: UnemploymentTimelineUrgency.week1,
      ),
      UnemploymentTimelineItem(
        jour: 30,
        step: UnemploymentTimelineStep.lppTransfer,
        urgence: UnemploymentTimelineUrgency.month1,
      ),
      UnemploymentTimelineItem(
        jour: 30,
        step: UnemploymentTimelineStep.pause3a,
        urgence: UnemploymentTimelineUrgency.month1,
      ),
      UnemploymentTimelineItem(
        jour: 60,
        step: UnemploymentTimelineStep.lamalReview,
        urgence: UnemploymentTimelineUrgency.months2to3,
      ),
      UnemploymentTimelineItem(
        jour: 90,
        step: UnemploymentTimelineStep.orpReview,
        urgence: UnemploymentTimelineUrgency.months2to3,
      ),
    ];
  }

  // ════════════════════════════════════════════════════════════
  //  HELPERS
  // ════════════════════════════════════════════════════════════

  /// Format a number with Swiss apostrophe separators.
  static String _formatNumber(double value) {
    final intVal = value.round();
    final str = intVal.abs().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write("'");
      }
      buffer.write(str[i]);
    }
    return '${intVal < 0 ? '-' : ''}${buffer.toString()}';
  }

  /// Format CHF with Swiss apostrophe.
  static String formatChf(double value) {
    return 'CHF\u00A0${_formatNumber(value)}';
  }
}
