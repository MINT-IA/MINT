import 'dart:math' as math;

enum PropertyTransmissionStatus {
  ok('ok'),
  needsReview('needs_review'),
  atRisk('at_risk'),
  missingData('missing_data'),
  notApplicable('not_applicable');

  const PropertyTransmissionStatus(this.rawValue);

  final String rawValue;
}

enum PropertyScenarioConfidence {
  none('none'),
  medium('medium');

  const PropertyScenarioConfidence(this.rawValue);

  final String rawValue;
}

class PropertyScenarioConfidenceRationale {
  final String basis;
  final Map<String, String> axes;
  final List<String> missingInputs;
  final List<String> composedInputs;
  final List<String> limits;

  const PropertyScenarioConfidenceRationale({
    required this.basis,
    required this.axes,
    required this.missingInputs,
    required this.composedInputs,
    required this.limits,
  });

  String get semanticsValue {
    final orderedAxes = <String>[
      'completeness',
      'accuracy',
      'freshness',
      'understanding',
    ];
    final axesValue =
        orderedAxes.map((axis) => '$axis=${axes[axis] ?? 'unknown'}').join(';');
    final composedValue = composedInputs.isEmpty
        ? ''
        : ';composed_inputs=${composedInputs.join(",")}';
    final missingValue = missingInputs.isEmpty
        ? ''
        : ';missing_inputs=${missingInputs.join(",")}';
    return 'basis=$basis;$axesValue$missingValue$composedValue';
  }
}

class PropertyTransmissionInputs {
  static const defaultScenarioKey = 'article_raiffeisen_transmission_logement';

  final String scenarioKey;
  final String canton;
  final double? propertyMarketValue;
  final double? mortgageBalance;
  final double? cashPaidByRecipient;
  final double? mortgageAssumedByRecipient;
  final double? parentLiquidAssets;
  final double? parentAnnualRetirementIncome;
  final String? parentAnnualRetirementIncomeSource;
  final List<String> parentAnnualRetirementIncomeSourceKeys;
  final Map<String, DateTime> inputSourceDates;
  final DateTime? freshnessAsOf;
  final double? parentAnnualLivingCosts;
  final int? heirsCount;
  final String recipientRelationship;
  final String retainedRight;
  final bool avancementHoirie;

  const PropertyTransmissionInputs({
    this.scenarioKey = defaultScenarioKey,
    this.canton = 'VD',
    this.propertyMarketValue,
    this.mortgageBalance,
    this.cashPaidByRecipient,
    this.mortgageAssumedByRecipient,
    this.parentLiquidAssets,
    this.parentAnnualRetirementIncome,
    this.parentAnnualRetirementIncomeSource,
    this.parentAnnualRetirementIncomeSourceKeys = const [],
    this.inputSourceDates = const {},
    this.freshnessAsOf,
    this.parentAnnualLivingCosts,
    this.heirsCount,
    this.recipientRelationship = 'descendant',
    this.retainedRight = 'none',
    this.avancementHoirie = true,
  });

  factory PropertyTransmissionInputs.fromJson(Map<String, dynamic> json) {
    return PropertyTransmissionInputs(
      scenarioKey: (json['scenarioKey'] as String?) ?? defaultScenarioKey,
      canton: ((json['canton'] as String?) ?? 'VD').toUpperCase(),
      propertyMarketValue: _readDouble(json['propertyMarketValue']),
      mortgageBalance: _readDouble(json['mortgageBalance']),
      cashPaidByRecipient: _readDouble(json['cashPaidByRecipient']),
      mortgageAssumedByRecipient:
          _readDouble(json['mortgageAssumedByRecipient']),
      parentLiquidAssets: _readDouble(json['parentLiquidAssets']),
      parentAnnualRetirementIncome:
          _readDouble(json['parentAnnualRetirementIncome']),
      parentAnnualRetirementIncomeSource:
          json['parentAnnualRetirementIncomeSource'] as String?,
      parentAnnualRetirementIncomeSourceKeys:
          _readStringList(json['parentAnnualRetirementIncomeSourceKeys']),
      inputSourceDates: _readSourceDates(json),
      freshnessAsOf: _readDate(json['_freshnessAsOf']),
      parentAnnualLivingCosts: _readDouble(json['parentAnnualLivingCosts']),
      heirsCount: _readInt(json['heirsCount']),
      recipientRelationship:
          (json['recipientRelationship'] as String?) ?? 'descendant',
      retainedRight: (json['retainedRight'] as String?) ?? 'none',
      avancementHoirie: (json['avancementHoirie'] as bool?) ?? true,
    );
  }

