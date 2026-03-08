import 'package:flutter/foundation.dart';
import 'package:mint_mobile/models/minimal_profile_models.dart';
import 'package:mint_mobile/services/minimal_profile_service.dart';
import 'package:mint_mobile/services/chiffre_choc_selector.dart';

/// ViewModel for the Smart Onboarding flow (Lot 2 — Value-First).
///
/// Manages state for the 3-question step and the chiffre choc reveal step.
/// Calls [MinimalProfileService.compute] and [ChiffreChocSelector.select]
/// to produce the first impactful number within 30 seconds.
///
/// Step 1: 3 required inputs (age, grossSalary, canton).
/// Step 2+: optional enrichment fields that improve confidence.
///
/// Delegates all financial computation to the shared financial_core.
/// NEVER duplicates calculation logic.
class SmartOnboardingViewModel extends ChangeNotifier {
  // ─── Step 1 data (3 required questions) ──────────────────────────────────

  double grossSalary = 80000;
  int age = 35;
  String? canton;

  /// Employment status: 'salarie', 'independant', 'sans_emploi', 'retraite'.
  /// Impacts 3a ceiling (7'258 vs 36'288), LPP estimation, AVS.
  String? employmentStatus;

  /// Nationality group: 'CH', 'EU', 'OTHER'.
  /// Triggers archetype detection (expat_eu, expat_us, etc.).
  String? nationalityGroup;

  /// Specific country code if nationalityGroup == 'OTHER' (e.g. 'US', 'BR').
  String? nationalityCountry;

  /// Year of arrival in Switzerland (if not Swiss native).
  int? arrivalYear;

  /// Whether a Swiss national lived/worked abroad and interrupted their
  /// AVS/LPP contributions. Triggers the arrival-year sub-question even
  /// when [nationalityGroup] == 'CH'. Maps to q_avs_lacunes_status =
  /// 'lived_abroad' in wizard answers, so [fromWizardAnswers] computes
  /// the correct LPP gap and AVS reduction.
  bool? hasLivedAbroad;

  /// User's stress intention (tap selector, not a data question).
  /// Used to filter coaching tips by relevance.
  String? stressType;

  // ─── Computed results (populated after step 1) ──────────────────────────

  MinimalProfileResult? profile;
  ChiffreChoc? chiffreChoc;

  /// Confidence score in percent (0–100).
  /// Based on ratio of provided fields to total possible fields.
  double confidenceScore = 0;

  // ─── Enrichment data (step 2–3, optional) ────────────────────────────────

  String? householdType;
  double? currentSavings;
  bool? isPropertyOwner;
  double? existing3a;
  double? existingLpp;

  // ─── Guards ──────────────────────────────────────────────────────────────

  /// True when the 4 required fields are filled and computation is possible.
  bool get canCompute => canton != null && employmentStatus != null;

  /// True when a result has been computed at least once.
  bool get hasResult => profile != null && chiffreChoc != null;

  /// Error message if computation failed.
  String? error;

  // ─── Setters with notification ────────────────────────────────────────────

  void setGrossSalary(double value) {
    grossSalary = value;
    notifyListeners();
  }

  void setAge(int value) {
    age = value;
    notifyListeners();
  }

  void setCanton(String? value) {
    canton = value;
    notifyListeners();
  }

  void setEmploymentStatus(String? value) {
    employmentStatus = value;
    if (hasResult) {
      compute();
    } else {
      notifyListeners();
    }
  }

  void setNationalityGroup(String? value) {
    nationalityGroup = value;
    if (value == 'CH') {
      nationalityCountry = null;
      arrivalYear = null;
    }
    notifyListeners();
  }

  void setNationalityCountry(String? value) {
    nationalityCountry = value;
    notifyListeners();
  }

  void setArrivalYear(int? value) {
    arrivalYear = value;
    notifyListeners();
  }

  void setHasLivedAbroad(bool? value) {
    hasLivedAbroad = value;
    if (value == false) arrivalYear = null;
    notifyListeners();
  }

  /// True when the "vécu à l'étranger" toggle should appear (Swiss only).
  bool get showAbroadQuestion => nationalityGroup == 'CH';

  /// True when the arrival year picker should appear.
  /// Triggered for non-Swiss nationalities, OR for Swiss nationals who
  /// explicitly confirmed they lived abroad ([hasLivedAbroad] == true).
  bool get showArrivalYear =>
      nationalityGroup != null &&
      (nationalityGroup != 'CH' || hasLivedAbroad == true);

  void setStressType(String? value) {
    stressType = value;
    notifyListeners();
  }

  void setHouseholdType(String? value) {
    householdType = value;
    if (hasResult) {
      compute(); // compute() calls notifyListeners()
    } else {
      notifyListeners();
    }
  }

  void setCurrentSavings(double? value) {
    currentSavings = value;
    if (hasResult) {
      compute();
    } else {
      notifyListeners();
    }
  }

  void setIsPropertyOwner(bool? value) {
    isPropertyOwner = value;
    if (hasResult) {
      compute();
    } else {
      notifyListeners();
    }
  }

  void setExisting3a(double? value) {
    existing3a = value;
    if (hasResult) {
      compute();
    } else {
      notifyListeners();
    }
  }

  void setExistingLpp(double? value) {
    existingLpp = value;
    if (hasResult) {
      compute();
    } else {
      notifyListeners();
    }
  }

  // ─── Computation ─────────────────────────────────────────────────────────

  /// Compute projection from current inputs.
  ///
  /// Called after step 1 (3 questions) and after each enrichment answer.
  /// Delegates entirely to [MinimalProfileService] and [ChiffreChocSelector].
  void compute() {
    if (!canCompute) return;

    try {
      error = null;

      profile = MinimalProfileService.compute(
        age: age,
        grossSalary: grossSalary,
        canton: canton!,
        employmentStatus: employmentStatus,
        nationalityGroup: nationalityGroup,
        householdType: householdType,
        currentSavings: currentSavings,
        isPropertyOwner: isPropertyOwner,
        existing3a: existing3a,
        existingLpp: existingLpp,
      );

      chiffreChoc = ChiffreChocSelector.select(profile!);

      // Confidence: number of estimated fields reduces the score.
      // Base: 3 provided fields (age, salary, canton) out of 8 total data points.
      const totalFields = 8; // age, salary, canton + 5 optional enrichment fields
      final estimatedCount = profile!.estimatedFields.length;
      final providedCount = totalFields - estimatedCount;
      confidenceScore =
          (providedCount / totalFields * 100).clamp(0.0, 100.0);
    } catch (e) {
      error = 'Erreur de calcul. Verifie tes données et réessaie.';
      profile = null;
      chiffreChoc = null;
      confidenceScore = 0;
    }

    notifyListeners();
  }
}
