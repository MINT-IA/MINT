import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';
import 'package:mint_mobile/services/tax_estimator_service.dart';

enum PayFrequency {
  monthly,
  biweekly,
  weekly,
  yearly,
}

enum BudgetStyle {
  justAvailable,
  envelopes3,
}

class BudgetInputs {
  static const maxMonthlyHousingCost = 20000.0;
  static const maxMonthlyHealthInsurance = 3000.0;
  static const maxMonthlyFixedCharge = 10000.0;

  final PayFrequency payFrequency;
  final double netIncome; // Mensuel normalisé
  final double housingCost; // Mensuel
  final double debtPayments; // Mensuel
  final double taxProvision; // Mensuel (provision impots)
  final double healthInsurance; // Mensuel (LAMal)
  final double otherFixedCosts; // Mensuel (assurances/autres charges fixes)
  final bool isTaxEstimated;
  final bool isHealthEstimated;
  final bool isHousingMissing;
  final bool isHealthMissing;
  final bool isOtherFixedMissing;
  final BudgetStyle style;
  final double
      emergencyFundMonths; // Mois de dépenses couverts par l'épargne liquide

  const BudgetInputs({
    required this.payFrequency,
    required this.netIncome,
    required this.housingCost,
    required this.debtPayments,
    this.taxProvision = 0,
    this.healthInsurance = 0,
    this.otherFixedCosts = 0,
    this.isTaxEstimated = false,
    this.isHealthEstimated = false,
    this.isHousingMissing = false,
    this.isHealthMissing = false,
    this.isOtherFixedMissing = false,
    this.style = BudgetStyle.envelopes3,
    this.emergencyFundMonths = 0,
  });

  bool get hasEstimatedValues => isTaxEstimated || isHealthEstimated;
  bool get hasMissingValues =>
      isHousingMissing || isHealthMissing || isOtherFixedMissing;

  /// Source-trust charges predicate shared by the readiness gate and the
  /// budget render path (SALVAGE-00 SC-3 / Gate Fix 1).
  ///
  /// Returns true IFF [fromCoachProfile] would yield a NON-ZERO monthly
  /// charges total — i.e. at least one user-facing expense (loyer / LAMal /
  /// autres charges fixes) carries a trusted or estimated data source, OR was
  /// explicitly user-provided. This is the SAME per-expense source gate the
  /// budget screen renders against (see [fromCoachProfile] :85-108), so the
  /// readiness gate is gate-ready IFF the screen would render a non-zero
  /// charge. An untagged loyer (no `dataSources['depenses.loyer']` entry, not
  /// in `userProvidedFields`) renders 0 and therefore must NOT pass the gate.
  ///
  /// Do NOT loosen this to a raw `profile.depenses.totalMensuel > 0` check:
  /// that would pass the gate while the screen still renders 0 (the P1
  /// pass-gate-but-render-zero trust collapse this fix kills).
  static bool hasTrustedCharges(CoachProfile profile) {
    final hasHousingSource = _hasTrustedSource(profile, 'depenses.loyer') ||
        _hasEstimatedSource(profile, 'depenses.loyer') ||
        profile.userProvidedFields.contains('housingCost');
    final hasHealthSource =
        _hasTrustedSource(profile, 'depenses.assuranceMaladie') ||
            _hasEstimatedSource(profile, 'depenses.assuranceMaladie') ||
            profile.userProvidedFields.contains('lamalPremium');
    final hasOtherFixedSource = _hasAnyTrustedSource(profile, const [
          'depenses.electricite',
          'depenses.transport',
          'depenses.telecom',
          'depenses.fraisMedicaux',
          'depenses.autresDepensesFixes',
        ]) ||
        profile.userProvidedFields.contains('electricity') ||
        profile.userProvidedFields.contains('transport') ||
        profile.userProvidedFields.contains('telecom') ||
        profile.userProvidedFields.contains('medicalCosts') ||
        profile.userProvidedFields.contains('otherFixedCosts');
    return hasHousingSource || hasHealthSource || hasOtherFixedSource;
  }

