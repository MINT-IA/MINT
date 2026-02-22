import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mint_mobile/data/cantonal_data.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/screens/advisor/onboarding/onboarding_constants.dart';
import 'package:mint_mobile/services/forecaster_service.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/services/tax_estimator_service.dart';

class OnboardingProvider extends ChangeNotifier {
  String? firstName;
  Set<String> stressChoices = {};
  String? canton;
  String? employmentStatus;
  String? householdType;
  String? mainGoal;
  String? housingStatus;

  int? birthYear;
  double? incomeMonthly;
  double? housingCostMonthly;
  double? debtPaymentsMonthly;
  double? cashSavingsTotal;
  double? investmentsTotal;
  double? pillar3aTotal;
  double? taxProvisionMonthly;
  double? lamalPremiumMonthly;
  double? otherFixedCostsMonthly;

  // Partner data (couple / family)
  double? partnerIncome;
  int? partnerBirthYear;
  String? partnerEmploymentStatus;
  String? civilStatusChoice; // 'married' or 'concubinage'
  String? partnerFirstName;

  String? draftFirstName;
  String? draftBirthYear;
  String? draftIncome;
  String? draftHousingCost;
  String? draftDebtPayments;
  String? draftCashSavings;
  String? draftInvestmentsTotal;
  String? draftPillar3aTotal;
  String? draftTaxProvision;
  String? draftLamal;
  String? draftOtherFixed;
  String? draftPartnerIncome;
  String? draftPartnerBirthYear;
  String? draftPartnerFirstName;

  int currentStep = 0;
  bool isCompleted = false;
  bool hasSavedWizardProgress = false;
  int savedWizardProgress = 0;

  String variant = 'control';
  Map<String, int> variantMetrics = const {};

  Timer? _autoSaveDebounce;
  bool _isDisposed = false;

  bool get canAdvanceFromStep1 => stressChoices.isNotEmpty;

  bool get _isBirthYearValid {
    if (birthYear == null) return false;
    final maxYear = DateTime.now().year - 16;
    return birthYear! >= 1940 && birthYear! <= maxYear;
  }

  bool get canAdvanceFromStep2 => _isBirthYearValid && canton != null;

