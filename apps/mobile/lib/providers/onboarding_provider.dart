import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mint_mobile/data/cantonal_data.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/screens/advisor/onboarding/onboarding_constants.dart';
import 'package:mint_mobile/services/forecaster_service.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/services/tax_estimator_service.dart';

class OnboardingProvider extends ChangeNotifier {
  String? stressChoice;
  String? canton;
  String? employmentStatus;
  String? householdType;
  String? mainGoal;

  int? birthYear;
  double? incomeMonthly;
  double? taxProvisionMonthly;
  double? lamalPremiumMonthly;
  double? otherFixedCostsMonthly;

  String? draftBirthYear;
  String? draftIncome;
  String? draftTaxProvision;
  String? draftLamal;
  String? draftOtherFixed;

  int currentStep = 0;
  bool isCompleted = false;
  bool hasSavedWizardProgress = false;
  int savedWizardProgress = 0;

  String variant = 'control';
  Map<String, int> variantMetrics = const {};

  Timer? _autoSaveDebounce;
  bool _isDisposed = false;

  bool get canAdvanceFromStep1 => stressChoice != null;

  bool get _isBirthYearValid {
    if (birthYear == null) return false;
    final maxYear = DateTime.now().year - 16;
    return birthYear! >= 1940 && birthYear! <= maxYear;
  }

  bool get canAdvanceFromStep2 => _isBirthYearValid && canton != null;

  bool get canAdvanceFromStep3 {
    return (incomeMonthly ?? 0) > 0 &&
        employmentStatus != null &&
        householdType != null;
  }

  bool get canAdvanceFromStep4 => mainGoal != null;

  int? get age {
    if (birthYear == null) return null;
    return DateTime.now().year - birthYear!;
  }

  int get yearsToRetirement {
    final value = age;
    if (value == null) return 0;
    return (65 - value).clamp(0, 60);
  }

  Future<void> init() async {
    await Future.wait([initExperimentContext(), initFromPersistence()]);
  }

  Future<void> initExperimentContext() async {
    try {
      variant =
          await ReportPersistenceService.getOrCreateMiniOnboardingVariant();
      variantMetrics =
          await ReportPersistenceService.loadMiniOnboardingMetrics(variant);
      _safeNotify();
    } catch (_) {
      // keep defaults
    }
  }

  Future<void> initFromPersistence() async {
    final savedAnswers = await ReportPersistenceService.loadAnswers();
    if (savedAnswers.isEmpty) return;

    _hydrateFromSavedAnswers(savedAnswers);
    hasSavedWizardProgress = true;
    savedWizardProgress =
        ((savedAnswers.length / OnboardingConstants.wizardTotalQuestions) * 100)
            .round()
            .clamp(0, 99);
    currentStep = computeResumeStep();
    _safeNotify();
  }

  void _hydrateFromSavedAnswers(Map<String, dynamic> answers) {
    stressChoice = answers['q_financial_stress_check'] as String?;
    canton = answers['q_canton'] as String?;
    employmentStatus = answers['q_employment_status'] as String?;
    householdType = answers['q_household_type'] as String?;
    mainGoal = answers['q_main_goal'] as String?;

    birthYear = _toInt(answers['q_birth_year']);
    incomeMonthly = _toDouble(answers['q_net_income_period_chf']);
    taxProvisionMonthly = _toDouble(answers['q_tax_provision_monthly_chf']);
    lamalPremiumMonthly = _toDouble(answers['q_lamal_premium_monthly_chf']);
    otherFixedCostsMonthly =
        _toDouble(answers['q_other_fixed_costs_monthly_chf']);

    draftBirthYear = answers['mini_draft_birth_year']?.toString();
    draftIncome = answers['mini_draft_income']?.toString();
    draftTaxProvision = answers['mini_draft_tax_provision']?.toString();
    draftLamal = answers['mini_draft_lamal']?.toString();
    draftOtherFixed = answers['mini_draft_other_fixed']?.toString();

    if (householdType == null) {
      final civilStatus = answers['q_civil_status'] as String?;
      final children = _toInt(answers['q_children']) ?? 0;
      if (civilStatus == 'married' || civilStatus == 'concubinage') {
        householdType = children > 0 ? 'family' : 'couple';
      } else {
        householdType = 'single';
      }
    }
  }

  int computeResumeStep() {
    if (!canAdvanceFromStep1) return 0;
    if (!canAdvanceFromStep2) return 1;
    if (!canAdvanceFromStep3) return 2;
    if (!canAdvanceFromStep4) return 3;
    return 3;
  }

  void setCurrentStep(int value) {
    currentStep = value.clamp(0, OnboardingConstants.totalSteps - 1);
    _safeNotify();
  }

  void setStressChoice(String? value) {
    stressChoice = value;
    scheduleAutoSave('stress_selected');
    _safeNotify();
  }

  void setBirthYearDraft(String value) {
    draftBirthYear = value.trim();
    birthYear = _toInt(value);
    scheduleAutoSave('birth_year_changed');
    _safeNotify();
  }

