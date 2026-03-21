// ────────────────────────────────────────────────────────────
//  LIFECYCLE DETECTOR — S57 / Phase 2 "Le Compagnon"
// ────────────────────────────────────────────────────────────
//
// Pure function service — no side effects, deterministic, testable.
//
// Detects the user's lifecycle phase from CoachProfile data:
//   - Primary signal: age from birthYear
//   - Override: employmentStatus == 'retraite' → forces retraite/transmission
//   - Override: early retirement target within 10 years (age 50+) → transition
//
// See lifecycle_phase.dart for phase definitions.
// See docs/ROADMAP_V2.md §S57.
// ────────────────────────────────────────────────────────────
library;

import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/lifecycle/lifecycle_adaptation.dart';
import 'package:mint_mobile/services/lifecycle/lifecycle_phase.dart';

/// Detects lifecycle phase and provides content adaptation hints.
///
/// All methods are static — no instantiation needed.
class LifecycleDetector {
  LifecycleDetector._();

  /// Detect lifecycle phase from a CoachProfile.
  ///
  /// Uses age (from [CoachProfile.birthYear]) as the primary signal.
  /// Secondary signals:
  /// - [CoachProfile.employmentStatus] == 'retraite' → forces retraite/transmission
  /// - [CoachProfile.targetRetirementAge] within 10 years + age >= 50 → transition
  ///
  /// If [birthYear] is null on the profile, defaults to [LifecyclePhase.construction].
  ///
  /// [now] parameter enables deterministic testing. Defaults to [DateTime.now()].
  static LifecyclePhase detect(CoachProfile profile, {DateTime? now}) {
    // Delegate to LifecyclePhaseService-compatible detection logic.
    // birthYear is non-nullable on CoachProfile (has a default via required
    // constructor), but the nullable ConjointProfile wrapper version may differ.
    final currentYear = (now ?? DateTime.now()).year;
    final age = currentYear - profile.birthYear;

    // Override: already retired
    if (profile.employmentStatus == 'retraite') {
      return age >= 75 ? LifecyclePhase.transmission : LifecyclePhase.retraite;
    }

    // Override: early retirement target approaching
    final targetRetirement =
        profile.targetRetirementAge ?? avsAgeReferenceHomme;
    final yearsLeft = targetRetirement - age;
    if (age >= 50 && yearsLeft > 0 && yearsLeft <= 10) {
      return LifecyclePhase.transition;
    }

    // Standard age-based detection
    return _phaseFromAge(age);
  }

  /// Detect lifecycle phase for a user with a nullable birthYear.
  ///
  /// If [birthYear] is null, returns [LifecyclePhase.construction] as the safe
  /// default for an unknown-age user.
  static LifecyclePhase detectFromBirthYear(
    int? birthYear, {
    String? employmentStatus,
    int? targetRetirementAge,
    DateTime? now,
  }) {
    if (birthYear == null) return LifecyclePhase.construction;

    final currentYear = (now ?? DateTime.now()).year;
    final age = currentYear - birthYear;

    // Override: already retired
    if (employmentStatus == 'retraite') {
      return age >= 75 ? LifecyclePhase.transmission : LifecyclePhase.retraite;
    }

    // Override: early retirement target approaching
    final targetRetirement = targetRetirementAge ?? avsAgeReferenceHomme;
    final yearsLeft = targetRetirement - age;
    if (age >= 50 && yearsLeft > 0 && yearsLeft <= 10) {
      return LifecyclePhase.transition;
    }

    return _phaseFromAge(age);
  }

  /// Get the content adaptation hints for a given phase.
  ///
  /// Returns the pre-computed [LifecycleAdaptation] from [lifecycleAdaptations].
  static LifecycleAdaptation adapt(LifecyclePhase phase) {
    return lifecycleAdaptations[phase]!;
  }

  /// Core age-to-phase mapping.
  ///
  /// Boundaries:
  /// - < 25  → demarrage
  /// - 25-34 → construction
  /// - 35-44 → acceleration
  /// - 45-54 → consolidation
  /// - 55-60 → transition (pre-retirement countdown)
  /// - 61-67 → retraite
  /// - > 67  → transmission
  static LifecyclePhase _phaseFromAge(int age) {
    if (age < 25) return LifecyclePhase.demarrage;
    if (age < 35) return LifecyclePhase.construction;
    if (age < 45) return LifecyclePhase.acceleration;
    if (age < 55) return LifecyclePhase.consolidation;
    if (age <= 60) return LifecyclePhase.transition;
    if (age <= 67) return LifecyclePhase.retraite;
    return LifecyclePhase.transmission;
  }
}
