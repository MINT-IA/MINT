import 'package:mint_mobile/models/coach_profile.dart';

abstract final class CoachContextProfileMapper {
  static Map<String, double> knownValues(CoachProfile profile) {
    final values = <String, double>{};
    final annual3a = profile.total3aMensuel * 12;
    if (annual3a.isFinite && annual3a > 0) {
      values['annual_3a_contribution'] = annual3a;
    }
    final independentIncome = profile.independentNetProfessionalIncomeAnnual;
    if (independentIncome != null &&
        independentIncome.isFinite &&
        independentIncome > 0) {
      values['self_employed_net_income_annual'] = independentIncome;
    }
    return values;
  }

  static List<Map<String, dynamic>> plannedContributions(
    CoachProfile profile,
  ) {
    return profile.plannedContributions
        .where((c) => c.amount.isFinite && c.amount > 0)
        .map(
          (c) => {
            'category': c.category,
            'monthly_amount': c.amount,
            'annual_amount': c.amount * 12,
            'is_automatic': c.isAutomatic,
          },
        )
        .toList(growable: false);
  }

  static String activeGoal(CoachProfile profile) {
    final label = profile.goalA.label.trim();
    if (label.isNotEmpty) return label;
    return profile.goalA.type.name;
  }

  static Map<String, String> dataReliability(CoachProfile profile) {
    return profile.dataSources.map((key, source) => MapEntry(key, source.name));
  }
}
