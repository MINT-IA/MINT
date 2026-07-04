import 'dart:math' as math;

import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/biography/biography_fact.dart';
import 'package:mint_mobile/services/biography/freshness_decay_service.dart';
import 'package:mint_mobile/services/data_quest/data_quest_service.dart';
import 'package:mint_mobile/services/financial_core/property_transmission_calculator.dart';
import 'package:mint_mobile/services/mortgage_service.dart';

class DossierPayload {
  final String caseId;
  final String pdfSectionId;
  final String profileOwnerId;
  final String scenarioId;
  final DateTime generatedAt;
  final Map<String, dynamic> inputs;
  final Map<String, dynamic> outputs;
  final List<DossierAssumption> assumptions;
  final List<String> warnings;
  final List<String> nextQuestions;

  const DossierPayload({
    required this.caseId,
    required this.pdfSectionId,
    required this.profileOwnerId,
    required this.scenarioId,
    required this.generatedAt,
    required this.inputs,
    required this.outputs,
    required this.assumptions,
    required this.warnings,
    required this.nextQuestions,
  });

  Map<String, dynamic> toJson() => {
        'case_id': caseId,
        'pdf_section_id': pdfSectionId,
        'profile_owner_id': profileOwnerId,
        'scenario_id': scenarioId,
        'generated_at': generatedAt.toUtc().toIso8601String(),
        'inputs': inputs,
        'outputs': outputs,
        'assumptions': assumptions.map((a) => a.toJson()).toList(),
        'warnings': warnings,
        'next_questions': nextQuestions,
      };
}

class DossierAssumption {
  final String inputKey;
  final dynamic value;
  final String source;
  final String confidence;
  final bool sourceRequired;
  final bool confidenceRequired;

  const DossierAssumption({
    required this.inputKey,
    required this.value,
    required this.source,
    required this.confidence,
    this.sourceRequired = true,
    this.confidenceRequired = true,
  });

  Map<String, dynamic> toJson() => {
        'input_key': inputKey,
        'value': value,
        'source': source,
        'confidence': confidence,
        'source_required': sourceRequired,
        'confidence_required': confidenceRequired,
      };
}

class DossierPayloadService {
  DossierPayloadService._();

  static const List<String> _parentAnnualRetirementIncomeAnswerKeys = [
    'q_parent_annual_retirement_income',
    '_transmit_property_parent_annual_retirement_income',
  ];
  static const List<String> _parentLivingCostLedgerKeys = [
    'depenses.loyer',
    'depenses.assuranceMaladie',
    'depenses.electricite',
    'depenses.transport',
    'depenses.telecom',
    'depenses.fraisMedicaux',
    'depenses.autresDepensesFixes',
  ];

  static double get mortgageStressInterestRate =>
      reg('mortgage.theoretical_rate', hypothequeTauxTheorique);

  static DossierPayload buildP0Case({
    required String caseId,
    required Map<String, dynamic> answers,
    DateTime? generatedAt,
  }) {
    final spec = DataQuestCaseRegistry.p0Cases[caseId];
    if (spec == null) {
      throw ArgumentError.value(caseId, 'caseId', 'Unknown P0 dossier case');
    }
    final at = (generatedAt ?? DateTime.now()).toUtc();
    final profile = CoachProfile.fromWizardAnswers(answers);
    final profileOwnerId = _profileOwnerIdFor(answers);
    final scenarioId = _scenarioIdFor(caseId, answers, at);
    final factsByLedgerKey = dataQuestFactsFromProfile(
      profile: profile,
      answers: answers,
    );
    final nextQuestions = DataQuestService.planCase(
      caseId: caseId,
      answers: answers,
      now: at,
      factsByLedgerKey: factsByLedgerKey,
      includeUseful: true,
    ).asks.map((ask) => ask.questionId).toList(growable: false);

    return switch (caseId) {
      'first_salary_tax' => _firstSalaryTax(
          spec: spec,
          profile: profile,
          answers: answers,
          profileOwnerId: profileOwnerId,
          scenarioId: scenarioId,
          generatedAt: at,
          nextQuestions: nextQuestions,
        ),
      'buy_property' => _buyProperty(
          spec: spec,
          profile: profile,
          answers: answers,
          profileOwnerId: profileOwnerId,
          scenarioId: scenarioId,
          generatedAt: at,
          nextQuestions: nextQuestions,
        ),
      'transmit_property' => _transmitProperty(
          spec: spec,
          profile: profile,
          answers: answers,
          profileOwnerId: profileOwnerId,
          scenarioId: scenarioId,
          generatedAt: at,
          nextQuestions: nextQuestions,
        ),
      _ => throw ArgumentError.value(caseId, 'caseId', 'Unsupported P0 case'),
    };
  }

  static String _profileOwnerIdFor(Map<String, dynamic> answers) {
    final explicit = _string(
      _answer(answers, const ['_profile_owner_id', '_coach_profile_owner_id']),
    );
    if (explicit != null && explicit != 'local_demo_pending') return explicit;
    throw StateError(
      'Dossier payload requires a resolved _coach_profile_owner_id before '
      'buildP0Case().',
    );
  }

  static String _scenarioIdFor(
    String caseId,
    Map<String, dynamic> answers,
    DateTime generatedAt,
  ) {
    final explicit = _string(
      _answer(answers, ['_${caseId}_scenario_id', '_scenario_id']),
    );
    if (explicit != null) return explicit;
    return '${caseId}_${generatedAt.millisecondsSinceEpoch}';
  }

