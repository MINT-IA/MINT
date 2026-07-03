import 'package:mint_mobile/services/biography/biography_fact.dart';
import 'package:mint_mobile/services/biography/freshness_decay_service.dart';

enum DataQuestAskMode { collect, reconfirm, scenarioAssumption }

enum DataQuestTone { plain, gentle }

enum DataQuestStage { guard, required, useful }

class DataQuestFieldSpec {
  final String inputKey;
  final String? ledgerKey;
  final List<String> answerKeys;
  final String questionId;
  final int priority;
  final bool allowZero;

  const DataQuestFieldSpec({
    required this.inputKey,
    required this.ledgerKey,
    required this.answerKeys,
    required this.questionId,
    required this.priority,
    this.allowZero = false,
  });
}

class DataQuestCaseSpec {
  final String caseId;
  final String targetRoute;
  final String pdfSectionId;
  final String maestroFlowId;
  final bool heavyEvent;
  final List<DataQuestFieldSpec> guardFields;
  final List<DataQuestFieldSpec> requiredFields;
  final List<DataQuestFieldSpec> usefulFields;

  const DataQuestCaseSpec({
    required this.caseId,
    required this.targetRoute,
    required this.pdfSectionId,
    required this.maestroFlowId,
    required this.guardFields,
    required this.requiredFields,
    this.usefulFields = const [],
    this.heavyEvent = false,
  });
}

class DataQuestAsk {
  final String caseId;
  final String inputKey;
  final String? ledgerKey;
  final String questionId;
  final DataQuestAskMode mode;
  final DataQuestTone tone;
  final DataQuestStage stage;
  final dynamic priorValue;

  const DataQuestAsk({
    required this.caseId,
    required this.inputKey,
    required this.ledgerKey,
    required this.questionId,
    required this.mode,
    required this.tone,
    required this.stage,
    this.priorValue,
  });
}

class DataQuestPlan {
  final String caseId;
  final String targetRoute;
  final String pdfSectionId;
  final String maestroFlowId;
  final List<DataQuestAsk> asks;

  const DataQuestPlan({
    required this.caseId,
    required this.targetRoute,
    required this.pdfSectionId,
    required this.maestroFlowId,
    required this.asks,
  });

  bool get isSatisfied => asks.isEmpty;
}

class DataQuestCaseRegistry {
  DataQuestCaseRegistry._();