  /// Construit des BudgetInputs a partir d'un CoachProfile.
  ///
  /// Utilise pour synchroniser le budget quand le profil change
  /// (wizard, annual refresh, mini-onboarding).
  /// Le revenu net utilise NetIncomeBreakdown (canton + age).
  /// Les mensualites de dettes saisies priment; le proxy total/36 ne sert
  /// que si aucun paiement mensuel explicite n'existe.
  static BudgetInputs fromCoachProfile(CoachProfile profile) {
    // Revenu net du menage (utilisateur + conjoint si couple)
    final monthlyNet = monthlyNetFromCoachProfile(profile);
    final hasHousingSource = _hasTrustedSource(profile, 'depenses.loyer') ||
        _hasEstimatedSource(profile, 'depenses.loyer') ||
        profile.userProvidedFields.contains('housingCost');
    final hasTrustedHealthSource =
        _hasTrustedSource(profile, 'depenses.assuranceMaladie');
    final hasEstimatedHealthSource =
        _hasEstimatedSource(profile, 'depenses.assuranceMaladie');
    final hasUserProvidedHealthSource =
        profile.userProvidedFields.contains('lamalPremium');
    final hasHealthSource = hasTrustedHealthSource ||
        hasEstimatedHealthSource ||
        hasUserProvidedHealthSource;
    final hasOtherFixedSource = _hasAnyTrustedSource(profile, const [
          'depenses.electricite',
          'depenses.transport',
          'depenses.telecom',
          'depenses.fraisMedicaux',
          'depenses.autresDepensesFixes',
        ]) ||
        profile.userProvidedFields.contains('electricity') ||
        profile.userProvidedFields.contains('transport') ||
        profile.userProvidedFields.contains('telecom') ||
        profile.userProvidedFields.contains('medicalCosts') ||
        profile.userProvidedFields.contains('otherFixedCosts');

    final housingCost = hasHousingSource
        ? plausibleMonthlyAmount(
              profile.depenses.loyer,
              max: maxMonthlyHousingCost,
            ) ??
            0.0
        : 0.0;
    final healthInsurance = hasHealthSource
        ? plausibleMonthlyAmount(
              profile.depenses.assuranceMaladie,
              max: maxMonthlyHealthInsurance,
            ) ??
            0.0
        : 0.0;
    final monthlyDebt = _monthlyDebtPayment(profile.dettes);
    final otherFixed =
        hasOtherFixedSource ? _trustedOtherFixedCosts(profile) : 0.0;
    final plausibleOtherFixed = plausibleMonthlyAmount(
          otherFixed,
          max: maxMonthlyFixedCharge,
        ) ??
        0.0;

    // Civilite mapping pour TaxEstimatorService
    final civilStatusStr = switch (profile.etatCivil) {
      CoachCivilStatus.marie => 'married',
      CoachCivilStatus.concubinage => 'single',
      _ => 'single',
    };

    // Data source tags — propagate "estimé" vs "saisi" from profile
    // Emergency fund: months of plausible expenses covered by liquid savings.
    final plausibleMonthlyExpenses =
        housingCost + healthInsurance + plausibleOtherFixed;
    final monthlyExpenses = plausibleMonthlyExpenses > 0
        ? plausibleMonthlyExpenses
        : monthlyNet * 0.70; // fallback: 70% of net income
    final emergencyMonths = monthlyExpenses > 0
        ? profile.patrimoine.epargneLiquide / monthlyExpenses
        : 0.0;

    return BudgetInputs(
      payFrequency: PayFrequency.monthly,
      netIncome: monthlyNet,
      housingCost: housingCost,
      debtPayments: monthlyDebt,
      taxProvision: TaxEstimatorService.estimateMonthlyProvision(
        TaxEstimatorService.estimateAnnualTax(
          netMonthlyIncome: monthlyNet,
          cantonCode: profile.canton,
          civilStatus: civilStatusStr,
          childrenCount: profile.nombreEnfants,
          age: profile.age,
          isSourceTaxed: false,
        ),
      ),
      healthInsurance: healthInsurance,
      otherFixedCosts: plausibleOtherFixed > 0 ? plausibleOtherFixed : 0,
      isTaxEstimated: true,
      isHealthEstimated: hasHealthSource ? hasEstimatedHealthSource : false,
      isHousingMissing: !hasHousingSource,
      isHealthMissing: !hasHealthSource,
      isOtherFixedMissing: plausibleOtherFixed <= 0,
      emergencyFundMonths: emergencyMonths,
    );
  }