  static Map<String, BiographyFact> dataQuestFactsFromProfile({
    required CoachProfile profile,
    required Map<String, dynamic> answers,
  }) {
    final facts = <String, BiographyFact>{};

    void addFact(String fieldPath, DateTime updatedAt) {
      if (!_hasLedgerEvidence(profile, fieldPath)) return;
      final value = _profileValueForField(profile, fieldPath);
      if (value == null) return;
      final fact = BiographyFact(
        id: 'profile:$fieldPath',
        factType: _factTypeForFieldPath(fieldPath),
        fieldPath: fieldPath,
        value: value.toString(),
        source: _factSourceFromProfile(profile.dataSources[fieldPath]),
        sourceDate: profile.dataSourceDates[fieldPath],
        createdAt: updatedAt,
        updatedAt: updatedAt,
        freshnessCategory:
            FreshnessDecayService.kFieldFreshnessCategory[fieldPath] ??
                'annual',
      );
      facts[fieldPath] = fact;
      for (final alias in _dataQuestLedgerAliases(fieldPath)) {
        facts[alias] = fact;
      }
    }

    for (final entry in profile.dataTimestamps.entries) {
      addFact(entry.key, entry.value);
    }
    final retirementIncome = _parentAnnualRetirementIncomeEvidence(
      profile: profile,
      answers: answers,
    );
    if (retirementIncome.value != null && retirementIncome.sourceDate != null) {
      facts['parentAnnualRetirementIncome'] = BiographyFact(
        id: 'profile:parentAnnualRetirementIncome',
        factType: FactType.salary,
        fieldPath: 'parentAnnualRetirementIncome',
        value: retirementIncome.value!.toString(),
        source: retirementIncome.source == ProfileDataSource.userInput.name
            ? FactSource.userInput
            : FactSource.coach,
        sourceDate: retirementIncome.sourceDate,
        createdAt: retirementIncome.sourceDate!,
        updatedAt: retirementIncome.sourceDate!,
        freshnessCategory: FreshnessDecayService
                .kFieldFreshnessCategory['parentAnnualRetirementIncome'] ??
            'annual',
      );
    }
    final livingCosts = _parentAnnualLivingCosts(
      profile: profile,
      answers: answers,
    );
    if (livingCosts.annualCosts != null && livingCosts.sourceDate != null) {
      facts['parentAnnualLivingCosts'] = BiographyFact(
        id: 'profile:parentAnnualLivingCosts',
        factType: FactType.userDecision,
        fieldPath: 'parentAnnualLivingCosts',
        value: livingCosts.annualCosts!.toString(),
        source:
            livingCosts.isComplete ? FactSource.userInput : FactSource.coach,
        sourceDate: livingCosts.sourceDate,
        createdAt: livingCosts.sourceDate!,
        updatedAt: livingCosts.sourceDate!,
        freshnessCategory: FreshnessDecayService
                .kFieldFreshnessCategory['parentAnnualLivingCosts'] ??
            'volatile',
      );
    }
    return facts;
  }

  static List<String> _dataQuestLedgerAliases(String fieldPath) {
    return switch (fieldPath) {
      'salaireBrutMensuel' => const ['incomeGrossYearly'],
      'prevoyance.avoirLppTotal' => const ['avoirLpp'],
      'prevoyance.totalEpargne3a' => const ['pillar3aBalance'],
      'prevoyance.renteAVSEstimeeMensuelle' => const [
          'prevoyance.renteAVSEstimeeMensuelle',
        ],
      'prevoyance.projectedRenteLpp' => const [
          'prevoyance.projectedRenteLpp',
        ],
      'patrimoine.propertyMarketValue' => const [
          'propertyMarketValue',
          'patrimoine.propertyMarketValue',
        ],
      'patrimoine.targetPropertyValue' => const [
          'targetPropertyValue',
          'patrimoine.targetPropertyValue',
        ],
      'patrimoine.epargneLiquide' => const ['parentLiquidAssets'],
      'nombreEnfants' => const ['heirsCount'],
      _ => const [],
    };
  }

  static FactType _factTypeForFieldPath(String fieldPath) {
    if (fieldPath.contains('mortgage')) return FactType.mortgageDebt;
    if (fieldPath.contains('avoirLpp') ||
        fieldPath.contains('lpp') ||
        fieldPath.contains('Lpp')) {
      return FactType.lppCapital;
    }
    if (fieldPath.contains('3a')) return FactType.threeACapital;
    if (fieldPath.contains('avs') || fieldPath.contains('Avs')) {
      return FactType.avsContributionYears;
    }
    if (fieldPath == 'canton' || fieldPath == 'commune') {
      return FactType.canton;
    }
    if (fieldPath.contains('employment')) return FactType.employmentStatus;
    if (fieldPath.contains('household') || fieldPath.contains('conjoint')) {
      return FactType.civilStatus;
    }
    if (fieldPath.contains('mortgage') || fieldPath.contains('hypotheque')) {
      return FactType.mortgageDebt;
    }
    return FactType.salary;
  }

  static FactSource _factSourceFromProfile(ProfileDataSource? source) {
    return switch (source) {
      ProfileDataSource.certificate ||
      ProfileDataSource.openBanking =>
        FactSource.document,
      ProfileDataSource.crossValidated => FactSource.userEdit,
      ProfileDataSource.userInput => FactSource.userInput,
      ProfileDataSource.estimated || null => FactSource.coach,
    };
  }

  static Object? _profileValueForField(CoachProfile profile, String fieldPath) {
    return switch (fieldPath) {
      'salaireBrutMensuel' => profile.revenuBrutAnnuel,
      'canton' => profile.canton,
      'birthYear' => profile.birthYear,
      'targetRetirementAge' => profile.targetRetirementAge,
      'has2ndPillar' => profile.prevoyance.avoirLppTotal != null,
      'prevoyance.avoirLppTotal' => profile.prevoyance.avoirLppTotal,
      'prevoyance.totalEpargne3a' => profile.prevoyance.totalEpargne3a,
      'prevoyance.renteAVSEstimeeMensuelle' =>
        profile.prevoyance.renteAVSEstimeeMensuelle,
      'prevoyance.projectedRenteLpp' => profile.prevoyance.projectedRenteLpp,
      'patrimoine.propertyMarketValue' =>
        profile.patrimoine.propertyMarketValue,
      'patrimoine.targetPropertyValue' =>
        profile.patrimoine.targetPropertyValue,
      'patrimoine.epargneLiquide' => profile.patrimoine.epargneLiquide,
      'patrimoine.mortgageBalance' => profile.patrimoine.mortgageBalance,
      'nombreEnfants' => profile.nombreEnfants,
      _ => null,
    };
  }

