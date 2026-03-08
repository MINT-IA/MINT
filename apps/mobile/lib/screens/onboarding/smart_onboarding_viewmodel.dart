import 'package:flutter/foundation.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/minimal_profile_models.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';
import 'package:mint_mobile/services/minimal_profile_service.dart';
import 'package:mint_mobile/services/chiffre_choc_selector.dart';

/// ViewModel for the Smart Onboarding flow (Lot 2 — Value-First).
///
/// Manages state for the 5-question step and the chiffre choc reveal step.
/// Calls [MinimalProfileService.compute] and [ChiffreChocSelector.select]
/// to produce the first impactful number within 30 seconds.
///
/// Step 1: 5 core inputs (age, grossSalary, canton, employmentStatus, nationalityGroup).
/// Step 2+: optional enrichment fields that improve confidence.
///
/// AVS gaps / lacunes are NOT collected here — source of truth is the
/// extrait AVS uploaded via StepOcrUpload (AvsExtractParser).
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
  /// AVS gap details come from extrait AVS upload — not asked in onboarding.
  String? nationalityGroup;

  /// Specific country code if nationalityGroup == 'OTHER' (e.g. 'US', 'BR').
  String? nationalityCountry;

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
    if (value == 'CH') nationalityCountry = null;
    notifyListeners();
  }

  void setNationalityCountry(String? value) {
    nationalityCountry = value;
    notifyListeners();
  }

  // ─── Literacy calibration ─────────────────────────────────────────────────

  /// Score brut 0-3 derive des 3 questions de calibrage en StepQuestions.
  int _literacyScore = 0;

  /// Niveau de culture financiere derive du score de calibrage.
  /// 0-1 = beginner, 2 = intermediate, 3 = advanced.
  FinancialLiteracyLevel get literacyLevel {
    if (_literacyScore >= 3) return FinancialLiteracyLevel.advanced;
    if (_literacyScore == 2) return FinancialLiteracyLevel.intermediate;
    return FinancialLiteracyLevel.beginner;
  }

  void setLiteracyScore(int score) {
    _literacyScore = score.clamp(0, 3);
    notifyListeners();
  }

  // ─── OCR result ───────────────────────────────────────────────────────────

  /// Champs extraits lors d'un scan OCR dans StepOcrUpload.
  /// Null si aucun scan n'a ete effectue.
  ExtractionResult? ocrResult;

  /// Applique un resultat OCR au profil.
  ///
  /// Mappe les champs extraits vers les setters du ViewModel.
  /// Les valeurs avec confidence < 0.50 sont ignorees (trop incertaines).
  /// Ne stocke jamais le document source — seules les donnees extraites
  /// sont conservees en memoire (LPD art. 6 — minimisation des donnees).
  void applyOcrResult(ExtractionResult result) {
    ocrResult = result;
    for (final field in result.fields) {
      if (field.confidence < 0.50) continue;
      final value = field.value;
      switch (field.fieldName) {
        case 'lpp_total':
          if (value is num) setExistingLpp(value.toDouble());
        case 'epargne_3a':
          if (value is num) setExisting3a(value.toDouble());
        default:
          break;
      }
    }
    // Recompute after OCR to refresh confidence score and projections.
    // setExisting* already call compute() individually, but if no field
    // matched (e.g. empty scan), we still need to notify.
    if (hasResult) {
      compute();
    } else {
      notifyListeners();
    }
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
