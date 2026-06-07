import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/models/coach_profile.dart';

/// Computes the current-year 3a deductible room from profile data.
class Pillar3aRoomCalculator {
  Pillar3aRoomCalculator._();

  static double annualCeiling(
    CoachProfile profile, {
    FinancialArchetype? archetype,
  }) {
    final resolvedArchetype = archetype ?? profile.archetype;
    if (resolvedArchetype == FinancialArchetype.independentNoLpp) {
      final incomeBase = profile.independentNetProfessionalIncomeAnnual != null
          ? profile.independentNetProfessionalIncomeAnnual!
          : profile.revenuBrutAnnuel;
      return (incomeBase * pilier3aTauxRevenuSansLpp)
          .clamp(0.0, pilier3aPlafondSansLpp)
          .toDouble();
    }
    return pilier3aPlafondAvecLpp;
  }

  static double plannedAnnualContribution(CoachProfile profile) =>
      profile.total3aMensuel * 12;

  static double remainingAnnualRoom(
    CoachProfile profile, {
    FinancialArchetype? archetype,
  }) {
    final ceiling = annualCeiling(profile, archetype: archetype);
    final planned = plannedAnnualContribution(profile);
    return (ceiling - planned).clamp(0.0, ceiling);
  }
}