  static DossierPayload _firstSalaryTax({
    required DataQuestCaseSpec spec,
    required CoachProfile profile,
    required Map<String, dynamic> answers,
    required String profileOwnerId,
    required String scenarioId,
    required DateTime generatedAt,
    required List<String> nextQuestions,
  }) {
    final hasSecondPillar = _bool(_answer(answers, ['q_has_pension_fund']));
    final grossIncome = _num(_answer(answers, ['q_gross_salary_annual'])) ??
        (_hasLedgerEvidence(profile, 'salaireBrutMensuel')
            ? profile.revenuBrutAnnuel
            : null);
    final annual3a = _num(_answer(answers, ['q_3a_annual_contribution'])) ?? 0;
    final missingCeilingInputs = <String>[
      if (grossIncome == null || grossIncome <= 0) 'incomeGrossYearly',
      if (hasSecondPillar == null) 'has2ndPillar',
    ];
    final ceiling = missingCeilingInputs.isEmpty
        ? (hasSecondPillar!
            ? reg('pillar3a.max_with_lpp', pilier3aPlafondAvecLpp)
            : math.min(
                grossIncome! *
                    reg('pillar3a.income_rate_without_lpp',
                        pilier3aTauxRevenuSansLpp),
                reg('pillar3a.max_without_lpp', pilier3aPlafondSansLpp),
              ))
        : null;
    final warnings = <String>[
      if (grossIncome == null || grossIncome <= 0)
        'Revenu brut annuel manquant: la fourchette fiscale reste à confirmer.',
      if (hasSecondPillar == null)
        'Statut LPP manquant: le plafond 3a ne peut pas être calculé.',
      if (ceiling != null && annual3a > ceiling)
        'Versement 3a supérieur au plafond indicatif: contrôle spécialiste requis.',
    ];

    return DossierPayload(
      caseId: spec.caseId,
      pdfSectionId: spec.pdfSectionId,
      profileOwnerId: profileOwnerId,
      scenarioId: scenarioId,
      generatedAt: generatedAt,
      inputs: {
        'birthYear': _input(
          profile: profile,
          inputKey: 'birthYear',
          ledgerKey: 'birthYear',
          value: profile.birthYear,
          answerPresent: answers.containsKey('q_birth_year') ||
              answers.containsKey('q_date_of_birth'),
        ),
        'canton': _input(
          profile: profile,
          inputKey: 'canton',
          ledgerKey: 'canton',
          value: profile.canton,
          answerPresent: answers.containsKey('q_canton'),
        ),
        'incomeGrossYearly': _input(
          profile: profile,
          inputKey: 'incomeGrossYearly',
          ledgerKey: 'salaireBrutMensuel',
          value: grossIncome,
          answerPresent: answers.containsKey('q_gross_salary_annual') ||
              _hasLedgerEvidence(profile, 'salaireBrutMensuel'),
        ),
        'has2ndPillar': _input(
          profile: profile,
          inputKey: 'has2ndPillar',
          ledgerKey: 'has2ndPillar',
          value: hasSecondPillar,
          answerPresent: answers.containsKey('q_has_pension_fund'),
        ),
        'pillar3aAnnual': _input(
          profile: profile,
          inputKey: 'pillar3aAnnual',
          ledgerKey: 'pillar3aAnnual',
          value: annual3a,
          answerPresent: answers.containsKey('q_3a_annual_contribution'),
        ),
      },
      outputs: {
        'tax_context': {
          'canton': profile.canton,
          'tax_year': generatedAt.year,
          'gross_income_yearly': grossIncome?.round(),
          'canton_sensitive': true,
          'specialist_review': 'tax_declaration_or_tax_advisor',
        },
        'pillar3a_ceiling_context': {
          'status': missingCeilingInputs.isEmpty
              ? 'ready_for_educational_estimate'
              : 'missing_required_input',
          'missing_inputs': missingCeilingInputs,
          'has_second_pillar': hasSecondPillar,
          'annual_ceiling': ceiling?.round(),
          'current_contribution': annual3a.round(),
          'remaining_room':
              ceiling == null ? null : math.max(0, ceiling - annual3a).round(),
          'source_ref': 'OPP3 art. 7',
        },
      },
      assumptions: [
        DossierAssumption(
          inputKey: 'taxYear',
          value: generatedAt.year,
          source: 'system_registry',
          confidence: 'medium',
        ),
      ],
      warnings: warnings,
      nextQuestions: nextQuestions,
    );
  }