  static double? _readDouble(Object? value) {
    if (value == null || value is bool) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static int? _readInt(Object? value) {
    if (value == null || value is bool) return null;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static List<String> _readStringList(Object? value) {
    if (value is List) {
      return value.whereType<String>().toList(growable: false);
    }
    return const [];
  }

  static Map<String, DateTime> _readSourceDates(Map<String, dynamic> json) {
    final explicit = _readDateMap(json['inputSourceDates']);
    if (explicit.isNotEmpty) return explicit;
    return _readProvenanceSourceDates(json['_inputProvenance']);
  }

  static Map<String, DateTime> _readDateMap(Object? value) {
    if (value is! Map) return const {};
    final dates = <String, DateTime>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is! String) continue;
      final date = _readDate(entry.value);
      if (date != null) dates[key] = date;
    }
    return dates;
  }

  static Map<String, DateTime> _readProvenanceSourceDates(Object? value) {
    if (value is! Map) return const {};
    final dates = <String, DateTime>{};
    for (final entry in value.entries) {
      final key = entry.key;
      final meta = entry.value;
      if (key is! String || meta is! Map) continue;
      final date = _readDate(meta['source_date'] ?? meta['sourceDate']);
      if (date != null) dates[key] = date;
    }
    return dates;
  }

  static DateTime? _readDate(Object? value) {
    if (value is DateTime) return value.toUtc();
    if (value is! String || value.trim().isEmpty) return null;
    return DateTime.tryParse(value)?.toUtc();
  }
}

class PropertyTransmissionComputed {
  final int propertyMarketValue;
  final int mortgageBalance;
  final int propertyEquity;
  final int cashPaidByRecipient;
  final int mortgageAssumedByRecipient;
  final int economicTransferValue;
  final int parentLiquidityAfterTransfer;
  final int annualRetirementMargin;

  const PropertyTransmissionComputed({
    required this.propertyMarketValue,
    required this.mortgageBalance,
    required this.propertyEquity,
    required this.cashPaidByRecipient,
    required this.mortgageAssumedByRecipient,
    required this.economicTransferValue,
    required this.parentLiquidityAfterTransfer,
    required this.annualRetirementMargin,
  });
}

class RetirementAffordabilityResult {
  final int rank;
  final PropertyTransmissionStatus status;
  final int annualMargin;
  final double liquidityCoverageYears;
  final List<String> reasons;

  const RetirementAffordabilityResult({
    required this.rank,
    required this.status,
    required this.annualMargin,
    required this.liquidityCoverageYears,
    required this.reasons,
  });

  RetirementAffordabilityResult copyWith({
    PropertyTransmissionStatus? status,
    List<String>? reasons,
  }) {
    return RetirementAffordabilityResult(
      rank: rank,
      status: status ?? this.status,
      annualMargin: annualMargin,
      liquidityCoverageYears: liquidityCoverageYears,
      reasons: reasons ?? this.reasons,
    );
  }
}

class FamilyEqualizationResult {
  final int rank;
  final PropertyTransmissionStatus status;
  final int immediateEqualizationNeedPerOtherHeir;
  final int immediateEqualizationNeedTotal;
  final int immediateEqualizationGap;
  final List<String> notes;

  const FamilyEqualizationResult({
    required this.rank,
    required this.status,
    required this.immediateEqualizationNeedPerOtherHeir,
    required this.immediateEqualizationNeedTotal,
    required this.immediateEqualizationGap,
    required this.notes,
  });

  FamilyEqualizationResult copyWith({
    PropertyTransmissionStatus? status,
    List<String>? notes,
  }) {
    return FamilyEqualizationResult(
      rank: rank,
      status: status ?? this.status,
      immediateEqualizationNeedPerOtherHeir:
          immediateEqualizationNeedPerOtherHeir,
      immediateEqualizationNeedTotal: immediateEqualizationNeedTotal,
      immediateEqualizationGap: immediateEqualizationGap,
      notes: notes ?? this.notes,
    );
  }
}

class PropertyModelScope {
  final String classification;
  final bool notLegalPartition;
  final bool requiresSpecialistReview;
  final List<String> unmodelledLegalFactors;

  const PropertyModelScope({
    required this.classification,
    required this.notLegalPartition,
    required this.requiresSpecialistReview,
    required this.unmodelledLegalFactors,
  });

