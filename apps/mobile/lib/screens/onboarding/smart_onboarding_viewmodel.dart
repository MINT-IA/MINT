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

  /// True when the 3 required fields are filled and computation is possible.
  bool get canCompute => canton != null;

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