  static DossierPayload _buyProperty({
    required DataQuestCaseSpec spec,
    required CoachProfile profile,
    required Map<String, dynamic> answers,
    required String profileOwnerId,
    required String scenarioId,
    required DateTime generatedAt,
    required List<String> nextQuestions,
  }) {
    final grossIncome = _num(_answer(answers, ['q_gross_salary_annual'])) ??
        (_hasLedgerEvidence(profile, 'salaireBrutMensuel')
            ? profile.revenuBrutAnnuelCouple
            : null);
    final liquidAssets = _num(_answer(answers, ['q_cash_total'])) ??
        (_hasLedgerEvidence(profile, 'patrimoine.epargneLiquide')
            ? profile.patrimoine.epargneLiquide
            : null);
    final targetPropertyValue = _num(_answer(
          answers,
          ['q_target_property_value'],
        )) ??
        (_hasLedgerEvidence(profile, 'patrimoine.targetPropertyValue')
            ? profile.patrimoine.targetPropertyValue
            : null);
    final targetPropertyAnswerPresent =
        answers.containsKey('q_target_property_value') ||
            _hasLedgerEvidence(profile, 'patrimoine.targetPropertyValue');
    final targetPropertyLedgerKey =
        answers.containsKey('q_target_property_value') ||
                _hasLedgerEvidence(profile, 'patrimoine.targetPropertyValue')
            ? 'patrimoine.targetPropertyValue'
            : null;
    final total3a =
        _num(_answer(answers, ['q_3a_total', '_coach_total_3a'])) ?? 0;
    final lpp = profile.prevoyance.avoirLppTotal ?? 0;
    final missingAffordabilityInputs = <String>[
      if (grossIncome == null || grossIncome <= 0) 'incomeGrossYearly',
      if (liquidAssets == null) 'patrimoine.epargneLiquide',
      if (targetPropertyValue == null || targetPropertyValue <= 0)
        'targetPropertyValue',
    ];
    final affordability = missingAffordabilityInputs.isEmpty
        ? AffordabilityCalculator.calculate(
            revenuBrutAnnuel: grossIncome!,
            epargneDispo: liquidAssets!,
            avoir3a: total3a,
            avoirLpp: lpp,
            prixAchat: targetPropertyValue!,
            canton: profile.canton,
          )
        : null;
    final warnings = <String>[
      ...missingAffordabilityInputs.map(
        (input) => 'Donnée requise à confirmer: $input.',
      ),
      if (affordability != null && !affordability.capaciteOk)
        'Taux d’effort hypothécaire indicatif supérieur à la règle des 33%.',
      if (affordability != null && !affordability.fondsPropresOk)
        'Fonds propres indicatifs inférieurs aux 20% usuels.',
      if (profile.patrimoine.mortgageRate == null)
        'Taux hypothécaire réel manquant: le dossier utilise surtout le taux de tenue.',
    ];

    return DossierPayload(
      caseId: spec.caseId,
      pdfSectionId: spec.pdfSectionId,
      profileOwnerId: profileOwnerId,
      scenarioId: scenarioId,
      generatedAt: generatedAt,
      inputs: {
        'householdType': _input(
          profile: profile,
          inputKey: 'householdType',
          ledgerKey: 'householdType',
          value: profile.etatCivil.name,
          answerPresent: answers.containsKey('q_civil_status'),
        ),
        'incomeGrossYearly': _input(
          profile: profile,
          inputKey: 'incomeGrossYearly',
          ledgerKey: 'salaireBrutMensuel',
          value: grossIncome,
          answerPresent: answers.containsKey('q_gross_salary_annual') ||
              _hasLedgerEvidence(profile, 'salaireBrutMensuel'),
        ),
        'patrimoine.epargneLiquide': _input(
          profile: profile,
          inputKey: 'patrimoine.epargneLiquide',
          ledgerKey: 'patrimoine.epargneLiquide',
          value: liquidAssets,
          answerPresent: answers.containsKey('q_cash_total') ||
              _hasLedgerEvidence(profile, 'patrimoine.epargneLiquide'),
        ),
        'targetPropertyValue': _input(
          profile: profile,
          inputKey: 'targetPropertyValue',
          ledgerKey:
              targetPropertyLedgerKey ?? 'patrimoine.targetPropertyValue',
          value: targetPropertyValue,
          answerPresent: targetPropertyAnswerPresent,
        ),
        'canton': _input(
          profile: profile,
          inputKey: 'canton',
          ledgerKey: 'canton',
          value: profile.canton,
          answerPresent: answers.containsKey('q_canton'),
        ),
        'patrimoine.mortgageRate': _input(
          profile: profile,
          inputKey: 'patrimoine.mortgageRate',
          ledgerKey: 'patrimoine.mortgageRate',
          value: profile.patrimoine.mortgageRate,
          answerPresent: answers.containsKey('q_mortgage_rate'),
        ),
      },
      outputs: {
        'affordability_context': {
          'status': affordability == null
              ? 'missing_required_input'
              : affordability.capaciteOk && affordability.fondsPropresOk
                  ? 'within_educational_capacity'
                  : 'needs_review',
          'missing_inputs': missingAffordabilityInputs,
          'charges_ratio': affordability?.ratioCharges,
          'charges_theoriques_mensuelles':
              affordability?.chargesTheoriquesMensuelles.round(),
          'prix_max_accessible': affordability?.prixMaxAccessible.round(),
          'specialist_review': 'bank_or_mortgage_specialist',
        },
        'equity_context': {
          'status': affordability == null
              ? 'missing_required_input'
              : 'ready_for_educational_estimate',
          'missing_inputs': missingAffordabilityInputs,
          'fonds_propres_total': affordability?.fondsPropresTotal.round(),
          'fonds_propres_requis': affordability?.fondsPropresRequis.round(),
          'manque_fonds_propres': affordability?.manqueFondsPropres.round(),
          'lpp_utilise': affordability?.lppUtilise.round(),
        },
      },
      assumptions: [
        DossierAssumption(
          inputKey: 'stressInterestRate',
          value: mortgageStressInterestRate,
          source: 'system_assumption_asb_practice',
          confidence: 'medium',
        ),
      ],
      warnings: warnings,
      nextQuestions: nextQuestions,
    );
  }