  String get semanticsValue =>
      'classification=$classification;not_legal_partition=$notLegalPartition;requires_specialist_review=$requiresSpecialistReview';
}

class PropertyCantonalTaxResult {
  final int rank;
  final String canton;
  final bool requiresCantonalReview;
  final List<String> notes;

  const PropertyCantonalTaxResult({
    required this.rank,
    required this.canton,
    required this.requiresCantonalReview,
    required this.notes,
  });

  String get semanticsValue =>
      'canton=$canton;requires_cantonal_review=$requiresCantonalReview';
}

class PropertyRetainedRightResult {
  final String type;
  final String label;
  final List<String> notes;

  const PropertyRetainedRightResult({
    required this.type,
    required this.label,
    required this.notes,
  });
}

class PropertyTransmissionVariant {
  final String key;
  final String label;
  final String mainTradeoff;

  const PropertyTransmissionVariant({
    required this.key,
    required this.label,
    required this.mainTradeoff,
  });
}

class PropertyTransmissionResult {
  final String scenarioKey;
  final String scenarioKind;
  final PropertyScenarioConfidence scenarioConfidence;
  final PropertyScenarioConfidenceRationale scenarioConfidenceRationale;
  final String? parentAnnualRetirementIncomeSource;
  final PropertyModelScope modelScope;
  final String articleThesis;
  final bool requiresInputCompletion;
  final List<String> missingInputs;
  final PropertyTransmissionComputed computed;
  final RetirementAffordabilityResult retirementAffordability;
  final FamilyEqualizationResult familyEqualization;
  final PropertyCantonalTaxResult cantonalTax;
  final PropertyRetainedRightResult retainedRight;
  final bool avancementHoirie;
  final List<PropertyTransmissionVariant> variants;
  final List<String> formalities;

  const PropertyTransmissionResult({
    required this.scenarioKey,
    required this.scenarioKind,
    required this.scenarioConfidence,
    required this.scenarioConfidenceRationale,
    this.parentAnnualRetirementIncomeSource,
    required this.modelScope,
    required this.articleThesis,
    required this.requiresInputCompletion,
    required this.missingInputs,
    required this.computed,
    required this.retirementAffordability,
    required this.familyEqualization,
    required this.cantonalTax,
    required this.retainedRight,
    required this.avancementHoirie,
    required this.variants,
    required this.formalities,
  });
}

class PropertyTransmissionCalculator {
  static const requiredInputs = <String>[
    'propertyMarketValue',
    'mortgageBalance',
    'parentLiquidAssets',
    'parentAnnualRetirementIncome',
    'parentAnnualLivingCosts',
    'heirsCount',
  ];
  static const _freshnessTrackedInputs = <String>[
    'propertyMarketValue',
    'mortgageBalance',
    'parentLiquidAssets',
    'parentAnnualRetirementIncome',
    'parentAnnualLivingCosts',
  ];
  static const _sourceDateStaleAfterDays = 365;
  // MINT educational-triage assumptions, not Swiss legal or regulatory
  // thresholds. A negative annual margin is arithmetic. The 3-year liquidity
  // buffer is a product threshold used only to route users toward specialist
  // review before a donation/sale decision involving Swiss real estate.
  static const _mintLiquidityCoverageReviewYears = 3.0;