  bool get canAdvanceFromStep3 {
    final hasHousing = housingStatus == 'hosted' ||
        (housingStatus != null && _effectiveHousingCost > 0);
    final hasCoreIncomeData = _effectiveIncome > 0 &&
        hasHousing &&
        employmentStatus != null &&
        householdType != null;
    if (!hasCoreIncomeData) return false;
    if (!isHouseholdWithPartner) return true;
    return hasPartnerRequiredData;
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

  bool get isHouseholdWithPartner {
    return householdType == 'couple' || householdType == 'family';
  }

  bool get _isPartnerBirthYearValid {
    final value = _effectivePartnerBirthYear;
    if (value == null) return false;
    final maxYear = DateTime.now().year - 16;
    return value >= 1940 && value <= maxYear;
  }

  bool get hasPartnerRequiredData {
    return civilStatusChoice != null &&
        _effectivePartnerIncome > 0 &&
        _isPartnerBirthYearValid &&
        partnerEmploymentStatus != null;
  }

  double get effectiveIncomeMonthly => _effectiveIncome;
  double get effectiveHousingCostMonthly => _effectiveHousingCost;
  double get effectiveDebtPaymentsMonthly => _effectiveDebtPayments;
  double get effectiveCashSavingsTotal => _effectiveCashSavings;
  double get effectiveInvestmentsTotal => _effectiveInvestments;
  double get effectivePillar3aTotal => _effectivePillar3a;
  double get effectivePartnerIncomeMonthly => _effectivePartnerIncome;
  int? get effectivePartnerBirthYear => _effectivePartnerBirthYear;

  double get _effectiveIncome => incomeMonthly ?? _toDouble(draftIncome) ?? 0;
  double get _effectiveHousingCost =>
      housingCostMonthly ?? _toDouble(draftHousingCost) ?? 0;
  double get _effectiveDebtPayments =>
      debtPaymentsMonthly ?? _toDouble(draftDebtPayments) ?? 0;
  double get _effectiveCashSavings =>
      cashSavingsTotal ?? _toDouble(draftCashSavings) ?? 0;
  double get _effectiveInvestments =>
      investmentsTotal ?? _toDouble(draftInvestmentsTotal) ?? 0;
  double get _effectivePillar3a =>
      pillar3aTotal ?? _toDouble(draftPillar3aTotal) ?? 0;
  double get _effectivePartnerIncome =>
      partnerIncome ?? _toDouble(draftPartnerIncome) ?? 0;
  int? get _effectivePartnerBirthYear =>
      partnerBirthYear ?? _toInt(draftPartnerBirthYear);

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
    firstName = answers['q_firstname'] as String?;
    // Support both legacy String and new List<String> format
    final rawStress = answers['q_financial_stress_check'];
    if (rawStress is List) {
      stressChoices = Set<String>.from(rawStress.cast<String>());
    } else if (rawStress is String) {
      stressChoices = {rawStress};
    }
    canton = answers['q_canton'] as String?;
    employmentStatus = answers['q_employment_status'] as String?;
    householdType = answers['q_household_type'] as String?;
    mainGoal = answers['q_main_goal'] as String?;
    housingStatus = answers['q_housing_status'] as String?;

    birthYear = _toInt(answers['q_birth_year']);
    incomeMonthly = _toDouble(answers['q_net_income_period_chf']);
    housingCostMonthly = _toDouble(answers['q_housing_cost_period_chf']);
    debtPaymentsMonthly = _toDouble(answers['q_debt_payments_period_chf']);
    cashSavingsTotal = _toDouble(answers['q_cash_total']);
    investmentsTotal = _toDouble(answers['q_investments_total']);
    pillar3aTotal = _toDouble(answers['q_3a_total']);
    taxProvisionMonthly = _toDouble(answers['q_tax_provision_monthly_chf']);
    lamalPremiumMonthly = _toDouble(answers['q_lamal_premium_monthly_chf']);
    otherFixedCostsMonthly =
        _toDouble(answers['q_other_fixed_costs_monthly_chf']);

    draftBirthYear = answers['mini_draft_birth_year']?.toString();
    draftIncome = answers['mini_draft_income']?.toString();
    draftHousingCost = answers['mini_draft_housing_cost']?.toString();
    draftDebtPayments = answers['mini_draft_debt_payments']?.toString();
    draftCashSavings = answers['mini_draft_cash_savings']?.toString();
    draftInvestmentsTotal =
        answers['mini_draft_investments_total']?.toString();
    draftPillar3aTotal = answers['mini_draft_3a_total']?.toString();
    draftTaxProvision = answers['mini_draft_tax_provision']?.toString();
    draftLamal = answers['mini_draft_lamal']?.toString();
    draftOtherFixed = answers['mini_draft_other_fixed']?.toString();

    // Partner data
    partnerFirstName = answers['q_partner_firstname'] as String?;
    partnerIncome = _toDouble(answers['q_partner_net_income_chf']);
    partnerBirthYear = _toInt(answers['q_partner_birth_year']);
    partnerEmploymentStatus = answers['q_partner_employment_status'] as String?;
    civilStatusChoice = answers['q_civil_status_choice'] as String?;
    draftFirstName = answers['mini_draft_firstname']?.toString();
    draftPartnerIncome = answers['mini_draft_partner_income']?.toString();
    draftPartnerBirthYear =
        answers['mini_draft_partner_birth_year']?.toString();
    draftPartnerFirstName =
        answers['mini_draft_partner_firstname']?.toString();

    if (householdType == null) {
      final civilStatus = answers['q_civil_status'] as String?;
      final children = _toInt(answers['q_children']) ?? 0;
      if (civilStatus == 'married' || civilStatus == 'concubinage') {
        householdType = children > 0 ? 'family' : 'couple';
      } else if (children > 0) {
        householdType = 'single_parent';
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

  void toggleStressChoice(String value) {
    if (stressChoices.contains(value)) {
      stressChoices = Set<String>.from(stressChoices)..remove(value);
    } else {
      stressChoices = Set<String>.from(stressChoices)..add(value);
    }
    scheduleAutoSave('stress_selected');
    _safeNotify();
  }

  void setBirthYearDraft(String value) {
    draftBirthYear = value.trim();
    birthYear = _toInt(value);
    scheduleAutoSave('birth_year_changed');
    _safeNotify();
  }

  void setFirstNameDraft(String value) {
    final trimmed = value.trim();
    draftFirstName = trimmed;
    firstName = trimmed.isEmpty ? null : trimmed;
    scheduleAutoSave('first_name_changed');
    _safeNotify();
  }

  void setCanton(String? value) {
    canton = value;
    _tryPrefillFixedCosts();
    scheduleAutoSave('canton_changed');
    _safeNotify();
  }

  void setIncomeDraft(String value) {
    draftIncome = value.trim();
    incomeMonthly = _toDouble(value);
    _tryPrefillHousingCost();
    _tryPrefillFixedCosts();
    scheduleAutoSave('income_changed');
    _safeNotify();
  }

  void setHousingStatus(String? value) {
    housingStatus = value;
    _tryPrefillHousingCost();
    scheduleAutoSave('housing_status_changed');
    _safeNotify();
  }

  void setHousingCostDraft(String value) {
    draftHousingCost = value.trim();
    housingCostMonthly = _toDouble(value);
    scheduleAutoSave('housing_cost_changed');
    _safeNotify();
  }

  void setDebtPaymentsDraft(String value) {
    draftDebtPayments = value.trim();
    debtPaymentsMonthly = _toDouble(value);
    scheduleAutoSave('debt_payments_changed');
    _safeNotify();
  }

  void setCashSavingsDraft(String value) {
    draftCashSavings = value.trim();
    cashSavingsTotal = _toDouble(value);
    scheduleAutoSave('cash_savings_changed');
    _safeNotify();
  }

  void setInvestmentsTotalDraft(String value) {
    draftInvestmentsTotal = value.trim();
    investmentsTotal = _toDouble(value);
    scheduleAutoSave('investments_total_changed');
    _safeNotify();
  }

  void setPillar3aTotalDraft(String value) {
    draftPillar3aTotal = value.trim();
    pillar3aTotal = _toDouble(value);
    scheduleAutoSave('3a_total_changed');
    _safeNotify();
  }

  void setEmploymentStatus(String? value) {
    employmentStatus = value;
    scheduleAutoSave('employment_changed');
    _safeNotify();
  }

  void setHouseholdType(String? value) {
    householdType = value;
    _tryPrefillHousingCost();
    if (value == 'single' || value == 'single_parent') {
      civilStatusChoice = null;
      partnerIncome = null;
      partnerBirthYear = null;
      partnerEmploymentStatus = null;
      partnerFirstName = null;
      draftPartnerIncome = null;
      draftPartnerBirthYear = null;
      draftPartnerFirstName = null;
    }
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

  void setPartnerIncome(double? value) {
    partnerIncome = value;
    scheduleAutoSave('partner_income');
    _safeNotify();
  }

  void setPartnerFirstNameDraft(String value) {
    final trimmed = value.trim();
    draftPartnerFirstName = trimmed;
    partnerFirstName = trimmed.isEmpty ? null : trimmed;
    scheduleAutoSave('partner_first_name');
    _safeNotify();
  }

  void setPartnerIncomeDraft(String value) {
    draftPartnerIncome = value.trim();
    partnerIncome = _toDouble(value);
    scheduleAutoSave('partner_income');
    _safeNotify();
  }

  void setPartnerBirthYear(int? value) {
    partnerBirthYear = value;
    scheduleAutoSave('partner_birth_year');
    _safeNotify();
  }

  void setPartnerBirthYearDraft(String value) {
    draftPartnerBirthYear = value.trim();
    partnerBirthYear = _toInt(value);
    scheduleAutoSave('partner_birth_year');
    _safeNotify();
  }

  void setPartnerEmploymentStatus(String? value) {
    partnerEmploymentStatus = value;
    scheduleAutoSave('partner_employment');
    _safeNotify();
  }

  void setCivilStatusChoice(String? value) {
    civilStatusChoice = value;
    scheduleAutoSave('civil_status_choice');
    _safeNotify();
  }

  String suggestGoalFromStress() {
    // Priority: budget/debt → debt_free, tax → real_estate, pension → retirement
    if (stressChoices.contains('budget') || stressChoices.contains('debt')) {
      return 'debt_free';
    }
    if (stressChoices.contains('tax')) {
      return 'real_estate';
    }
    return 'retirement';
  }

  String civilStatusForHousehold(String value) {
    switch (value) {
      case 'couple':
      case 'family':
        return civilStatusChoice ?? 'married';
      case 'single_parent':
        return 'single';
      default:
        return 'single';
    }
  }

  int childrenCountForHousehold(String value) {
    if (value == 'family' || value == 'single_parent') return 1;
    return 0;
  }

  int adultCountForHousehold(String value) {
    return (value == 'single' || value == 'single_parent') ? 1 : 2;
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

  void _tryPrefillFixedCosts() {
    if (canton != null && (incomeMonthly ?? 0) > 0) {
      prefillFixedCostsEstimates();
    }
  }

  void prefillFixedCostsEstimates() {
    if (_effectiveIncome <= 0 || canton == null) return;
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
    otherFixedCostsMonthly ??= switch (householdType ?? 'single') {
      'single' => 250,
      'couple' => 450,
      'family' => 700,
      'single_parent' => 550,
      _ => 300,
    };
    draftTaxProvision ??= monthlyTax.round().toString();
    draftLamal ??= lamalPremiumMonthly?.round().toString();
    draftOtherFixed ??= otherFixedCostsMonthly?.round().toString();

    scheduleAutoSave('fixed_cost_prefill');
    _safeNotify();
  }

  void _tryPrefillHousingCost() {
    if ((incomeMonthly ?? 0) <= 0) return;
    if ((housingCostMonthly ?? 0) > 0) return;
    final income = incomeMonthly ?? 0;
    final ratio = switch (householdType ?? 'single') {
      'single' => 0.28,
      'single_parent' => 0.30,
      'couple' => 0.26,
      'family' => 0.27,
      _ => 0.28,
    };
    final estimated = (income * ratio).clamp(700, 4500).roundToDouble();
    housingCostMonthly = estimated;
    draftHousingCost ??= estimated.round().toString();
  }

  Map<String, dynamic> buildAnswersSnapshot() {
    final snapshot = <String, dynamic>{};

    if ((firstName ?? '').trim().isNotEmpty) {
      snapshot['q_firstname'] = firstName!.trim();
    }

    if (stressChoices.isNotEmpty) {
      snapshot['q_financial_stress_check'] = stressChoices.toList();
    }
    if (_isBirthYearValid) {
      snapshot['q_birth_year'] = birthYear;
    }
    if (canton != null) {
      snapshot['q_canton'] = canton;
    }
    if (_effectiveIncome > 0) {
      snapshot['q_net_income_period_chf'] = _effectiveIncome;
    }
    if ((housingStatus ?? '').isNotEmpty) {
      snapshot['q_housing_status'] = housingStatus;
    }
    if (_effectiveHousingCost > 0) {
      snapshot['q_housing_cost_period_chf'] = _effectiveHousingCost;
    }
    if (_effectiveDebtPayments > 0) {
      snapshot['q_debt_payments_period_chf'] = _effectiveDebtPayments;
      snapshot['q_has_consumer_debt'] = 'yes';
    } else {
      snapshot['q_has_consumer_debt'] = 'no';
    }
    if (_effectiveCashSavings > 0) {
      snapshot['q_cash_total'] = _effectiveCashSavings;
    }
    if (_effectiveInvestments > 0) {
      snapshot['q_has_investments'] = 'yes';
      snapshot['q_investments_total'] = _effectiveInvestments;
    } else {
      snapshot['q_has_investments'] = 'no';
    }
    if (_effectivePillar3a > 0) {
      snapshot['q_has_3a'] = 'yes';
      snapshot['q_3a_accounts_count'] = 1;
      snapshot['q_3a_total'] = _effectivePillar3a;
    } else {
      snapshot['q_has_3a'] = 'no';
      snapshot['q_3a_accounts_count'] = 0;
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

    // Partner data (couple / family only)
    if (isHouseholdWithPartner) {
      if (_effectivePartnerIncome > 0) {
        snapshot['q_partner_net_income_chf'] = _effectivePartnerIncome;
      }
      if ((partnerFirstName ?? '').trim().isNotEmpty) {
        snapshot['q_partner_firstname'] = partnerFirstName!.trim();
      }
      if (_effectivePartnerBirthYear != null) {
        snapshot['q_partner_birth_year'] = _effectivePartnerBirthYear;
      }
      if (partnerEmploymentStatus != null) {
        snapshot['q_partner_employment_status'] = partnerEmploymentStatus;
      }
      if (civilStatusChoice != null) {
        snapshot['q_civil_status_choice'] = civilStatusChoice;
      }
    }

    if (employmentStatus == 'employee' &&
        (incomeMonthly ?? 0) * 12 > OnboardingConstants.lppAccessThreshold) {
      snapshot['q_has_pension_fund'] = 'yes';
    }

    if ((draftBirthYear ?? '').isNotEmpty) {
      snapshot['mini_draft_birth_year'] = draftBirthYear;
    }
    if ((draftFirstName ?? '').isNotEmpty) {
      snapshot['mini_draft_firstname'] = draftFirstName;
    }
    if ((draftIncome ?? '').isNotEmpty) {
      snapshot['mini_draft_income'] = draftIncome;
    }
    if ((draftHousingCost ?? '').isNotEmpty) {
      snapshot['mini_draft_housing_cost'] = draftHousingCost;
    }
    if ((draftDebtPayments ?? '').isNotEmpty) {
      snapshot['mini_draft_debt_payments'] = draftDebtPayments;
    }
    if ((draftCashSavings ?? '').isNotEmpty) {
      snapshot['mini_draft_cash_savings'] = draftCashSavings;
    }
    if ((draftInvestmentsTotal ?? '').isNotEmpty) {
      snapshot['mini_draft_investments_total'] = draftInvestmentsTotal;
    }
    if ((draftPillar3aTotal ?? '').isNotEmpty) {
      snapshot['mini_draft_3a_total'] = draftPillar3aTotal;
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
    if (isHouseholdWithPartner) {
      if ((draftPartnerFirstName ?? '').isNotEmpty) {
        snapshot['mini_draft_partner_firstname'] = draftPartnerFirstName;
      }
      if ((draftPartnerIncome ?? '').isNotEmpty) {
        snapshot['mini_draft_partner_income'] = draftPartnerIncome;
      }
      if ((draftPartnerBirthYear ?? '').isNotEmpty) {
        snapshot['mini_draft_partner_birth_year'] = draftPartnerBirthYear;
      }
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
        _effectiveIncome * 12 > OnboardingConstants.lppAccessThreshold;
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
      'q_net_income_period_chf': _effectiveIncome,
      'q_employment_status': employment,
      'q_has_pension_fund': hasPensionFund ? 'yes' : 'no',
      'q_savings_monthly': monthlySavings,
      'q_savings_allocation': const ['epargne_libre'],
      'q_main_goal': mainGoal ?? 'retirement',
      'q_household_type': householdType ?? 'single',
      'q_housing_status': housingStatus ?? 'tenant',
      'q_housing_cost_period_chf': _effectiveHousingCost > 0
          ? _effectiveHousingCost
          : (0.28 * _effectiveIncome).roundToDouble(),
      'q_debt_payments_period_chf': _effectiveDebtPayments,
      'q_has_consumer_debt': _effectiveDebtPayments > 0 ? 'yes' : 'no',
      'q_cash_total': _effectiveCashSavings,
      'q_has_investments': _effectiveInvestments > 0 ? 'yes' : 'no',
      'q_investments_total': _effectiveInvestments,
      'q_has_3a': _effectivePillar3a > 0 ? 'yes' : 'no',
      'q_3a_total': _effectivePillar3a,
      'q_3a_accounts_count': _effectivePillar3a > 0 ? 1 : 0,
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