  static DossierPayload _transmitProperty({
    required DataQuestCaseSpec spec,
    required CoachProfile profile,
    required Map<String, dynamic> answers,
    required String profileOwnerId,
    required String scenarioId,
    required DateTime generatedAt,
    required List<String> nextQuestions,
  }) {
    final retirementIncome = _parentAnnualRetirementIncomeEvidence(
      profile: profile,
      answers: answers,
    );
    final parentLiquidAssets = _num(_answer(answers, ['q_cash_total'])) ??
        (_hasLedgerEvidence(profile, 'patrimoine.epargneLiquide')
            ? profile.patrimoine.epargneLiquide
            : null);
    final livingCosts = _parentAnnualLivingCosts(
      profile: profile,
      answers: answers,
    );
    final parentAnnualLivingCosts = livingCosts.annualCosts;
    final inputSourceDates = <String, DateTime>{
      for (final entry in {
        'propertyMarketValue': 'patrimoine.propertyMarketValue',
        'mortgageBalance': 'patrimoine.mortgageBalance',
        'parentLiquidAssets': 'patrimoine.epargneLiquide',
      }.entries)
        if (profile.dataSourceDates[entry.value] != null)
          entry.key: profile.dataSourceDates[entry.value]!.toUtc(),
      if (retirementIncome.sourceDate != null)
        'parentAnnualRetirementIncome': retirementIncome.sourceDate!,
      if (livingCosts.sourceDate != null)
        'parentAnnualLivingCosts': livingCosts.sourceDate!,
    };
    final inputs = PropertyTransmissionInputs(
      canton: profile.canton,
      propertyMarketValue: profile.patrimoine.propertyMarketValue,
      mortgageBalance: profile.patrimoine.mortgageBalance,
      cashPaidByRecipient:
          _num(_answer(answers, ['_transmit_property_cash_paid_by_recipient'])),
      mortgageAssumedByRecipient: _num(
        _answer(answers, ['_transmit_property_mortgage_assumed_by_recipient']),
      ),
      parentLiquidAssets: parentLiquidAssets,
      parentAnnualRetirementIncome: retirementIncome.value,
      parentAnnualRetirementIncomeSource: retirementIncome.calculatorSource,
      parentAnnualRetirementIncomeSourceKeys: retirementIncome.derivedFrom,
      inputSourceDates: inputSourceDates,
      freshnessAsOf: generatedAt,
      parentAnnualLivingCosts: parentAnnualLivingCosts,
      heirsCount: _int(_answer(answers, ['q_children'])),
      recipientRelationship: _string(_answer(
              answers, ['_transmit_property_recipient_relationship'])) ??
          'descendant',
      retainedRight:
          _string(_answer(answers, ['_transmit_property_retained_right'])) ??
              'none',
      avancementHoirie:
          _bool(_answer(answers, ['_transmit_property_avancement_hoirie'])) ??
              true,
    );
    final result = PropertyTransmissionCalculator.compute(inputs);

    return DossierPayload(
      caseId: spec.caseId,
      pdfSectionId: spec.pdfSectionId,
      profileOwnerId: profileOwnerId,
      scenarioId: scenarioId,
      generatedAt: generatedAt,
      inputs: {
        'targetRetirementAge': _input(
          profile: profile,
          inputKey: 'targetRetirementAge',
          ledgerKey: 'targetRetirementAge',
          value: profile.effectiveRetirementAge,
          answerPresent: answers.containsKey('q_target_retirement_age'),
        ),
        'avoirLpp': _input(
          profile: profile,
          inputKey: 'avoirLpp',
          ledgerKey: 'prevoyance.avoirLppTotal',
          value: profile.prevoyance.avoirLppTotal,
          answerPresent: answers.containsKey('_coach_avoir_lpp') ||
              answers.containsKey('q_current_lpp_capital'),
        ),
        'pillar3aBalance': _input(
          profile: profile,
          inputKey: 'pillar3aBalance',
          ledgerKey: 'prevoyance.totalEpargne3a',
          value: profile.prevoyance.totalEpargne3a,
          answerPresent: answers.containsKey('q_3a_total') ||
              answers.containsKey('_coach_total_3a'),
        ),
        'patrimoine.epargneLiquide': _input(
          profile: profile,
          inputKey: 'patrimoine.epargneLiquide',
          ledgerKey: 'patrimoine.epargneLiquide',
          value: parentLiquidAssets,
          answerPresent: answers.containsKey('q_cash_total') ||
              _hasLedgerEvidence(profile, 'patrimoine.epargneLiquide'),
        ),
        'patrimoine.propertyMarketValue': _input(
          profile: profile,
          inputKey: 'patrimoine.propertyMarketValue',
          ledgerKey: 'patrimoine.propertyMarketValue',
          value: profile.patrimoine.propertyMarketValue,
          answerPresent: answers.containsKey('q_property_market_value') ||
              answers.containsKey('q_property_value'),
        ),
        'mortgageBalance': _input(
          profile: profile,
          inputKey: 'mortgageBalance',
          ledgerKey: 'patrimoine.mortgageBalance',
          value: profile.patrimoine.mortgageBalance,
          answerPresent: answers.containsKey('q_mortgage_balance'),
        ),
        'heirsCount': _input(
          profile: profile,
          inputKey: 'heirsCount',
          ledgerKey: 'nombreEnfants',
          value: profile.nombreEnfants,
          answerPresent: answers.containsKey('q_children'),
        ),
        'parentAnnualRetirementIncome': _input(
          profile: profile,
          inputKey: 'parentAnnualRetirementIncome',
          ledgerKey: 'parentAnnualRetirementIncome',
          value: retirementIncome.value,
          source: retirementIncome.source,
          confidence: retirementIncome.confidence,
          derivedFrom: retirementIncome.derivedFrom,
          formula: retirementIncome.formula,
          sourceDate: retirementIncome.sourceDate,
          answerPresent: retirementIncome.value != null,
        ),
        'parentAnnualLivingCosts': _input(
          profile: profile,
          inputKey: 'parentAnnualLivingCosts',
          ledgerKey: 'parentAnnualLivingCosts',
          value: parentAnnualLivingCosts,
          source: parentAnnualLivingCosts == null
              ? 'missing'
              : livingCosts.isComplete
                  ? 'userInput'
                  : 'partial_composed',
          confidence: parentAnnualLivingCosts == null
              ? 'low'
              : livingCosts.isComplete
                  ? 'medium'
                  : 'low',
          derivedFrom: livingCosts.derivedFrom,
          formula: livingCosts.formula,
          sourceDate: livingCosts.sourceDate,
          answerPresent: parentAnnualLivingCosts != null,
        ),
      },
      outputs: {
        'retirement_affordability': {
          'status': result.retirementAffordability.status.rawValue,
          'annual_margin': result.retirementAffordability.annualMargin,
          'liquidity_coverage_years':
              result.retirementAffordability.liquidityCoverageYears,
          'reasons': result.retirementAffordability.reasons,
        },
        'family_equalization': {
          'status': result.familyEqualization.status.rawValue,
          'need_per_other_heir':
              result.familyEqualization.immediateEqualizationNeedPerOtherHeir,
          'need_total':
              result.familyEqualization.immediateEqualizationNeedTotal,
          'gap': result.familyEqualization.immediateEqualizationGap,
          'notes': result.familyEqualization.notes,
        },
        'cantonal_review': {
          'canton': result.cantonalTax.canton,
          'requires_cantonal_review': result.cantonalTax.requiresCantonalReview,
          'notes': result.cantonalTax.notes,
        },
        'scenario_confidence': {
          'value': result.scenarioConfidence.rawValue,
          'rationale': result.scenarioConfidenceRationale.semanticsValue,
          'missing_inputs': result.missingInputs,
        },
        'living_costs_context': {
          'status': parentAnnualLivingCosts == null
              ? 'missing_required_input'
              : livingCosts.isComplete
                  ? 'complete_composition'
                  : 'partial_composition',
          'derived_from': livingCosts.derivedFrom,
          'missing_components': livingCosts.missingComponents,
        },
      },
      assumptions: [
        DossierAssumption(
          inputKey: 'cashPaidByRecipient',
          value: inputs.cashPaidByRecipient ?? 0,
          source: _assumptionSource(
            answers,
            '_transmit_property_cash_paid_by_recipient',
          ),
          confidence: inputs.cashPaidByRecipient == null ? 'low' : 'medium',
        ),
        DossierAssumption(
          inputKey: 'mortgageAssumedByRecipient',
          value: inputs.mortgageAssumedByRecipient ?? 0,
          source: _assumptionSource(
            answers,
            '_transmit_property_mortgage_assumed_by_recipient',
          ),
          confidence:
              inputs.mortgageAssumedByRecipient == null ? 'low' : 'medium',
        ),
        DossierAssumption(
          inputKey: 'recipientRelationship',
          value: inputs.recipientRelationship,
          source: _assumptionSource(
            answers,
            '_transmit_property_recipient_relationship',
          ),
          confidence: answers.containsKey(
            '_transmit_property_recipient_relationship',
          )
              ? 'medium'
              : 'low',
        ),
        DossierAssumption(
          inputKey: 'retainedRight',
          value: inputs.retainedRight,
          source: _assumptionSource(
            answers,
            '_transmit_property_retained_right',
          ),
          confidence: answers.containsKey('_transmit_property_retained_right')
              ? 'medium'
              : 'low',
        ),
        DossierAssumption(
          inputKey: 'avancementHoirie',
          value: inputs.avancementHoirie,
          source: _assumptionSource(
            answers,
            '_transmit_property_avancement_hoirie',
          ),
          confidence:
              answers.containsKey('_transmit_property_avancement_hoirie')
                  ? 'medium'
                  : 'low',
        ),
      ],
      warnings: [
        ...result.missingInputs.map(
          (input) => 'Donnée requise à confirmer: $input.',
        ),
        if (result.cantonalTax.requiresCantonalReview)
          'Fiscalité de donation/succession à confirmer selon le canton.',
        if (parentAnnualLivingCosts != null && !livingCosts.isComplete)
          'Coûts de vie annuels partiels: compléter les postes manquants avant décision.',
        if ((profile.prevoyance.avoirLppTotal ?? 0) > 0 ||
            profile.prevoyance.totalEpargne3a > 0)
          'Retrait en capital LPP/3a: impôt séparé à vérifier selon LIFD art. 38 et les barèmes cantonaux.',
        if (result.modelScope.requiresSpecialistReview)
          'Revue notaire/fiscaliste requise avant décision.',
      ],
      nextQuestions: nextQuestions,
    );
  }