  static PropertyTransmissionResult compute(PropertyTransmissionInputs inputs) {
    final propertyValue = inputs.propertyMarketValue ?? 0;
    final mortgageBalance = inputs.mortgageBalance ?? 0;
    final cashPaid = inputs.cashPaidByRecipient ?? 0;
    final mortgageAssumed = inputs.mortgageAssumedByRecipient ?? 0;
    final liquidAssets = inputs.parentLiquidAssets ?? 0;
    final annualIncome = inputs.parentAnnualRetirementIncome ?? 0;
    final annualCosts = inputs.parentAnnualLivingCosts ?? 0;
    final heirsCount = math.max(0, inputs.heirsCount ?? 0);
    final canton = inputs.canton.toUpperCase();

    final propertyEquity = math.max(0.0, propertyValue - mortgageBalance);
    final economicTransferValue =
        math.max(0.0, propertyValue - cashPaid - mortgageAssumed);
    final parentLiquidityAfterTransfer = liquidAssets + cashPaid;

    var retirement = _retirementAffordability(
      annualIncome: annualIncome,
      annualCosts: annualCosts,
      liquidityAfterTransfer: parentLiquidityAfterTransfer,
    );
    var equalization = _familyEqualization(
      economicTransferValue: economicTransferValue,
      heirsCount: heirsCount,
      liquidityAfterTransfer: parentLiquidityAfterTransfer,
      avancementHoirie: inputs.avancementHoirie,
    );

    final missingInputs = _missingRequiredInputs(inputs);
    final requiresInputCompletion = missingInputs.isNotEmpty;
    final composedInputs = _composedInputs(inputs);
    if (requiresInputCompletion) {
      const missingNote = 'successionPropertyTransmissionMissingRequiredInputs';
      retirement = retirement.copyWith(
        status: PropertyTransmissionStatus.missingData,
        reasons: [missingNote, ...retirement.reasons],
      );
      equalization = equalization.copyWith(
        status: PropertyTransmissionStatus.missingData,
        notes: [missingNote, ...equalization.notes],
      );
    }

    return PropertyTransmissionResult(
      scenarioKey: inputs.scenarioKey,
      scenarioKind: 'succession',
      scenarioConfidence: requiresInputCompletion
          ? PropertyScenarioConfidence.none
          : PropertyScenarioConfidence.medium,
      scenarioConfidenceRationale: _scenarioConfidenceRationale(
        requiresInputCompletion: requiresInputCompletion,
        missingInputs: missingInputs,
        composedInputs: composedInputs,
        inputs: inputs,
      ),
      parentAnnualRetirementIncomeSource:
          inputs.parentAnnualRetirementIncomeSource,
      modelScope: _modelScope(),
      articleThesis: _articleThesis,
      requiresInputCompletion: requiresInputCompletion,
      missingInputs: missingInputs,
      computed: PropertyTransmissionComputed(
        propertyMarketValue: _roundMoney(propertyValue),
        mortgageBalance: _roundMoney(mortgageBalance),
        propertyEquity: _roundMoney(propertyEquity),
        cashPaidByRecipient: _roundMoney(cashPaid),
        mortgageAssumedByRecipient: _roundMoney(mortgageAssumed),
        economicTransferValue: _roundMoney(economicTransferValue),
        parentLiquidityAfterTransfer: _roundMoney(parentLiquidityAfterTransfer),
        annualRetirementMargin: retirement.annualMargin,
      ),
      retirementAffordability: retirement,
      familyEqualization: equalization,
      cantonalTax: _cantonalTax(
        canton: canton,
        relationship: inputs.recipientRelationship,
        retainedRight: inputs.retainedRight,
      ),
      retainedRight: PropertyRetainedRightResult(
        type: inputs.retainedRight,
        label: _retainedRightLabel(inputs.retainedRight),
        notes: _retainedRightNotes(inputs.retainedRight),
      ),
      avancementHoirie: inputs.avancementHoirie,
      variants: _variants(),
      formalities: _formalities(),
    );
  }

  static List<String> _missingRequiredInputs(
    PropertyTransmissionInputs inputs,
  ) {
    return <String>[
      if (inputs.propertyMarketValue == null) 'propertyMarketValue',
      if (inputs.mortgageBalance == null) 'mortgageBalance',
      if (inputs.parentLiquidAssets == null) 'parentLiquidAssets',
      if (inputs.parentAnnualRetirementIncome == null)
        'parentAnnualRetirementIncome',
      if (inputs.parentAnnualLivingCosts == null) 'parentAnnualLivingCosts',
      if (inputs.heirsCount == null) 'heirsCount',
    ];
  }

  static PropertyScenarioConfidenceRationale _scenarioConfidenceRationale({
    required bool requiresInputCompletion,
    required List<String> missingInputs,
    required List<String> composedInputs,
    required PropertyTransmissionInputs inputs,
  }) {
    final completeness = requiresInputCompletion
        ? 'none'
        : composedInputs.isNotEmpty
            ? 'low'
            : 'medium';
    final basis = requiresInputCompletion
        ? 'missing_required_inputs'
        : composedInputs.isNotEmpty
            ? 'required_inputs_present_with_estimated_composition'
            : 'required_inputs_present';
    return PropertyScenarioConfidenceRationale(
      basis: basis,
      axes: {
        'completeness': completeness,
        'accuracy': 'source_dependent',
        'freshness': _freshnessAxis(inputs, missingInputs),
        'understanding': 'educational_triage',
      },
      missingInputs: missingInputs,
      composedInputs: composedInputs,
      limits: const [
        'successionPropertyTransmissionConfidenceLimitLegal',
        'successionPropertyTransmissionConfidenceLimitAccuracy',
        'successionPropertyTransmissionConfidenceLimitFreshness',
        'successionPropertyTransmissionConfidenceLimitLiquidityBufferAssumption',
        'successionPropertyTransmissionConfidenceLimitLppCapitalTax',
      ],
    );
  }