  void setCanton(String? value) {
    canton = value;
    scheduleAutoSave('canton_changed');
    _safeNotify();
  }

  void setIncomeDraft(String value) {
    draftIncome = value.trim();
    incomeMonthly = _toDouble(value);
    scheduleAutoSave('income_changed');
    _safeNotify();
  }

  void setEmploymentStatus(String? value) {
    employmentStatus = value;
    scheduleAutoSave('employment_changed');
    _safeNotify();
  }

  void setHouseholdType(String? value) {
    householdType = value;
    scheduleAutoSave('household_changed');
    _safeNotify();
  }

  void setMainGoal(String? value) {
    mainGoal = value;
    scheduleAutoSave('goal_selected');
    _safeNotify();
  }

  void setTaxProvisionDraft(String value) {
    draftTaxProvision = value.trim();
    taxProvisionMonthly = _toDouble(value);
    scheduleAutoSave('fixed_cost_changed');
    _safeNotify();
  }

  void setLamalDraft(String value) {
    draftLamal = value.trim();
    lamalPremiumMonthly = _toDouble(value);
    scheduleAutoSave('fixed_cost_changed');
    _safeNotify();
  }

  void setOtherFixedDraft(String value) {
    draftOtherFixed = value.trim();
    otherFixedCostsMonthly = _toDouble(value);
    scheduleAutoSave('fixed_cost_changed');
    _safeNotify();
  }

  String suggestGoalFromStress() {
    switch (stressChoice) {
      case 'budget':
      case 'debt':
        return 'debt_free';
      case 'tax':
        return 'real_estate';
      case 'pension':
      default:
        return 'retirement';
    }
  }

  String civilStatusForHousehold(String value) {
    switch (value) {
      case 'couple':
      case 'family':
        return 'married';
      default:
        return 'single';
    }
  }

  int childrenCountForHousehold(String value) {
    return value == 'family' ? 1 : 0;
  }

  int adultCountForHousehold(String value) {
    return value == 'single' ? 1 : 2;
  }

  double estimateLamalFromCanton(String cantonCode, {String? household}) {
    final mode = household ?? householdType ?? 'single';
    final baseAdultPremium =
        OnboardingConstants.highLamalCantons.contains(cantonCode)
            ? 520.0
            : OnboardingConstants.lowLamalCantons.contains(cantonCode)
                ? 350.0
                : 430.0;
    final adults = adultCountForHousehold(mode);
    final children = childrenCountForHousehold(mode);
    final childPremium = (baseAdultPremium * 0.27).roundToDouble();
    return (baseAdultPremium * adults) + (childPremium * children);
  }

  void prefillFixedCostsEstimates() {
    if ((incomeMonthly ?? 0) <= 0 || canton == null) return;
    final civil = civilStatusForHousehold(householdType ?? 'single');
    final children = childrenCountForHousehold(householdType ?? 'single');
    final currentAge = age?.clamp(18, 80) ?? 35;

    final monthlyTax = TaxEstimatorService.estimateMonthlyProvision(
      TaxEstimatorService.estimateAnnualTax(
        netMonthlyIncome: incomeMonthly!,
        cantonCode: canton!,
        civilStatus: civil,
        childrenCount: children,
        age: currentAge,
        isSourceTaxed: false,
      ),
    );

    taxProvisionMonthly ??= monthlyTax;
    lamalPremiumMonthly ??= estimateLamalFromCanton(canton!);
    draftTaxProvision ??= monthlyTax.round().toString();
    draftLamal ??= lamalPremiumMonthly?.round().toString();

    scheduleAutoSave('fixed_cost_prefill');
    _safeNotify();
  }

  Map<String, dynamic> buildAnswersSnapshot() {
    final snapshot = <String, dynamic>{};

    if (stressChoice != null) {
      snapshot['q_financial_stress_check'] = stressChoice;
    }
    if (_isBirthYearValid) {
      snapshot['q_birth_year'] = birthYear;
    }
    if (canton != null) {
      snapshot['q_canton'] = canton;
    }
    if ((incomeMonthly ?? 0) > 0) {
      snapshot['q_net_income_period_chf'] = incomeMonthly;
    }
    if (employmentStatus != null) {
      snapshot['q_employment_status'] = employmentStatus;
    }

    final household = householdType ?? 'single';
    snapshot['q_household_type'] = household;
    snapshot['q_civil_status'] = civilStatusForHousehold(household);
    snapshot['q_children'] = childrenCountForHousehold(household);

    if ((taxProvisionMonthly ?? 0) > 0) {
      snapshot['q_tax_provision_monthly_chf'] = taxProvisionMonthly;
    }
    if ((lamalPremiumMonthly ?? 0) > 0) {
      snapshot['q_lamal_premium_monthly_chf'] = lamalPremiumMonthly;
    }
    if ((otherFixedCostsMonthly ?? 0) > 0) {
      snapshot['q_other_fixed_costs_monthly_chf'] = otherFixedCostsMonthly;
    }
    if (mainGoal != null) {
      snapshot['q_main_goal'] = mainGoal;
    }

    if (employmentStatus == 'employee' &&
        (incomeMonthly ?? 0) * 12 > OnboardingConstants.lppAccessThreshold) {
      snapshot['q_has_pension_fund'] = 'yes';
    }

    if ((draftBirthYear ?? '').isNotEmpty) {
      snapshot['mini_draft_birth_year'] = draftBirthYear;
    }
    if ((draftIncome ?? '').isNotEmpty) {
      snapshot['mini_draft_income'] = draftIncome;
    }
    if ((draftTaxProvision ?? '').isNotEmpty) {
      snapshot['mini_draft_tax_provision'] = draftTaxProvision;
    }
    if ((draftLamal ?? '').isNotEmpty) {
      snapshot['mini_draft_lamal'] = draftLamal;
    }
    if ((draftOtherFixed ?? '').isNotEmpty) {
      snapshot['mini_draft_other_fixed'] = draftOtherFixed;
    }

    return snapshot;
  }

