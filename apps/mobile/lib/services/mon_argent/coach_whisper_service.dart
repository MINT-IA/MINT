import 'package:mint_mobile/domain/budget/budget_inputs.dart';
import 'package:mint_mobile/domain/budget/budget_plan.dart';
import 'package:mint_mobile/domain/budget/present_budget_builder.dart';
import 'package:mint_mobile/models/budget_snapshot.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/budget_living_engine.dart';
import 'package:mint_mobile/services/mon_argent/patrimoine_aggregator.dart';

/// Deterministic coach whisper for the Mon argent tab.
///
/// Returns a single contextual sentence based on simple rules.
/// Returns null when no rule matches (silence = no noise).
/// Zero LLM, zero backend — pure function with 4-5 conditions.
class CoachWhisperService {
  CoachWhisperService._();

  /// Evaluate whisper rules. Returns null if nothing to say.
  ///
  /// [now] is injectable for deterministic tests; defaults to the current date
  /// so the 3a-suggestion proration tracks the real calendar.
  static String? evaluate({
    BudgetSnapshot? budgetSnapshot,
    required BudgetInputs? budgetInputs,
    required BudgetPlan? budgetPlan,
    required PatrimoineSummary patrimoine,
    required CoachProfile? profile,
    DateTime? now,
  }) {
    // Rule 1: Budget deficit — urgent. BudgetPlan.available is an allocation
    // amount and is intentionally non-negative, so use signed cashflow here.
    if (_signedMonthlyFree(budgetSnapshot, budgetInputs, budgetPlan) < 0) {
      return 'Mois serré. Regarde tes dépenses fixes.';
    }

    // Rule 2: Good month + 3a opportunity
    if ((budgetSnapshot != null || budgetPlan != null) &&
        profile != null &&
        !profile.hasMaterialConsumerDebtForPriority) {
      final monthlyNet = budgetSnapshot?.present.monthlyNet ??
          (budgetInputs != null
              ? PresentBudgetBuilder.displayChf(budgetInputs.netIncome)
              : profile.salaireBrutMensuel);
      final monthlyFree = budgetSnapshot?.present.monthlyFree ??
          _signedMonthlyFree(budgetSnapshot, budgetInputs, budgetPlan);
      if (monthlyNet > 0 && monthlyFree > monthlyNet * 0.15) {
        // D10 fix \u2014 NEVER suggest the raw free margin as a 3a versement.
        // Route through the SAME canonical clamp the LLM-context path uses
        // (`BudgetLivingEngine.cappedMonthly3aSuggestion`, NEVER #3 reuse):
        // - clamps to the statutory remaining annual room, archetype-aware,
        //   pro-rated over the remaining calendar months;
        // - returns 0 when the ceiling is reached OR the user cannot
        //   contribute (US person / FATCA) \u2192 NO 3a whisper at all (a 0-CHF
        //   suggestion would be a dissonant illogism).
        // Device repro (married swiss, marge 6164): round(6164\u00d70.25)=1541/mois
        // \u2248 2.55\u00d7 the 7258 annual ceiling. Clamped \u2192 \u2264 7258/12 \u2248 605/mois.
        final capped = BudgetLivingEngine.cappedMonthly3aSuggestion(
          profile,
          availableMonthlyMargin: monthlyFree,
          now: now,
        );
        final suggestion = capped.round();
        if (suggestion >= 100) {
          return 'Bon mois. Tu pourrais verser $suggestion\u00a0CHF en 3a.';
        }
      }
    }

    // Rule 3: Emergency fund low
    if (patrimoine.epargneLiquide != null && profile != null) {
      final monthlyExpenses =
          _essentialMonthlyExpenses(budgetSnapshot, budgetInputs);
      if (monthlyExpenses > 0) {
        final months = patrimoine.epargneLiquide!.value / monthlyExpenses;
        if (months < 3) {
          return 'Ton matelas de sécurité couvre ${months.toStringAsFixed(1)} mois. '
              "L'idéal\u00a0: 3-6\u00a0mois.";
        }
      }
    }

    // Rule 4: Patrimoine data very incomplete — contextual scan nudge.
    // Only suggests what isn't already sourced from a certificate, so the
    // hint doesn't parrot "scan LPP" once Julien already scanned his LPP.
    if (patrimoine.completionRatio < 0.34 && !patrimoine.isEmpty) {
      final sources = profile?.dataSources ?? const {};
      final lppScanned =
          sources['prevoyance.avoirLppTotal'] == ProfileDataSource.certificate;
      final troisaScanned =
          sources['prevoyance.avoir3a'] == ProfileDataSource.certificate;
      if (!lppScanned && !troisaScanned) {
        return 'Scanne un certificat LPP ou 3a pour affiner ta vue.';
      }
      if (lppScanned && !troisaScanned) {
        return 'Ton 3a reste à capturer. Scanne ton attestation pour compléter.';
      }
      if (!lppScanned && troisaScanned) {
        return 'Il manque ton certificat LPP. Scanne-le pour compléter.';
      }
      // Both scanned — the patrimoine gap is elsewhere (immo, placements).
      // Silence beats a hint that parrots what's already done.
    }

    // Default: silence. No noise is better than generic advice.
    return null;
  }

  static double _essentialMonthlyExpenses(
    BudgetSnapshot? snapshot,
    BudgetInputs? inputs,
  ) {
    if (snapshot != null) return snapshot.present.monthlyCharges;
    if (inputs == null) return 0;
    final fixed = PresentBudgetBuilder.fixedChargesFromInputs(inputs);
    return fixed > 0
        ? fixed
        : PresentBudgetBuilder.displayChf(inputs.netIncome);
  }

  static double _signedMonthlyFree(
    BudgetSnapshot? snapshot,
    BudgetInputs? inputs,
    BudgetPlan? plan,
  ) {
    if (snapshot != null) return snapshot.present.monthlyFree;
    if (inputs == null) return 0;
    final fixed = PresentBudgetBuilder.fixedChargesFromInputs(inputs);
    return PresentBudgetBuilder.displayChf(inputs.netIncome) -
        fixed -
        PresentBudgetBuilder.displayChf(plan?.future ?? 0);
  }
}