  /// Household monthly net income used by budget surfaces.
  ///
  /// Salaried income uses the payslip net calculator. Independent income uses
  /// the same explicit approximation as BudgetLivingEngine: gross annual × 90%
  /// / 12, because NetIncomeBreakdown models employee social charges.
  static double monthlyNetFromCoachProfile(CoachProfile profile) {
    final explicitOwnNet = profile.explicitMonthlyNetIncome;
    if (explicitOwnNet != null &&
        explicitOwnNet.isFinite &&
        explicitOwnNet > 0) {
      return explicitOwnNet;
    }
    if (profile.employmentStatus == 'independant') {
      final professionalNetAnnual =
          profile.independentNetProfessionalIncomeAnnual;
      if (professionalNetAnnual != null &&
          professionalNetAnnual.isFinite &&
          professionalNetAnnual > 0) {
        return professionalNetAnnual / 12;
      }
    }
    final ownNet = _monthlyNetFromGrossAnnual(
      grossAnnual: profile.revenuBrutAnnuel,
      canton: profile.canton,
      age: profile.age,
      employmentStatus: profile.employmentStatus,
    );
    final conjoint = profile.conjoint;
    final partnerNet = conjoint != null && conjoint.age != null
        ? _monthlyNetFromGrossAnnual(
            grossAnnual: conjoint.revenuBrutAnnuel,
            canton: profile.canton,
            age: conjoint.age!,
            employmentStatus: conjoint.employmentStatus ?? 'salarie',
          )
        : 0.0;
    return ownNet + partnerNet;
  }

  static double _monthlyNetFromGrossAnnual({
    required double grossAnnual,
    required String canton,
    required int age,
    required String employmentStatus,
  }) {
    if (grossAnnual <= 0 || !grossAnnual.isFinite) return 0;
    if (employmentStatus == 'independant') {
      return grossAnnual * 0.90 / 12;
    }
    return NetIncomeBreakdown.compute(
      grossSalary: grossAnnual,
      canton: canton.isNotEmpty ? canton : 'ZH',
      age: age,
    ).monthlyNetPayslip;
  }

  static double _monthlyDebtPayment(DetteProfile dettes) {
    final explicitMonthly = _positiveFinite(dettes.mensualiteCreditConso) +
        _positiveFinite(dettes.mensualiteLeasing);
    if (explicitMonthly.isFinite && explicitMonthly > 0) {
      return explicitMonthly;
    }

    final totalDebt = _positiveFinite(dettes.creditConsommation) +
        _positiveFinite(dettes.leasing) +
        _positiveFinite(dettes.autresDettes);
    if (totalDebt.isFinite && totalDebt > 0) {
      return totalDebt / 36;
    }

    return 0.0;
  }

  static double _positiveFinite(double? value) {
    if (value == null || !value.isFinite || value <= 0) return 0.0;
    return value;
  }

