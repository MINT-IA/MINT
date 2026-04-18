import 'package:mint_mobile/domain/budget/budget_inputs.dart';
import 'package:mint_mobile/domain/budget/budget_plan.dart';
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
    required BudgetInputs? budgetInputs,
    required BudgetPlan? budgetPlan,
    required PatrimoineSummary patrimoine,
    required CoachProfile? profile,
  }) {
    // Rule 1: Budget deficit — urgent
    if (budgetPlan != null && budgetPlan.available < 0) {
      return 'Mois serré. Regarde tes dépenses fixes.';
    }

    // Rule 2: Good month + 3a opportunity
    if (budgetInputs != null && budgetPlan != null && profile != null) {
      final salary = profile.salaireBrutMensuel;
      final available = budgetPlan.available;
      if (salary > 0 && available > salary * 0.15) {
        final suggestion = (available * 0.25).round();
        if (suggestion >= 100) {
          return 'Bon mois. Tu pourrais verser $suggestion\u00a0CHF en 3a.';
        }
      }
    }

    // Rule 3: Emergency fund low
    if (patrimoine.epargneLiquide != null && profile != null) {
      final monthlyExpenses = budgetInputs?.netIncome ?? 0;
      if (monthlyExpenses > 0) {
        final months = patrimoine.epargneLiquide!.value / monthlyExpenses;
        if (months < 3) {
          return 'Ton matelas de sécurité couvre ${months.toStringAsFixed(1)} mois. '
              "L'idéal\u00a0: 3-6\u00a0mois.";
        }
      }
    }

    // Rule 4: Patrimoine data very incomplete
    if (patrimoine.completionRatio < 0.34 && !patrimoine.isEmpty) {
      return 'Scanne un certificat LPP ou 3a pour affiner ta vue.';
    }

    // Default: silence. No noise is better than generic advice.
    return null;
  }
}
