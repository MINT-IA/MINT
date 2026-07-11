import 'package:mint_mobile/constants/social_insurance.dart';

/// LPP contribution-rate helpers.
///
/// Legal basis: LPP art. 16. The statutory age credit is a total
/// employee+employer rate; this helper applies the employer share declared by
/// a concrete plan and returns the employee-side percentage points.
class LppContributionCalculator {
  const LppContributionCalculator._();

  static double estimateEmployeeRatePct({
    required int age,
    required double employerSharePct,
  }) {
    final totalRatePct = getLppBonificationRate(age) * 100;
    return totalRatePct * (100 - employerSharePct) / 100;
  }
}