  static const p0Cases = <String, DataQuestCaseSpec>{
    'first_salary_tax': DataQuestCaseSpec(
      caseId: 'first_salary_tax',
      targetRoute: '/pilier-3a',
      pdfSectionId: 'dossier_first_salary_tax',
      maestroFlowId: 'pending',
      guardFields: [
        DataQuestFieldSpec(
          inputKey: 'incomeGrossYearly',
          ledgerKey: 'incomeGrossYearly',
          answerKeys: ['q_gross_salary_annual'],
          questionId: 'ask_income_gross_yearly',
          priority: 100,
        ),
        DataQuestFieldSpec(
          inputKey: 'canton',
          ledgerKey: 'canton',
          answerKeys: ['q_canton'],
          questionId: 'ask_canton',
          priority: 90,
        ),
        DataQuestFieldSpec(
          inputKey: 'birthYear',
          ledgerKey: 'birthYear',
          answerKeys: ['q_birth_year', 'q_date_of_birth'],
          questionId: 'ask_birth_year',
          priority: 80,
        ),
        DataQuestFieldSpec(
          inputKey: 'has2ndPillar',
          ledgerKey: 'has2ndPillar',
          answerKeys: ['q_has_pension_fund'],
          questionId: 'ask_has_second_pillar',
          priority: 70,
        ),
      ],
      requiredFields: [],
      usefulFields: [
        DataQuestFieldSpec(
          inputKey: 'pillar3aAnnual',
          ledgerKey: 'pillar3aAnnual',
          answerKeys: ['q_3a_annual_contribution'],
          questionId: 'ask_pillar3a_annual',
          priority: 50,
          allowZero: true,
        ),
      ],
    ),
    'buy_property': DataQuestCaseSpec(
      caseId: 'buy_property',
      targetRoute: '/hypotheque',
      pdfSectionId: 'dossier_buy_property',
      maestroFlowId: 'pending',
      guardFields: [
        DataQuestFieldSpec(
          inputKey: 'incomeGrossYearly',
          ledgerKey: 'incomeGrossYearly',
          answerKeys: ['q_gross_salary_annual'],
          questionId: 'ask_income_gross_yearly',
          priority: 100,
        ),
        DataQuestFieldSpec(
          inputKey: 'patrimoine.epargneLiquide',
          ledgerKey: 'patrimoine.epargneLiquide',
          answerKeys: ['q_cash_total'],
          questionId: 'ask_liquid_assets',
          priority: 95,
          allowZero: true,
        ),
        DataQuestFieldSpec(
          inputKey: 'targetPropertyValue',
          ledgerKey: 'targetPropertyValue',
          answerKeys: ['q_target_property_value'],
          questionId: 'ask_target_property_value',
          priority: 90,
        ),
        DataQuestFieldSpec(
          inputKey: 'householdType',
          ledgerKey: 'householdType',
          answerKeys: ['q_civil_status'],
          questionId: 'ask_household_type',
          priority: 80,
        ),
      ],
      requiredFields: [
        DataQuestFieldSpec(
          inputKey: 'canton',
          ledgerKey: 'canton',
          answerKeys: ['q_canton'],
          questionId: 'ask_canton',
          priority: 70,
        ),
        DataQuestFieldSpec(
          inputKey: 'patrimoine.mortgageRate',
          ledgerKey: 'patrimoine.mortgageRate',
          answerKeys: ['q_mortgage_rate'],
          questionId: 'ask_mortgage_rate',
          priority: 50,
          allowZero: true,
        ),
      ],
    ),
    'transmit_property': DataQuestCaseSpec(
      caseId: 'transmit_property',
      targetRoute: '/succession',
      pdfSectionId: 'dossier_transmit_property',
      maestroFlowId: 'phase2_data_quest_transmit_property',
      heavyEvent: true,
      guardFields: [
        DataQuestFieldSpec(
          inputKey: 'propertyMarketValue',
          ledgerKey: 'patrimoine.propertyMarketValue',
          answerKeys: ['q_property_market_value', 'q_property_value'],
          questionId: 'ask_property_market_value',
          priority: 105,
        ),
        DataQuestFieldSpec(
          inputKey: 'targetRetirementAge',
          ledgerKey: 'targetRetirementAge',
          answerKeys: ['q_target_retirement_age'],
          questionId: 'ask_target_retirement_age',
          priority: 100,
        ),
        DataQuestFieldSpec(
          inputKey: 'avoirLpp',
          ledgerKey: 'avoirLpp',
          answerKeys: ['_coach_avoir_lpp'],
          questionId: 'ask_lpp_assets',
          priority: 95,
          allowZero: true,
        ),
        DataQuestFieldSpec(
          inputKey: 'pillar3aBalance',
          ledgerKey: 'pillar3aBalance',
          answerKeys: ['q_3a_total', '_coach_total_3a'],
          questionId: 'ask_pillar3a_balance',
          priority: 90,
          allowZero: true,
        ),
        DataQuestFieldSpec(
          inputKey: 'parentLiquidAssets',
          ledgerKey: 'patrimoine.epargneLiquide',
          answerKeys: ['q_cash_total'],
          questionId: 'ask_parent_liquid_assets',
          priority: 85,
          allowZero: true,
        ),
        DataQuestFieldSpec(
          inputKey: 'parentAnnualRetirementIncome',
          ledgerKey: 'parentAnnualRetirementIncome',
          answerKeys: [
            'q_parent_annual_retirement_income',
            '_transmit_property_parent_annual_retirement_income',
          ],
          questionId: 'ask_parent_annual_retirement_income',
          priority: 80,
          allowZero: true,
        ),
        DataQuestFieldSpec(
          inputKey: 'parentAnnualLivingCosts',
          ledgerKey: 'parentAnnualLivingCosts',
          answerKeys: [
            'q_parent_annual_living_costs',
            '_transmit_property_parent_annual_living_costs',
          ],
          questionId: 'ask_parent_annual_living_costs',
          priority: 75,
        ),
      ],
      requiredFields: [
        DataQuestFieldSpec(
          inputKey: 'mortgageBalance',
          ledgerKey: 'patrimoine.mortgageBalance',
          answerKeys: ['q_mortgage_balance'],
          questionId: 'ask_mortgage_balance',
          priority: 70,
          allowZero: true,
        ),
        DataQuestFieldSpec(
          inputKey: 'heirsCount',
          ledgerKey: 'nombreEnfants',
          answerKeys: ['q_children'],
          questionId: 'ask_heirs_count',
          priority: 60,
          allowZero: true,
        ),
      ],
      usefulFields: [
        DataQuestFieldSpec(
          inputKey: 'cashPaidByRecipient',
          ledgerKey: null,
          answerKeys: ['_transmit_property_cash_paid_by_recipient'],
          questionId: 'ask_cash_paid_by_recipient',
          priority: 50,
          allowZero: true,
        ),
        DataQuestFieldSpec(
          inputKey: 'mortgageAssumedByRecipient',
          ledgerKey: null,
          answerKeys: ['_transmit_property_mortgage_assumed_by_recipient'],
          questionId: 'ask_mortgage_assumed_by_recipient',
          priority: 45,
          allowZero: true,
        ),
        DataQuestFieldSpec(
          inputKey: 'recipientRelationship',
          ledgerKey: null,
          answerKeys: ['_transmit_property_recipient_relationship'],
          questionId: 'ask_recipient_relationship',
          priority: 40,
        ),
        DataQuestFieldSpec(
          inputKey: 'retainedRight',
          ledgerKey: null,
          answerKeys: ['_transmit_property_retained_right'],
          questionId: 'ask_retained_right',
          priority: 35,
        ),
        DataQuestFieldSpec(
          inputKey: 'avancementHoirie',
          ledgerKey: null,
          answerKeys: ['_transmit_property_avancement_hoirie'],
          questionId: 'ask_avancement_hoirie',
          priority: 30,
        ),
        DataQuestFieldSpec(
          inputKey: 'canton',
          ledgerKey: 'canton',
          answerKeys: ['q_canton'],
          questionId: 'ask_canton',
          priority: 25,
        ),
      ],
    ),
  };
}