  static String _freshnessAxis(
    PropertyTransmissionInputs inputs,
    List<String> missingInputs,
  ) {
    if (missingInputs.isNotEmpty) return 'missing_required_inputs';

    final asOf = inputs.freshnessAsOf ?? DateTime.now().toUtc();
    var datedCount = 0;
    var missingDateCount = 0;
    var hasStaleInput = false;

    for (final key in _freshnessTrackedInputs) {
      final sourceDate = inputs.inputSourceDates[key];
      if (sourceDate == null) {
        missingDateCount += 1;
        continue;
      }
      datedCount += 1;
      if (asOf.difference(sourceDate).inDays > _sourceDateStaleAfterDays) {
        hasStaleInput = true;
      }
    }

    if (hasStaleInput) return 'stale_source_dates';
    if (missingDateCount > 0 && datedCount > 0) return 'partial_source_dates';
    if (missingDateCount > 0) return 'missing_source_dates';
    return 'current_source_dates';
  }

  static List<String> _composedInputs(PropertyTransmissionInputs inputs) {
    if (inputs.parentAnnualRetirementIncomeSource != 'estimated' ||
        inputs.parentAnnualRetirementIncomeSourceKeys.isEmpty) {
      return const [];
    }
    return [
      'parentAnnualRetirementIncome:${inputs.parentAnnualRetirementIncomeSourceKeys.join("+")}',
    ];
  }

  static const _articleThesis = 'successionPropertyTransmissionArticleThesis';

  static PropertyModelScope _modelScope() {
    return const PropertyModelScope(
      classification: 'educational_triage',
      notLegalPartition: true,
      requiresSpecialistReview: true,
      unmodelledLegalFactors: [
        'successionPropertyTransmissionScopeSpousePartner',
        'successionPropertyTransmissionScopeMatrimonialRegime',
        'successionPropertyTransmissionScopeLegalShares',
        'successionPropertyTransmissionScopeEstateInstrument',
        'successionPropertyTransmissionScopeEstateComposition',
        'successionPropertyTransmissionScopeCantonalRelationship',
      ],
    );
  }

  static PropertyCantonalTaxResult _cantonalTax({
    required String canton,
    required String relationship,
    required String retainedRight,
  }) {
    return PropertyCantonalTaxResult(
      rank: 3,
      canton: canton,
      requiresCantonalReview: true,
      notes: [
        'successionPropertyTransmissionCantonalTaxNoFederalDonationTax',
        'successionPropertyTransmissionCantonalTaxBeneficiaryPays',
        'successionPropertyTransmissionCantonalTaxImmovableLocation',
        if (relationship == 'descendant')
          'successionPropertyTransmissionCantonalTaxDescendantOftenExempt',
        if (retainedRight == 'habitation' ||
            retainedRight == 'usufruct' ||
            retainedRight == 'usufruit')
          'successionPropertyTransmissionCantonalTaxRetainedRightCanChangeTax',
      ],
    );
  }

  static String _retainedRightLabel(String retainedRight) {
    return switch (retainedRight) {
      'habitation' =>
        'successionPropertyTransmissionRetainedRightHabitationLabel',
      'usufruct' ||
      'usufruit' =>
        'successionPropertyTransmissionRetainedRightUsufructLabel',
      'none' => 'successionPropertyTransmissionRetainedRightNoneLabel',
      _ => retainedRight,
    };
  }

  static List<String> _retainedRightNotes(String retainedRight) {
    return switch (retainedRight) {
      'habitation' => [
          'successionPropertyTransmissionRetainedRightHabitationStay',
          'successionPropertyTransmissionRetainedRightHabitationPersonal',
          'successionPropertyTransmissionRetainedRightHabitationTaxCharges',
        ],
      'usufruct' || 'usufruit' => [
          'successionPropertyTransmissionRetainedRightUsufructUseOrRent',
          'successionPropertyTransmissionRetainedRightUsufructCharges',
          'successionPropertyTransmissionRetainedRightUsufructValueAgeCanton',
        ],
      _ => [
          'successionPropertyTransmissionRetainedRightNoneHousingCosts',
        ],
    };
  }

