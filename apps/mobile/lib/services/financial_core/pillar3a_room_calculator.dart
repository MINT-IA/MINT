import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/models/coach_profile.dart';

/// Computes the current-year 3a deductible room from profile data.
class Pillar3aRoomCalculator {
  Pillar3aRoomCalculator._();

  static double annualCeiling(
    CoachProfile profile, {
    FinancialArchetype? archetype,
  }) {
    // FATCA eligibility gate (Codex P1) — US persons cannot contribute to 3a
    // (Swiss providers refuse them; CLAUDE.md NEVER #7), so the deductible
    // room is 0. Uses the archetype-aware top-level getter (source of truth,
    // CoachProfile.canContribute3a), NOT the prevoyance fallback which defaults
    // to true. remainingAnnualRoom flows through this and is gated too.
    if (!profile.canContribute3a) return 0.0;

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
