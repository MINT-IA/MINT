import 'package:mint_mobile/models/coach_profile.dart';

/// Read-only guards for independent-scenario facts.
///
/// These helpers intentionally require user-provided fields: derived or
/// injected `CoachProfile` values must not unlock calculators as known ledger
/// facts.
class IndependentLedgerFacts {
  IndependentLedgerFacts._();

  static double? selfEmployedAnnualIncome(CoachProfile? profile) {
    if (profile == null) return null;
    if (!profile.userProvidedFields.contains('selfEmployedNetIncome')) {
      return null;
    }
    final income = profile.selfEmployedNetIncome;
    if (income == null || income <= 0) return null;
    return income.toDouble();
  }

  static int? age(
    CoachProfile? profile, {
    required int min,
    required int max,
  }) {
    if (profile == null || !profile.userProvidedFields.contains('age')) {
      return null;
    }
    final age = profile.ageOrNull;
    if (age == null || age < min || age > max) return null;
    return age;
  }
}