  static List<PropertyTransmissionVariant> _variants() {
    return const [
      PropertyTransmissionVariant(
        key: 'market_sale',
        label: 'successionPropertyTransmissionVariantMarketSaleLabel',
        mainTradeoff: 'successionPropertyTransmissionVariantMarketSaleTradeoff',
      ),
      PropertyTransmissionVariant(
        key: 'advance_inheritance',
        label: 'successionPropertyTransmissionVariantAdvanceInheritanceLabel',
        mainTradeoff:
            'successionPropertyTransmissionVariantAdvanceInheritanceTradeoff',
      ),
      PropertyTransmissionVariant(
        key: 'mixed_donation',
        label: 'successionPropertyTransmissionVariantMixedDonationLabel',
        mainTradeoff:
            'successionPropertyTransmissionVariantMixedDonationTradeoff',
      ),
      PropertyTransmissionVariant(
        key: 'retained_habitation_or_usufruct',
        label: 'successionPropertyTransmissionVariantRetainedRightLabel',
        mainTradeoff:
            'successionPropertyTransmissionVariantRetainedRightTradeoff',
      ),
    ];
  }

  static List<String> _formalities() {
    return const [
      'successionPropertyTransmissionFormalityEstimateValue',
      'successionPropertyTransmissionFormalityMortgageLiquidity',
      'successionPropertyTransmissionFormalityRetirementCapacity',
      'successionPropertyTransmissionFormalityDocumentAdvanceInheritance',
      'successionPropertyTransmissionFormalityNotary',
      'successionPropertyTransmissionFormalityLandRegistry',
    ];
  }

  static RetirementAffordabilityResult _retirementAffordability({
    required double annualIncome,
    required double annualCosts,
    required double liquidityAfterTransfer,
  }) {
    final annualMargin = annualIncome - annualCosts;
    final coverageYears =
        annualCosts > 0 ? liquidityAfterTransfer / annualCosts : 99.0;
    final reasons = <String>[
      if (annualMargin < 0)
        'successionPropertyTransmissionRetirementReasonNegativeMargin',
      if (coverageYears < _mintLiquidityCoverageReviewYears)
        'successionPropertyTransmissionRetirementReasonLiquidityCoverageBelowThreeYears',
    ];

    return RetirementAffordabilityResult(
      rank: 1,
      status: reasons.isEmpty
          ? PropertyTransmissionStatus.ok
          : PropertyTransmissionStatus.needsReview,
      annualMargin: _roundMoney(annualMargin),
      liquidityCoverageYears: _roundYears(coverageYears),
      reasons: reasons,
    );
  }

  static FamilyEqualizationResult _familyEqualization({
    required double economicTransferValue,
    required int heirsCount,
    required double liquidityAfterTransfer,
    required bool avancementHoirie,
  }) {
    if (heirsCount <= 1) {
      return const FamilyEqualizationResult(
        rank: 2,
        status: PropertyTransmissionStatus.notApplicable,
        immediateEqualizationNeedPerOtherHeir: 0,
        immediateEqualizationNeedTotal: 0,
        immediateEqualizationGap: 0,
        notes: [
          'successionPropertyTransmissionFamilyEqualizationNoOtherHeir',
        ],
      );
    }

    final needPerOtherHeir = economicTransferValue / heirsCount;
    final otherHeirsCount = math.max(0, heirsCount - 1);
    final totalEqualizationNeed = needPerOtherHeir * otherHeirsCount;
    final gap = math.max(0.0, totalEqualizationNeed - liquidityAfterTransfer);

    return FamilyEqualizationResult(
      rank: 2,
      status: gap <= 0
          ? PropertyTransmissionStatus.ok
          : PropertyTransmissionStatus.atRisk,
      immediateEqualizationNeedPerOtherHeir: _roundMoney(needPerOtherHeir),
      immediateEqualizationNeedTotal: _roundMoney(totalEqualizationNeed),
      immediateEqualizationGap: _roundMoney(gap),
      notes: [
        avancementHoirie
            ? 'successionPropertyTransmissionFamilyEqualizationAdvanceInheritance'
            : 'successionPropertyTransmissionFamilyEqualizationDispense',
        'successionPropertyTransmissionFamilyEqualizationOtherHeirsEquity',
      ],
    );
  }

  static int _roundMoney(double value) => value.round();

  static double _roundYears(double value) =>
      (value * 100).roundToDouble() / 100;
}