  static Map<String, dynamic> _input({
    required CoachProfile profile,
    required String inputKey,
    required String ledgerKey,
    required dynamic value,
    required bool answerPresent,
    String? source,
    String? confidence,
    List<String> derivedFrom = const [],
    String? formula,
    DateTime? sourceDate,
  }) {
    final resolvedSource =
        source ?? _sourceFor(profile, ledgerKey, inputKey, answerPresent);
    final resolvedConfidence =
        confidence ?? _confidenceForSource(resolvedSource);
    return {
      'value': value,
      'source': resolvedSource,
      'confidence': resolvedConfidence,
      'updated_at': _timestampFor(profile, ledgerKey, inputKey)
          ?.toUtc()
          .toIso8601String(),
      'source_date': (sourceDate ?? profile.dataSourceDates[ledgerKey])
          ?.toUtc()
          .toIso8601String(),
      if (derivedFrom.isNotEmpty) 'derived_from': derivedFrom,
      if (formula != null) 'formula': formula,
    };
  }

  static dynamic _answer(Map<String, dynamic> answers, List<String> keys) {
    for (final key in keys) {
      if (answers.containsKey(key)) return answers[key];
    }
    return null;
  }

  static double? _num(dynamic value) {
    if (value == null || value is bool) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static int? _int(dynamic value) {
    if (value == null || value is bool) return null;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static bool? _bool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (['true', 'yes', 'oui', '1'].contains(normalized)) return true;
      if (['false', 'no', 'non', '0'].contains(normalized)) return false;
    }
    return null;
  }

  static String? _string(dynamic value) {
    if (value == null) return null;
    final string = value.toString().trim();
    return string.isEmpty ? null : string;
  }

  static DateTime? _timestampFor(
    CoachProfile profile,
    String ledgerKey,
    String inputKey,
  ) {
    return profile.dataTimestamps[ledgerKey] ??
        profile.dataTimestamps[inputKey];
  }

  static String _sourceFor(
    CoachProfile profile,
    String ledgerKey,
    String inputKey,
    bool answerPresent,
  ) {
    final source =
        profile.dataSources[ledgerKey] ?? profile.dataSources[inputKey];
    if (source != null) return source.name;
    return answerPresent ? ProfileDataSource.userInput.name : 'missing';
  }

  static String _confidenceForSource(String source) {
    return switch (source) {
      'openBanking' || 'certificate' || 'crossValidated' => 'high',
      'userInput' => 'medium',
      'estimated' => 'low',
      _ => 'low',
    };
  }

  static String _assumptionSource(
    Map<String, dynamic> answers,
    String answerKey,
  ) {
    return answers.containsKey(answerKey) ? 'userInput' : 'scenario_default';
  }

  static bool _hasLedgerEvidence(
    CoachProfile profile,
    String ledgerKey, [
    String? inputKey,
  ]) {
    return profile.dataSources.containsKey(ledgerKey) ||
        (inputKey != null && profile.dataSources.containsKey(inputKey));
  }

