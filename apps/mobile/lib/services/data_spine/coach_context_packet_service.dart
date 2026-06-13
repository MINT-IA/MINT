import 'package:mint_mobile/models/coach_context_packet.dart';
import 'package:mint_mobile/models/data_spine_snapshot.dart';
import 'package:mint_mobile/services/data_spine/data_spine_readiness_digest_service.dart';

abstract final class CoachContextPacketService {
  static const allowedFactIds = <String>{
    'profile.canton',
    'profile.birth_year',
    'situation.gross_annual_income',
    'situation.monthly_housing_cost',
    'situation.lamal_premium_monthly',
    'situation.liquid_savings',
    'situation.investments',
    'situation.total_debt',
    'budget.monthly_net',
    'budget.monthly_free',
    'budget.monthly_capacity',
    'budget.monthly_charges',
    'pillar.avs.contribution_years',
    'pillar.avs.gaps',
    'pillar.avs.estimated_monthly_pension',
    'pillar.lpp.total_balance',
    'pillar.lpp.insured_salary',
    'pillar.lpp.buyback_max',
    'pillar.3a.total_balance',
    'pillar.3a.accounts_count',
    'pillar.3a.annual_contribution',
    'trajectory.status',
    'trajectory.monthly_required',
    'trajectory.monthly_gap',
  };

  static CoachContextPacket fromSpine(DataSpineSnapshot spine) {
    final facts = <CoachContextFact>[
      ..._situationFacts(spine.situation),
      ..._budgetFacts(spine),
      ..._pillarFacts(spine.pillars),
      ..._trajectoryFacts(spine.trajectory),
    ];

    return CoachContextPacket(
      computedAt: spine.computedAt,
      facts: facts,
      missingFields: _missingFields(spine),
      trajectory: _trajectoryContext(spine.trajectory),
      nextQuestions: _nextQuestions(spine),
      readiness: _readinessContext(spine),
    );
  }

  static List<CoachContextFact> _situationFacts(FinancialSituation situation) {
    return [
      if (situation.canton.hasValue)
        _factFromValue(
          id: 'profile.canton',
          domain: 'profile',
          fieldPath: 'situation.canton',
          value: situation.canton,
        ),
      if (situation.birthYear.hasValue)
        _factFromValue(
          id: 'profile.birth_year',
          domain: 'profile',
          fieldPath: 'situation.birthYear',
          value: situation.birthYear,
        ),
      if (situation.grossAnnualIncome.hasValue)
        _factFromValue(
          id: 'situation.gross_annual_income',
          domain: 'situation',
          fieldPath: 'situation.grossAnnualIncome',
          value: situation.grossAnnualIncome,
        ),
      if (situation.monthlyHousingCost.hasValue)
        _factFromValue(
          id: 'situation.monthly_housing_cost',
          domain: 'situation',
          fieldPath: 'situation.monthlyHousingCost',
          value: situation.monthlyHousingCost,
        ),
      if (situation.lamalPremiumMonthly.hasValue)
        _factFromValue(
          id: 'situation.lamal_premium_monthly',
          domain: 'situation',
          fieldPath: 'situation.lamalPremiumMonthly',
          value: situation.lamalPremiumMonthly,
        ),
      if (situation.liquidSavings.hasValue)
        _factFromValue(
          id: 'situation.liquid_savings',
          domain: 'situation',
          fieldPath: 'situation.liquidSavings',
          value: situation.liquidSavings,
        ),
      if (situation.investments.hasValue)
        _factFromValue(
          id: 'situation.investments',
          domain: 'situation',
          fieldPath: 'situation.investments',
          value: situation.investments,
        ),
      if (situation.totalDebt.hasValue)
        _factFromValue(
          id: 'situation.total_debt',
          domain: 'situation',
          fieldPath: 'situation.totalDebt',
          value: situation.totalDebt,
        ),
    ];
  }

  static List<CoachContextFact> _budgetFacts(DataSpineSnapshot spine) {
    final budget = spine.budget.present;
    return [
      _fact(
        id: 'budget.monthly_net',
        domain: 'budget',
        fieldPath: 'budget.present.monthlyNet',
        value: budget.monthlyNet,
      ),
      _fact(
        id: 'budget.monthly_free',
        domain: 'budget',
        fieldPath: 'budget.present.monthlyFree',
        value: budget.monthlyFree,
      ),
      _fact(
        id: 'budget.monthly_capacity',
        domain: 'budget',
        fieldPath: 'trajectory.currentMonthlyCapacity',
        value: spine.trajectory.currentMonthlyCapacity,
      ),
      _fact(
        id: 'budget.monthly_charges',
        domain: 'budget',
        fieldPath: 'budget.present.monthlyCharges',
        value: budget.monthlyCharges,
      ),
    ];
  }

