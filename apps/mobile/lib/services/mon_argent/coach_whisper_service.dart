import 'package:mint_mobile/domain/budget/budget_inputs.dart';
import 'package:mint_mobile/domain/budget/budget_plan.dart';
import 'package:mint_mobile/models/budget_snapshot.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/mon_argent/patrimoine_aggregator.dart';

/// Deterministic coach whisper for the Mon argent tab.
///
/// Returns a single contextual sentence based on simple rules.
/// Returns null when no rule matches (silence = no noise).
/// Zero LLM, zero backend — pure function with 4-5 conditions.
class CoachWhisperService {
  CoachWhisperService._();

  /// Evaluate whisper rules. Returns null if nothing to say.
  static String? evaluate({
    BudgetSnapshot? budgetSnapshot,
    required BudgetInputs? budgetInputs,
    required BudgetPlan? budgetPlan,
    required PatrimoineSummary patrimoine,
    required CoachProfile? profile,
  }) {
    // Rule 1: Budget deficit — urgent. BudgetPlan.available is an allocation
    // amount and is intentionally non-negative, so use signed cashflow here.
    if (_signedMonthlyFree(budgetSnapshot, budgetInputs, budgetPlan) < 0) {
      return 'Mois serré. Regarde tes dépenses fixes.';
    }

    // Rule 2: Good month + 3a opportunity
    if ((budgetSnapshot != null || budgetPlan != null) && profile != null) {
      final salary = profile.salaireBrutMensuel;
      final available =
          budgetSnapshot?.present.monthlyFree ?? budgetPlan?.available ?? 0;
      if (salary > 0 && available > salary * 0.15) {
        final suggestion = (available * 0.25).round();
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
    final fixed = inputs.housingCost +
        inputs.healthInsurance +
        inputs.taxProvision +
        inputs.debtPayments +
        inputs.otherFixedCosts;
    return fixed > 0 ? fixed : inputs.netIncome;
  }

  static double _signedMonthlyFree(
    BudgetSnapshot? snapshot,
    BudgetInputs? inputs,
    BudgetPlan? plan,
  ) {
    if (snapshot != null) return snapshot.present.monthlyFree;
    if (inputs == null) return 0;
    final fixed = inputs.housingCost +
        inputs.healthInsurance +
        inputs.taxProvision +
        inputs.debtPayments +
        inputs.otherFixedCosts;
    return inputs.netIncome - fixed - (plan?.future ?? 0);
  }
}