class DataQuestService {
  DataQuestService._();

  static DataQuestPlan planCase({
    required String caseId,
    required Map<String, dynamic> answers,
    required DateTime now,
    Map<String, BiographyFact> factsByLedgerKey = const {},
    bool includeUseful = false,
  }) {
    final spec = DataQuestCaseRegistry.p0Cases[caseId];
    if (spec == null) {
      throw ArgumentError.value(caseId, 'caseId', 'Unknown DataQuest case');
    }

    final tone = spec.heavyEvent ? DataQuestTone.gentle : DataQuestTone.plain;
    final guardAsks = _buildAsks(
      spec: spec,
      fields: spec.guardFields,
      answers: answers,
      factsByLedgerKey: factsByLedgerKey,
      now: now,
      stage: DataQuestStage.guard,
      tone: tone,
    );
    if (guardAsks.isNotEmpty) {
      return _plan(spec, guardAsks);
    }

    final requiredAsks = _buildAsks(
      spec: spec,
      fields: spec.requiredFields,
      answers: answers,
      factsByLedgerKey: factsByLedgerKey,
      now: now,
      stage: DataQuestStage.required,
      tone: tone,
    );
    if (requiredAsks.isNotEmpty) {
      return _plan(spec, requiredAsks);
    }

    if (includeUseful) {
      return _plan(
        spec,
        _buildAsks(
          spec: spec,
          fields: spec.usefulFields,
          answers: answers,
          factsByLedgerKey: factsByLedgerKey,
          now: now,
          stage: DataQuestStage.useful,
          tone: tone,
        ),
      );
    }

    return _plan(spec, const []);
  }

  static DataQuestPlan _plan(
    DataQuestCaseSpec spec,
    List<DataQuestAsk> asks,
  ) {
    return DataQuestPlan(
      caseId: spec.caseId,
      targetRoute: spec.targetRoute,
      pdfSectionId: spec.pdfSectionId,
      maestroFlowId: spec.maestroFlowId,
      asks: ([...asks]..sort((a, b) => _compareAsks(spec, a, b))),
    );
  }