  static _RetirementIncomeEvidence _parentAnnualRetirementIncomeEvidence({
    required CoachProfile profile,
    required Map<String, dynamic> answers,
  }) {
    final explicit = _num(
      _answer(answers, _parentAnnualRetirementIncomeAnswerKeys),
    );
    if (explicit != null) {
      final sourceDate =
          profile.dataSourceDates['parentAnnualRetirementIncome']?.toUtc() ??
              profile.dataTimestamps['parentAnnualRetirementIncome']?.toUtc();
      return _RetirementIncomeEvidence(
        value: explicit,
        source: ProfileDataSource.userInput.name,
        confidence: 'medium',
        sourceDate: sourceDate,
      );
    }

    final avsMonthly = profile.prevoyance.renteAVSEstimeeMensuelle;
    final lppAnnual = profile.prevoyance.projectedRenteLpp;
    if (avsMonthly == null || lppAnnual == null) {
      return const _RetirementIncomeEvidence(
        value: null,
        source: 'missing',
        confidence: 'low',
      );
    }
    final derivedFrom = <String>[
      'prevoyance.renteAVSEstimeeMensuelle',
      'prevoyance.projectedRenteLpp',
    ];

    return _RetirementIncomeEvidence(
      value: (avsMonthly * 12) + lppAnnual,
      source: ProfileDataSource.estimated.name,
      confidence: 'medium',
      derivedFrom: derivedFrom,
      formula:
          '(prevoyance.renteAVSEstimeeMensuelle * 12) + prevoyance.projectedRenteLpp',
      sourceDate: _oldestEvidenceDateFor(profile, derivedFrom),
    );
  }

  static _LivingCostEvidence _parentAnnualLivingCosts({
    required CoachProfile profile,
    required Map<String, dynamic> answers,
  }) {
    final explicitAnnualCosts = _num(
      _answer(answers, const [
        'q_parent_annual_living_costs',
        '_transmit_property_parent_annual_living_costs',
      ]),
    );
    if (explicitAnnualCosts != null) {
      return _LivingCostEvidence(
        annualCosts: explicitAnnualCosts,
        derivedFrom: const ['parentAnnualLivingCosts'],
        missingComponents: const [],
        sourceDate: _oldestEvidenceDateFor(
          profile,
          const ['parentAnnualLivingCosts'],
        ),
        formula: 'parentAnnualLivingCosts',
      );
    }

    var monthlyTotal = 0.0;
    final derivedFrom = <String>[];

    void addMonthly({
      required String answerKey,
      required String ledgerKey,
      required double? profileValue,
      String? periodFrequencyKey,
      String? legacyPeriodFrequencyKey,
    }) {
      if (answers.containsKey(answerKey)) {
        final parsed = _num(answers[answerKey]);
        if (parsed != null) {
          final monthlyAmount = periodFrequencyKey != null
              ? _monthlyAmountForPeriodFrequency(
                  parsed,
                  answers,
                  primaryKey: periodFrequencyKey,
                  legacyKey: legacyPeriodFrequencyKey,
                )
              : parsed;
          if (monthlyAmount == null) return;
          monthlyTotal += monthlyAmount;
          derivedFrom.add(ledgerKey);
        }
        return;
      }
      if (_hasLedgerEvidence(profile, ledgerKey) && profileValue != null) {
        monthlyTotal += profileValue;
        derivedFrom.add(ledgerKey);
      }
    }

    addMonthly(
      answerKey: 'q_housing_cost_period_chf',
      ledgerKey: 'depenses.loyer',
      profileValue: profile.depenses.loyer,
      periodFrequencyKey: 'q_housing_cost_frequency',
      legacyPeriodFrequencyKey: 'q_pay_frequency',
    );
    addMonthly(
      answerKey: 'q_lamal_premium_monthly_chf',
      ledgerKey: 'depenses.assuranceMaladie',
      profileValue: profile.depenses.assuranceMaladie,
    );
    addMonthly(
      answerKey: '_coach_depenses_electricite',
      ledgerKey: 'depenses.electricite',
      profileValue: profile.depenses.electricite,
    );
    addMonthly(
      answerKey: '_coach_depenses_transport',
      ledgerKey: 'depenses.transport',
      profileValue: profile.depenses.transport,
    );
    addMonthly(
      answerKey: '_coach_depenses_telecom',
      ledgerKey: 'depenses.telecom',
      profileValue: profile.depenses.telecom,
    );
    addMonthly(
      answerKey: '_coach_depenses_frais_medicaux',
      ledgerKey: 'depenses.fraisMedicaux',
      profileValue: profile.depenses.fraisMedicaux,
    );
    final hasCatchallOtherCosts =
        answers.containsKey('_coach_depenses_autres') ||
            (_hasLedgerEvidence(profile, 'depenses.autresDepensesFixes') &&
                profile.depenses.autresDepensesFixes != null);
    if (hasCatchallOtherCosts) {
      addMonthly(
        answerKey: '_coach_depenses_autres',
        ledgerKey: 'depenses.autresDepensesFixes',
        profileValue: profile.depenses.autresDepensesFixes,
      );
    } else {
      addMonthly(
        answerKey: 'q_tax_provision_monthly_chf',
        ledgerKey: 'depenses.autresDepensesFixes',
        profileValue: null,
      );
      addMonthly(
        answerKey: 'q_other_fixed_costs_monthly_chf',
        ledgerKey: 'depenses.autresDepensesFixes',
        profileValue: null,
      );
      addMonthly(
        answerKey: 'q_debt_payments_period_chf',
        ledgerKey: 'depenses.autresDepensesFixes',
        profileValue: null,
        periodFrequencyKey: 'q_pay_frequency',
      );
    }

    return _LivingCostEvidence(
      annualCosts: derivedFrom.isEmpty ? null : monthlyTotal * 12,
      derivedFrom: derivedFrom.toSet().toList(growable: false),
      missingComponents: _parentLivingCostLedgerKeys
          .where((ledgerKey) => !derivedFrom.contains(ledgerKey))
          .toList(growable: false),
      sourceDate: _oldestEvidenceDateFor(profile, derivedFrom),
      formula: 'sum(monthly living-cost components) * 12',
    );
  }

  static double? _monthlyAmountForPeriodFrequency(
    double amount,
    Map<String, dynamic> answers, {
    required String primaryKey,
    String? legacyKey,
  }) {
    final primaryFrequency = _string(answers[primaryKey])?.toLowerCase();
    final legacyFrequency =
        legacyKey == null ? null : _string(answers[legacyKey])?.toLowerCase();
    final frequency = primaryFrequency ??
        (legacyFrequency == 'monthly' || legacyFrequency == 'mensuel'
            ? legacyFrequency
            : null);
    if (frequency == 'yearly' ||
        frequency == 'annual' ||
        frequency == 'annuel') {
      return amount / 12;
    }
    if (frequency == 'monthly' || frequency == 'mensuel') {
      return amount;
    }
    return null;
  }