  // Factory depuis une map (pour deserialization depuis Session.answers)
  factory BudgetInputs.fromMap(Map<String, dynamic> map) {
    // Calculer les mois de fonds d'urgence depuis la réponse wizard
    double emergencyMonths = 0;
    final emergencySaved = map['emergency_fund_months'];
    final emergencyRaw = map['q_emergency_fund'];
    if (emergencySaved is num) {
      emergencyMonths = emergencySaved.toDouble();
    }
    if (emergencyRaw is String) {
      switch (emergencyRaw.toLowerCase()) {
        case 'yes_6months':
          emergencyMonths = 6;
        case 'yes_3months':
          emergencyMonths = 3;
        case 'no':
          emergencyMonths = 0;
        default:
          final parsed = double.tryParse(emergencyRaw);
          if (parsed != null) emergencyMonths = parsed;
      }
    }

    final payFrequency = _parsePayFrequency(map['q_pay_frequency']);
    final legacyMonthlyIncome = _parseDouble(map['q_net_income_monthly']);
    final periodicNetIncome = _parseDouble(map['q_net_income_period_chf']);
    final netIncome = periodicNetIncome != null
        ? _toMonthly(periodicNetIncome, payFrequency)
        : legacyMonthlyIncome ?? 0.0;

    // Despite the historical "period" key names, these values are monthly
    // in current budget setup and wizard V2 flows. Do not multiply them by
    // pay frequency unless the storage contract changes.
    final hasHousingKey = map.containsKey('q_housing_cost_period_chf');
    final parsedHousingCost = _parseDouble(map['q_housing_cost_period_chf']);
    final housingCostRaw = parsedHousingCost ?? 0.0;
    final housingCost = plausibleMonthlyAmount(
          housingCostRaw,
          max: maxMonthlyHousingCost,
        ) ??
        0.0;
    final debtPayments = _parseDouble(map['q_debt_payments_period_chf']) ?? 0.0;

    final taxProvisionRaw = _parseDouble(map['q_tax_provision_monthly_chf']);
    final lamalRaw = plausibleMonthlyAmount(
      _parseDouble(map['q_lamal_premium_monthly_chf']),
      max: maxMonthlyHealthInsurance,
    );
    final otherFixedRaw = plausibleMonthlyAmount(
      _parseDouble(map['q_other_fixed_costs_monthly_chf']) ??
          _sumDetailedFixedCosts(map),
      max: maxMonthlyFixedCharge,
    );

    final civilStatus = map['q_civil_status'] as String? ?? 'single';
    final canton = map['q_canton'] as String? ?? 'CH';
    final children = _parseChildrenCount(map['q_children']);

    final estimatedTax = taxProvisionRaw ??
        TaxEstimatorService.estimateMonthlyProvision(
          TaxEstimatorService.estimateAnnualTax(
            netMonthlyIncome: netIncome,
            cantonCode: canton,
            civilStatus: civilStatus,
            childrenCount: children,
            age: 35,
            isSourceTaxed: false,
          ),
        );

    final estimatedLamal = lamalRaw ??
        _estimateLamalPremium(canton, map['q_household_type'] as String?);

    final metaTaxEstimated = map['meta_tax_estimated'];
    final metaHealthEstimated = map['meta_health_estimated'];
    final metaHousingMissing = map['meta_housing_missing'];
    final metaHealthMissing = map['meta_health_missing'];
    final metaOtherFixedMissing = map['meta_other_fixed_missing'];

    return BudgetInputs(
      payFrequency: payFrequency,
      netIncome: netIncome,
      housingCost: housingCost,
      debtPayments: debtPayments,
      taxProvision: estimatedTax,
      healthInsurance: estimatedLamal,
      otherFixedCosts: otherFixedRaw ?? 0.0,
      isTaxEstimated:
          metaTaxEstimated is bool ? metaTaxEstimated : taxProvisionRaw == null,
      isHealthEstimated:
          metaHealthEstimated is bool ? metaHealthEstimated : lamalRaw == null,
      isHousingMissing: metaHousingMissing is bool
          ? metaHousingMissing
          : !hasHousingKey || parsedHousingCost == null || housingCost == 0,
      isHealthMissing:
          metaHealthMissing is bool ? metaHealthMissing : lamalRaw == null,
      isOtherFixedMissing: metaOtherFixedMissing is bool
          ? metaOtherFixedMissing
          : otherFixedRaw == null,
      style: BudgetStyle.values.firstWhere(
        (e) => e.name == map['q_budget_style'],
        orElse: () => BudgetStyle.envelopes3,
      ),
      emergencyFundMonths: emergencyMonths,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'q_pay_frequency': PayFrequency.monthly.name,
      'q_net_income_period_chf': netIncome,
      'q_housing_cost_period_chf': housingCost,
      'q_debt_payments_period_chf': debtPayments,
      'q_tax_provision_monthly_chf': taxProvision,
      'q_lamal_premium_monthly_chf': healthInsurance,
      'q_other_fixed_costs_monthly_chf': otherFixedCosts,
      'meta_tax_estimated': isTaxEstimated,
      'meta_health_estimated': isHealthEstimated,
      'meta_housing_missing': isHousingMissing,
      'meta_health_missing': isHealthMissing,
      'meta_other_fixed_missing': isOtherFixedMissing,
      'q_budget_style': style.name,
      'emergency_fund_months': emergencyFundMonths,
    };
  }

  static double _toMonthly(double amount, PayFrequency frequency) {
    switch (frequency) {
      case PayFrequency.weekly:
        return amount * 4.333;
      case PayFrequency.biweekly:
        return amount * 2.166;
      case PayFrequency.yearly:
        return amount / 12;
      case PayFrequency.monthly:
        return amount;
    }
  }

  static PayFrequency _parsePayFrequency(Object? raw) {
    if (raw is! String) return PayFrequency.monthly;
    final normalized = raw.toLowerCase().trim();
    if (normalized == 'annuel' || normalized == 'annual') {
      return PayFrequency.yearly;
    }
    return PayFrequency.values.firstWhere(
      (e) => e.name == normalized,
      orElse: () => PayFrequency.monthly,
    );
  }