  static List<CoachContextFact> _pillarFacts(PillarPosition pillars) {
    return [
      ..._pillarFact(
        id: 'pillar.avs.contribution_years',
        domain: 'pillar_avs',
        fieldPath: 'pillars.avs.contributionYears',
        fact: pillars.avs.contributionYears,
      ),
      ..._pillarFact(
        id: 'pillar.avs.gaps',
        domain: 'pillar_avs',
        fieldPath: 'pillars.avs.gaps',
        fact: pillars.avs.gaps,
      ),
      ..._pillarFact(
        id: 'pillar.avs.estimated_monthly_pension',
        domain: 'pillar_avs',
        fieldPath: 'pillars.avs.estimatedMonthlyPension',
        fact: pillars.avs.estimatedMonthlyPension,
      ),
      ..._pillarFact(
        id: 'pillar.lpp.total_balance',
        domain: 'pillar_lpp',
        fieldPath: 'pillars.lpp.totalBalance',
        fact: pillars.lpp.totalBalance,
      ),
      ..._pillarFact(
        id: 'pillar.lpp.insured_salary',
        domain: 'pillar_lpp',
        fieldPath: 'pillars.lpp.insuredSalary',
        fact: pillars.lpp.insuredSalary,
      ),
      ..._pillarFact(
        id: 'pillar.lpp.buyback_max',
        domain: 'pillar_lpp',
        fieldPath: 'pillars.lpp.buybackMax',
        fact: pillars.lpp.buybackMax,
      ),
      ..._pillarFact(
        id: 'pillar.3a.total_balance',
        domain: 'pillar_3a',
        fieldPath: 'pillars.pillar3a.totalBalance',
        fact: pillars.pillar3a.totalBalance,
      ),
      ..._pillarFact(
        id: 'pillar.3a.accounts_count',
        domain: 'pillar_3a',
        fieldPath: 'pillars.pillar3a.accountsCount',
        fact: pillars.pillar3a.accountsCount,
      ),
      ..._pillarFact(
        id: 'pillar.3a.annual_contribution',
        domain: 'pillar_3a',
        fieldPath: 'pillars.pillar3a.annualContribution',
        fact: pillars.pillar3a.annualContribution,
      ),
    ];
  }

  static List<CoachContextFact> _trajectoryFacts(TrajectorySummary trajectory) {
    return [
      _fact(
        id: 'trajectory.status',
        domain: 'trajectory',
        fieldPath: 'trajectory.status',
        value: trajectory.status.name,
      ),
      if (trajectory.monthlyRequired != null)
        _fact(
          id: 'trajectory.monthly_required',
          domain: 'trajectory',
          fieldPath: 'trajectory.monthlyRequired',
          value: trajectory.monthlyRequired!,
        ),
      if (trajectory.monthlyGap != null)
        _fact(
          id: 'trajectory.monthly_gap',
          domain: 'trajectory',
          fieldPath: 'trajectory.monthlyGap',
          value: trajectory.monthlyGap!,
        ),
    ];
  }

  static List<CoachMissingField> _missingFields(DataSpineSnapshot spine) {
    final missing = <CoachMissingField>[
      ..._missingSituationField(
        value: spine.situation.monthlyHousingCost,
        fieldPath: 'situation.monthlyHousingCost',
      ),
      ..._missingSituationField(
        value: spine.situation.lamalPremiumMonthly,
        fieldPath: 'situation.lamalPremiumMonthly',
      ),
      ..._missingPillarField(
        fact: spine.pillars.avs.contributionYears,
        fieldPath: 'pillars.avs.contributionYears',
        domain: 'pillar_avs',
      ),
      ..._missingPillarField(
        fact: spine.pillars.avs.gaps,
        fieldPath: 'pillars.avs.gaps',
        domain: 'pillar_avs',
      ),
      ..._missingPillarField(
        fact: spine.pillars.avs.estimatedMonthlyPension,
        fieldPath: 'pillars.avs.estimatedMonthlyPension',
        domain: 'pillar_avs',
      ),
      ..._missingPillarField(
        fact: spine.pillars.lpp.totalBalance,
        fieldPath: 'pillars.lpp.totalBalance',
        domain: 'pillar_lpp',
      ),
      ..._missingPillarField(
        fact: spine.pillars.lpp.insuredSalary,
        fieldPath: 'pillars.lpp.insuredSalary',
        domain: 'pillar_lpp',
      ),
      ..._missingPillarField(
        fact: spine.pillars.lpp.buybackMax,
        fieldPath: 'pillars.lpp.buybackMax',
        domain: 'pillar_lpp',
      ),
      ..._missingPillarField(
        fact: spine.pillars.pillar3a.totalBalance,
        fieldPath: 'pillars.pillar3a.totalBalance',
        domain: 'pillar_3a',
      ),
      ..._missingPillarField(
        fact: spine.pillars.pillar3a.accountsCount,
        fieldPath: 'pillars.pillar3a.accountsCount',
        domain: 'pillar_3a',
      ),
    ];
    if (spine.trajectory.targetAmount == null) {
      missing.add(const CoachMissingField(
        fieldPath: 'trajectory.targetAmount',
        domain: 'trajectory',
        reason: 'missing_target_amount',
      ));
    }
    return missing;
  }