  static List<DataQuestAsk> _buildAsks({
    required DataQuestCaseSpec spec,
    required List<DataQuestFieldSpec> fields,
    required Map<String, dynamic> answers,
    required Map<String, BiographyFact> factsByLedgerKey,
    required DateTime now,
    required DataQuestStage stage,
    required DataQuestTone tone,
  }) {
    final asks = <DataQuestAsk>[];
    final orderedFields = [...fields]
      ..sort((a, b) => b.priority.compareTo(a.priority));
    for (final field in orderedFields) {
      final prior = _answerFor(field, answers);
      final hasAnswer = _isAnswered(field, prior);
      final fact = field.ledgerKey == null
          ? null
          : factsByLedgerKey[field.ledgerKey] ??
              factsByLedgerKey[field.inputKey];
      final factPrior = _priorValueFromFact(fact);
      final hasFact = _isAnswered(field, factPrior);

      if (!hasAnswer && !hasFact) {
        final mode = field.ledgerKey == null
            ? DataQuestAskMode.scenarioAssumption
            : DataQuestAskMode.collect;
        asks.add(_ask(spec, field, mode, tone, stage));
      } else if (fact != null &&
          FreshnessDecayService.needsRefresh(fact, now)) {
        asks.add(
          _ask(
            spec,
            field,
            DataQuestAskMode.reconfirm,
            tone,
            stage,
            priorValue: hasAnswer ? prior : factPrior,
          ),
        );
      } else if (spec.heavyEvent &&
          field.ledgerKey != null &&
          hasAnswer &&
          !hasFact) {
        // Heavy life events need dated/provenanced facts. Legacy answer-map
        // values remain useful as priors, but must be reconfirmed before a
        // transmission/succession scenario treats them as decision-grade.
        asks.add(
          _ask(
            spec,
            field,
            DataQuestAskMode.reconfirm,
            tone,
            stage,
            priorValue: prior,
          ),
        );
      }
    }
    asks.sort((a, b) {
      final priorityA = _priorityOf(orderedFields, a.inputKey);
      final priorityB = _priorityOf(orderedFields, b.inputKey);
      return priorityB.compareTo(priorityA);
    });
    return asks;
  }

  static int _compareAsks(
    DataQuestCaseSpec spec,
    DataQuestAsk a,
    DataQuestAsk b,
  ) {
    final stageOrder = _stageRank(a.stage).compareTo(_stageRank(b.stage));
    if (stageOrder != 0) return stageOrder;
    return _priorityOfSpec(spec, b.inputKey)
        .compareTo(_priorityOfSpec(spec, a.inputKey));
  }

  static DataQuestAsk _ask(
    DataQuestCaseSpec spec,
    DataQuestFieldSpec field,
    DataQuestAskMode mode,
    DataQuestTone tone,
    DataQuestStage stage, {
    dynamic priorValue,
  }) {
    return DataQuestAsk(
      caseId: spec.caseId,
      inputKey: field.inputKey,
      ledgerKey: field.ledgerKey,
      questionId: field.questionId,
      mode: mode,
      tone: tone,
      stage: stage,
      priorValue: priorValue,
    );
  }

  static int _priorityOf(List<DataQuestFieldSpec> fields, String inputKey) {
    return fields.firstWhere((field) => field.inputKey == inputKey).priority;
  }

  static int _priorityOfSpec(DataQuestCaseSpec spec, String inputKey) {
    for (final field in [
      ...spec.guardFields,
      ...spec.requiredFields,
      ...spec.usefulFields,
    ]) {
      if (field.inputKey == inputKey) return field.priority;
    }
    return 0;
  }

  static int _stageRank(DataQuestStage stage) {
    return switch (stage) {
      DataQuestStage.guard => 0,
      DataQuestStage.required => 1,
      DataQuestStage.useful => 2,
    };
  }

  static dynamic _answerFor(
    DataQuestFieldSpec field,
    Map<String, dynamic> answers,
  ) {
    for (final answerKey in field.answerKeys) {
      if (answers.containsKey(answerKey)) return answers[answerKey];
    }
    return null;
  }

  static dynamic _priorValueFromFact(BiographyFact? fact) {
    if (fact == null) return null;
    final text = fact.value.trim();
    if (text.isEmpty) return null;
    final asInt = int.tryParse(text);
    if (asInt != null) return asInt;
    final asDouble = double.tryParse(text);
    if (asDouble != null) return asDouble;
    return text;
  }

  static bool _isAnswered(DataQuestFieldSpec field, dynamic value) {
    if (value == null) return false;
    if (value is String) return value.trim().isNotEmpty;
    if (value is num) return field.allowZero ? value >= 0 : value > 0;
    if (value is bool) return true;
    if (value is Iterable) return value.isNotEmpty;
    if (value is Map) return value.isNotEmpty;
    return true;
  }
}