  static DateTime? _oldestEvidenceDateFor(
    CoachProfile profile,
    List<String> ledgerKeys,
  ) {
    DateTime? oldest;
    for (final key in ledgerKeys) {
      final candidate = profile.dataSourceDates[key]?.toUtc() ??
          profile.dataTimestamps[key]?.toUtc();
      if (candidate == null) continue;
      if (oldest == null || candidate.isBefore(oldest)) {
        oldest = candidate;
      }
    }
    return oldest;
  }
}

class _LivingCostEvidence {
  final double? annualCosts;
  final List<String> derivedFrom;
  final List<String> missingComponents;
  final DateTime? sourceDate;
  final String formula;

  const _LivingCostEvidence({
    required this.annualCosts,
    required this.derivedFrom,
    required this.missingComponents,
    required this.sourceDate,
    required this.formula,
  });

  bool get isComplete =>
      annualCosts != null &&
      missingComponents.isEmpty &&
      derivedFrom.isNotEmpty;
}

class _RetirementIncomeEvidence {
  final double? value;
  final String source;
  final String confidence;
  final List<String> derivedFrom;
  final String? formula;
  final DateTime? sourceDate;

  const _RetirementIncomeEvidence({
    required this.value,
    required this.source,
    required this.confidence,
    this.derivedFrom = const [],
    this.formula,
    this.sourceDate,
  });

  String? get calculatorSource => source == 'missing' ? null : source;
}

class DossierPayloadSchemaValidator {
  DossierPayloadSchemaValidator._();

  static List<String> validateJsonAgainstSchema({
    required Map<String, dynamic> payload,
    required Map<String, dynamic> schema,
  }) {
    final errors = <String>[];
    for (final key in (schema['required'] as List).cast<String>()) {
      if (!payload.containsKey(key)) errors.add('missing required key: $key');
    }
    final properties = schema['properties'] as Map<String, dynamic>;
    final caseConst = (properties['case_id'] as Map<String, dynamic>)['const'];
    final sectionConst =
        (properties['pdf_section_id'] as Map<String, dynamic>)['const'];
    if (payload['case_id'] != caseConst) {
      errors.add('case_id expected $caseConst got ${payload['case_id']}');
    }
    if (payload['pdf_section_id'] != sectionConst) {
      errors.add(
        'pdf_section_id expected $sectionConst got ${payload['pdf_section_id']}',
      );
    }
    final inputs = payload['inputs'];
    if (inputs is! Map) {
      errors.add('inputs must be object');
    } else {
      final inputRequired =
          ((properties['inputs'] as Map<String, dynamic>)['required'] as List)
              .cast<String>();
      for (final key in inputRequired) {
        if (!inputs.containsKey(key)) errors.add('inputs missing $key');
      }
      for (final entry in inputs.entries) {
        final key = entry.key;
        final value = entry.value;
        if (key is! String) {
          errors.add('input key must be string: $key');
          continue;
        }
        if (value is! Map) {
          errors.add('input $key must be object');
          continue;
        }
        for (final metaKey in const [
          'value',
          'source',
          'confidence',
          'updated_at',
          'source_date',
        ]) {
          if (!value.containsKey(metaKey)) {
            errors.add('input $key missing metadata $metaKey');
          }
        }
        final source = value['source'];
        if (source is! String || source.trim().isEmpty) {
          errors.add('input $key source must be non-empty string');
        }
        final confidence = value['confidence'];
        if (!const {'low', 'medium', 'high'}.contains(confidence)) {
          errors.add('input $key confidence not allowed: $confidence');
        }
        final updatedAt = value['updated_at'];
        if (updatedAt != null &&
            DateTime.tryParse(updatedAt.toString()) == null) {
          errors.add('input $key updated_at must be ISO date-time or null');
        }
        final sourceDate = value['source_date'];
        if (sourceDate != null &&
            DateTime.tryParse(sourceDate.toString()) == null) {
          errors.add('input $key source_date must be ISO date-time or null');
        }
      }
    }
    final outputs = payload['outputs'];
    if (outputs is! Map) {
      errors.add('outputs must be object');
    } else {
      final outputRequired =
          ((properties['outputs'] as Map<String, dynamic>)['required'] as List)
              .cast<String>();
      for (final key in outputRequired) {
        if (!outputs.containsKey(key)) errors.add('outputs missing $key');
      }
    }
    final assumptions = payload['assumptions'];
    if (assumptions is! List) {
      errors.add('assumptions must be array');
    } else {
      final assumptionSchema = ((properties['assumptions']
          as Map<String, dynamic>)['items'] as Map<String, dynamic>);
      final allowed = (((assumptionSchema['properties']
                  as Map<String, dynamic>)['input_key']
              as Map<String, dynamic>)['enum'] as List)
          .cast<String>();
      for (var i = 0; i < assumptions.length; i += 1) {
        final assumption = assumptions[i];
        if (assumption is! Map) {
          errors.add('assumption[$i] must be object');
          continue;
        }
        final inputKey = assumption['input_key'];
        if (!allowed.contains(inputKey)) {
          errors.add('assumption input_key not allowed: $inputKey');
        }
        if (assumption['source'] is! String ||
            assumption['source'].toString().trim().isEmpty) {
          errors.add('assumption $inputKey source must be non-empty string');
        }
        if (!const {'low', 'medium', 'high'}
            .contains(assumption['confidence'])) {
          errors.add(
            'assumption $inputKey confidence not allowed: ${assumption['confidence']}',
          );
        }
        if (assumption['source_required'] != true) {
          errors.add('assumption $inputKey source_required must be true');
        }
        if (assumption['confidence_required'] != true) {
          errors.add('assumption $inputKey confidence_required must be true');
        }
      }
    }
    if (payload['warnings'] is! List) errors.add('warnings must be array');
    if (payload['next_questions'] is! List) {
      errors.add('next_questions must be array');
    }
    return errors;
  }
}