  static double? plausibleMonthlyAmount(double? value, {required double max}) {
    if (value == null || value < 0 || value > max) return null;
    return value;
  }

  static double plausibleMonthlyFixedExpensesFromProfile(
    CoachProfile profile,
  ) {
    final depenses = profile.depenses;
    final housing = plausibleMonthlyAmount(
          depenses.loyer,
          max: maxMonthlyHousingCost,
        ) ??
        0.0;
    final health = plausibleMonthlyAmount(
          depenses.assuranceMaladie,
          max: maxMonthlyHealthInsurance,
        ) ??
        0.0;
    final otherFixed =
        depenses.totalMensuel - depenses.loyer - depenses.assuranceMaladie;
    final other = plausibleMonthlyAmount(
          otherFixed,
          max: maxMonthlyFixedCharge,
        ) ??
        0.0;
    return housing + health + other;
  }

  static bool _hasAnyTrustedSource(CoachProfile profile, List<String> keys) {
    return keys.any((key) => _hasTrustedSource(profile, key));
  }

  static bool _hasTrustedSource(CoachProfile profile, String key) {
    return switch (profile.dataSources[key]) {
      ProfileDataSource.userInput ||
      ProfileDataSource.crossValidated ||
      ProfileDataSource.certificate ||
      ProfileDataSource.openBanking =>
        true,
      _ => false,
    };
  }

  static bool _hasEstimatedSource(CoachProfile profile, String key) {
    return profile.dataSources[key] == ProfileDataSource.estimated;
  }

  static double _trustedOtherFixedCosts(CoachProfile profile) {
    return _trustedExpense(
          profile,
          'depenses.electricite',
          'electricity',
          profile.depenses.electricite,
        ) +
        _trustedExpense(
          profile,
          'depenses.transport',
          'transport',
          profile.depenses.transport,
        ) +
        _trustedExpense(
          profile,
          'depenses.telecom',
          'telecom',
          profile.depenses.telecom,
        ) +
        _trustedExpense(
          profile,
          'depenses.fraisMedicaux',
          'medicalCosts',
          profile.depenses.fraisMedicaux,
        ) +
        _trustedExpense(
          profile,
          'depenses.autresDepensesFixes',
          'otherFixedCosts',
          profile.depenses.autresDepensesFixes,
        );
  }

  static double _trustedExpense(
    CoachProfile profile,
    String dataSourceKey,
    String userProvidedKey,
    double? value,
  ) {
    final trusted = _hasTrustedSource(profile, dataSourceKey) ||
        profile.userProvidedFields.contains(userProvidedKey);
    return trusted ? value ?? 0.0 : 0.0;
  }

  static double? _parseDouble(dynamic raw) {
    if (raw is num) return raw.toDouble();
    if (raw is String) {
      return double.tryParse(
          raw.trim().replaceAll("'", '').replaceAll(',', '.'));
    }
    return null;
  }

  static double? _sumDetailedFixedCosts(Map<String, dynamic> map) {
    const keys = [
      '_coach_depenses_transport',
      '_coach_depenses_telecom',
      '_coach_depenses_electricite',
      '_coach_depenses_frais_medicaux',
      '_coach_depenses_autres',
    ];

    var hasAny = false;
    var total = 0.0;
    for (final key in keys) {
      if (!map.containsKey(key)) continue;
      hasAny = true;
      total += _parseDouble(map[key]) ?? 0.0;
    }

    return hasAny ? total : null;
  }

  static int _parseChildrenCount(dynamic raw) {
    if (raw == null) return 0;
    final text = raw.toString().trim().replaceAll('+', '');
    return int.tryParse(text) ?? 0;
  }

  static double _estimateLamalPremium(
      String cantonCode, String? householdType) {
    const highCantons = {'GE', 'VD', 'BS', 'NE'};
    const lowCantons = {'ZG', 'AI', 'UR', 'OW', 'NW'};
    final adults =
        householdType == 'couple' || householdType == 'family' ? 2 : 1;

    final baseAdult = highCantons.contains(cantonCode)
        ? 520.0
        : lowCantons.contains(cantonCode)
            ? 350.0
            : 430.0;

    return baseAdult * adults;
  }
}