  static CoachTrajectoryContext _trajectoryContext(
    TrajectorySummary trajectory,
  ) {
    return CoachTrajectoryContext(
      status: trajectory.status.name,
      currentMonthlyFree: trajectory.currentMonthlyFree,
      currentMonthlyCapacity: trajectory.currentMonthlyCapacity,
      targetAmount: trajectory.targetAmount,
      monthsToTarget: trajectory.monthsToTarget,
      monthlyRequired: trajectory.monthlyRequired,
      monthlyGap: trajectory.monthlyGap,
      nextLeverId: trajectory.nextLeverId,
    );
  }

  static List<CoachNextQuestion> _nextQuestions(DataSpineSnapshot spine) {
    return switch (spine.trajectory.status) {
      TrajectoryStatus.onTrack => const [
          CoachNextQuestion(
            id: 'confirm_plan_tracking',
            domain: 'trajectory',
            fieldPath: 'trajectory.status',
          ),
        ],
      TrajectoryStatus.blocked => const [
          CoachNextQuestion(
            id: 'review_fixed_charges',
            domain: 'budget',
            fieldPath: 'budget.present.monthlyFree',
          ),
        ],
      TrajectoryStatus.drifting => const [
          CoachNextQuestion(
            id: 'increase_monthly_capacity',
            domain: 'trajectory',
            fieldPath: 'trajectory.monthlyGap',
          ),
        ],
      TrajectoryStatus.insufficientData => const [
          CoachNextQuestion(
            id: 'define_target_amount',
            domain: 'trajectory',
            fieldPath: 'trajectory.targetAmount',
          ),
        ],
    };
  }

  static CoachReadinessContext _readinessContext(DataSpineSnapshot spine) {
    final digest = DataSpineReadinessDigestService.fromSpine(spine);
    return CoachReadinessContext(
      overallStatus: digest.overallStatus.name,
      sections: digest.sections
          .map(
            (section) => CoachReadinessSection(
              id: section.id,
              status: section.status.name,
              knownCount: section.knownCount,
              missingCount: section.missingCount,
            ),
          )
          .toList(growable: false),
      missingDomains: digest.missingDomains,
      nextActionId: digest.nextActionId,
    );
  }

  static List<CoachContextFact> _pillarFact<T extends Object>({
    required String id,
    required String domain,
    required String fieldPath,
    required PillarFact<T> fact,
  }) {
    if (fact.value == null || fact.state == PillarFactState.missing) {
      return const [];
    }
    return [
      _fact(
        id: id,
        domain: domain,
        fieldPath: fieldPath,
        value: fact.value!,
        meta: fact.meta,
        state: fact.state.name,
      ),
    ];
  }

  static List<CoachMissingField> _missingPillarField<T>({
    required PillarFact<T> fact,
    required String fieldPath,
    required String domain,
  }) {
    if (fact.state != PillarFactState.missing) return const [];
    return [
      CoachMissingField(
        fieldPath: fieldPath,
        domain: domain,
        reason: 'missing_fact',
      ),
    ];
  }

  static List<CoachMissingField> _missingSituationField<T extends Object>({
    required SpineValue<T> value,
    required String fieldPath,
  }) {
    if (value.hasValue) return const [];
    return [
      CoachMissingField(
        fieldPath: fieldPath,
        domain: 'budget',
        reason: 'missing_fact',
      ),
    ];
  }

  static CoachContextFact _factFromValue<T extends Object>({
    required String id,
    required String domain,
    required String fieldPath,
    required SpineValue<T> value,
  }) {
    return _fact(
      id: id,
      domain: domain,
      fieldPath: fieldPath,
      value: value.value!,
      meta: value.meta,
    );
  }

  static CoachContextFact _fact({
    required String id,
    required String domain,
    required String fieldPath,
    required Object value,
    SpineFieldMeta? meta,
    String? state,
  }) {
    assert(allowedFactIds.contains(id), 'Unexpected coach fact id: $id');
    return CoachContextFact(
      id: id,
      domain: domain,
      fieldPath: fieldPath,
      value: value,
      source: meta?.source?.name,
      confidence: (meta?.confidence ?? FieldConfidence.known).name,
      freshness: (meta?.freshness ?? FieldFreshness.unknown).name,
      state: state,
      updatedAt: meta?.updatedAt,
      storageLocation:
          (meta?.storageLocation ?? FieldStorageLocation.local).name,
      syncState: (meta?.syncState ?? FieldSyncState.localOnly).name,
      aiSharingState: FieldAiSharingState.sentToMintBackend.name,
      deleteConsequence:
          (meta?.deleteConsequence ?? FieldDeleteConsequence.clearsLocally)
              .name,
    );
  }
}