  Future<void> autoSave({required String reason}) async {
    if (_isDisposed || isCompleted) return;
    final snapshot = buildAnswersSnapshot();
    if (snapshot.isEmpty) return;
    final existing = await ReportPersistenceService.loadAnswers();
    await ReportPersistenceService.saveAnswers({...existing, ...snapshot});
    // reason kept for parity with current analytics pipeline
    if (kDebugMode && reason.isEmpty) {
      debugPrint('[OnboardingProvider] autosave called without reason');
    }
  }

  void scheduleAutoSave(String reason) {
    if (_isDisposed || isCompleted) return;
    _autoSaveDebounce?.cancel();
    _autoSaveDebounce = Timer(OnboardingConstants.autoSaveDebounce, () {
      unawaited(autoSave(reason: reason));
    });
  }

  Future<Map<String, dynamic>?> completeMiniOnboarding() async {
    if (!(canAdvanceFromStep1 &&
        canAdvanceFromStep2 &&
        canAdvanceFromStep3 &&
        canAdvanceFromStep4)) {
      return null;
    }

    final answers = buildAnswersSnapshot();
    final existing = await ReportPersistenceService.loadAnswers();
    final merged = {...existing, ...answers};
    await ReportPersistenceService.saveAnswers(merged);
    await ReportPersistenceService.setMiniOnboardingCompleted(true);

    isCompleted = true;
    _safeNotify();
    return merged;
  }

  Map<String, dynamic>? computeStep2AhaData() {
    if (!_isBirthYearValid || canton == null) return null;

    final cantonProfile = CantonalDataService.getByCode(canton);
    final swissAvg = CantonalDataService.getByCode(null).averageMarginalRate;
    final avgRate = cantonProfile.averageMarginalRate;
    final deltaRate = avgRate - swissAvg;

    return {
      'age': age,
      'years_to_retirement': yearsToRetirement,
      'canton_code': canton,
      'canton_name': cantonProfile.name,
      'avg_rate_percent': avgRate * 100,
      'tax_on_100k': (avgRate * 100000).round(),
      'delta_vs_ch_percent': deltaRate * 100,
      'annual_delta_on_100k': (deltaRate * 100000).round(),
    };
  }

  Map<String, dynamic>? computePreviewProjection() {
    if (!_isBirthYearValid || canton == null || (incomeMonthly ?? 0) <= 0) {
      return null;
    }

    final employment = employmentStatus ?? 'employee';
    final hasPensionFund = employment == 'employee' &&
        incomeMonthly! * 12 > OnboardingConstants.lppAccessThreshold;
    final monthlySavings =
        (incomeMonthly! * OnboardingConstants.defaultSavingsRate)
            .clamp(
              OnboardingConstants.minMonthlySavingsFloor,
              OnboardingConstants.maxMonthlySavingsCap,
            )
            .toDouble();

    final answers = <String, dynamic>{
      'q_birth_year': birthYear,
      'q_canton': canton,
      'q_pay_frequency': 'monthly',
      'q_net_income_period_chf': incomeMonthly,
      'q_employment_status': employment,
      'q_has_pension_fund': hasPensionFund ? 'yes' : 'no',
      'q_savings_monthly': monthlySavings,
      'q_savings_allocation': const ['epargne_libre'],
      'q_main_goal': mainGoal ?? 'retirement',
      'q_household_type': householdType ?? 'single',
    };

    final profile = CoachProfile.fromWizardAnswers(answers);
    final projection = ForecasterService.project(
      profile: profile,
      targetDate: profile.goalA.targetDate,
    );

    return {
      'targetLabel': profile.goalA.label,
      'prudent': projection.prudent.capitalFinal,
      'base': projection.base.capitalFinal,
      'optimiste': projection.optimiste.capitalFinal,
      'yearsLeft': yearsToRetirement,
    };
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString().trim());
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    final raw = value.toString().replaceAll("'", '').replaceAll(' ', '').trim();
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  void _safeNotify() {
    if (_isDisposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _autoSaveDebounce?.cancel();
    super.dispose();
  }
}
