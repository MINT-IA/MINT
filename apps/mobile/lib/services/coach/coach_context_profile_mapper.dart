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

  static Map<String, Map<String, String>> dataReliabilityDetails(
    CoachProfile profile,
  ) {
    final details = <String, Map<String, String>>{};
    for (final entry in profile.dataSources.entries) {
      final detail = _detailFor(
        source: entry.value,
        updatedAt: profile.dataTimestamps[entry.key] ?? profile.updatedAt,
      );
      details[entry.key] = detail;
      if (entry.key == 'plannedContributions.3a') {
        details['annual_3a_contribution'] = detail;
      }
    }
    return details;
  }

  static Map<String, String> _detailFor({
    required ProfileDataSource source,
    required DateTime? updatedAt,
  }) {
    return {
      'source': source.name,
      'confidence': _confidenceFor(source),
      'freshness': _freshnessFor(updatedAt),
      if (updatedAt != null) 'updatedAt': updatedAt.toIso8601String(),
    };
  }

  static String _confidenceFor(ProfileDataSource source) {
    return switch (source) {
      ProfileDataSource.estimated => 'estimated',
      ProfileDataSource.userInput => 'known',
      ProfileDataSource.crossValidated => 'known',
      ProfileDataSource.certificate => 'known',
      ProfileDataSource.openBanking => 'known',
    };
  }

  static String _freshnessFor(DateTime? updatedAt) {
    if (updatedAt == null) return 'unknown';
    final age = DateTime.now().difference(updatedAt);
    return age.inDays > 365 ? 'stale' : 'fresh';
  }
}
