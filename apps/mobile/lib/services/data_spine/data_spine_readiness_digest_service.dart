import 'package:mint_mobile/models/budget_snapshot.dart';
import 'package:mint_mobile/models/data_spine_snapshot.dart';

abstract final class DataSpineReadinessDigestService {
  static DataSpineReadinessDigest fromSpine(DataSpineSnapshot spine) {
    final missingDomains = _missingDomains(spine);
    final sections = <DataSpineReadinessSection>[
      _situationSection(spine.situation),
      _budgetSection(spine.budget),
      _pillarsSection(spine.pillars),
      _trajectorySection(spine.trajectory),
    ];

    final overallStatus = sections.any(
      (section) => section.status == DataSpineReadinessStatus.blocked,
    )
        ? DataSpineReadinessStatus.blocked
        : sections.every(
            (section) => section.status == DataSpineReadinessStatus.ready,
          )
            ? DataSpineReadinessStatus.ready
            : DataSpineReadinessStatus.partial;

    return DataSpineReadinessDigest(
      overallStatus: overallStatus,
      sections: sections,
      missingDomains: missingDomains,
      nextActionId: _nextActionId(spine, missingDomains),
      computedAt: spine.computedAt,
    );
  }

  static DataSpineReadinessSection _situationSection(
    FinancialSituation situation,
  ) {
    final values = <SpineValue<Object?>>[
      situation.birthYear,
      situation.canton,
      situation.grossAnnualIncome,
      situation.monthlyHousingCost,
      situation.lamalPremiumMonthly,
      situation.liquidSavings,
      situation.totalDebt,
    ];
    return _section(
      id: 'situation',
      knownCount: values.where((value) => value.hasValue).length,
      totalCount: values.length,
    );
  }

  static DataSpineReadinessSection _budgetSection(
    BudgetSnapshot budget,
  ) {
    if (budget.monthlyFree < 0) {
      return const DataSpineReadinessSection(
        id: 'budget',
        status: DataSpineReadinessStatus.blocked,
        knownCount: 1,
        missingCount: 0,
      );
    }
    return const DataSpineReadinessSection(
      id: 'budget',
      status: DataSpineReadinessStatus.ready,
      knownCount: 1,
      missingCount: 0,
    );
  }

  static DataSpineReadinessSection _pillarsSection(PillarPosition pillars) {
    final facts = <PillarFact<Object?>>[
      pillars.avs.contributionYears,
      pillars.avs.gaps,
      pillars.avs.estimatedMonthlyPension,
      pillars.lpp.totalBalance,
      pillars.lpp.insuredSalary,
      pillars.lpp.buybackMax,
      pillars.pillar3a.totalBalance,
      pillars.pillar3a.accountsCount,
    ];
    final known = facts.where((fact) => fact.state != PillarFactState.missing);
    return _section(
      id: 'pillars',
      knownCount: known.length,
      totalCount: facts.length,
    );
  }

  static DataSpineReadinessSection _trajectorySection(
    TrajectorySummary trajectory,
  ) {
    return switch (trajectory.status) {
      TrajectoryStatus.blocked => const DataSpineReadinessSection(
          id: 'trajectory',
          status: DataSpineReadinessStatus.blocked,
          knownCount: 1,
          missingCount: 0,
        ),
      TrajectoryStatus.insufficientData => const DataSpineReadinessSection(
          id: 'trajectory',
          status: DataSpineReadinessStatus.partial,
          knownCount: 1,
          missingCount: 1,
        ),
      TrajectoryStatus.onTrack ||
      TrajectoryStatus.drifting =>
        const DataSpineReadinessSection(
          id: 'trajectory',
          status: DataSpineReadinessStatus.ready,
          knownCount: 1,
          missingCount: 0,
        ),
    };
  }

  static DataSpineReadinessSection _section({
    required String id,
    required int knownCount,
    required int totalCount,
  }) {
    final missingCount = totalCount - knownCount;
    return DataSpineReadinessSection(
      id: id,
      status: missingCount == 0
          ? DataSpineReadinessStatus.ready
          : DataSpineReadinessStatus.partial,
      knownCount: knownCount,
      missingCount: missingCount,
    );
  }

  static List<String> _missingDomains(DataSpineSnapshot spine) {
    final domains = <String>{
      if (_hasMissingSituation(spine.situation)) 'situation',
      if (spine.budget.monthlyFree < 0) 'budget',
      if (_hasMissingAvs(spine.pillars.avs)) 'pillar_avs',
      if (_hasMissingLpp(spine.pillars.lpp)) 'pillar_lpp',
      if (_hasMissing3a(spine.pillars.pillar3a)) 'pillar_3a',
      if (spine.trajectory.status == TrajectoryStatus.insufficientData)
        'trajectory',
    };
    return domains.toList(growable: false);
  }

  static String _nextActionId(
    DataSpineSnapshot spine,
    List<String> missingDomains,
  ) {
    if (spine.budget.monthlyFree < 0 ||
        spine.trajectory.status == TrajectoryStatus.blocked) {
      return 'stabilize_budget';
    }
    if (spine.trajectory.status == TrajectoryStatus.insufficientData) {
      return 'define_target';
    }
    if (missingDomains.contains('pillar_avs')) return 'complete_pillar_avs';
    if (missingDomains.contains('pillar_lpp')) return 'complete_pillar_lpp';
    if (missingDomains.contains('pillar_3a')) return 'complete_pillar_3a';
    if (missingDomains.contains('situation')) return 'complete_situation';
    return spine.trajectory.nextLeverId;
  }

  static bool _hasMissingSituation(FinancialSituation situation) {
    return !situation.birthYear.hasValue ||
        !situation.canton.hasValue ||
        !situation.grossAnnualIncome.hasValue ||
        !situation.monthlyHousingCost.hasValue ||
        !situation.lamalPremiumMonthly.hasValue ||
        !situation.liquidSavings.hasValue ||
        !situation.totalDebt.hasValue;
  }

  static bool _hasMissingAvs(AvsPosition avs) {
    return avs.contributionYears.state == PillarFactState.missing ||
        avs.gaps.state == PillarFactState.missing ||
        avs.estimatedMonthlyPension.state == PillarFactState.missing;
  }

  static bool _hasMissingLpp(LppPosition lpp) {
    return lpp.totalBalance.state == PillarFactState.missing ||
        lpp.insuredSalary.state == PillarFactState.missing ||
        lpp.buybackMax.state == PillarFactState.missing;
  }

  static bool _hasMissing3a(Pillar3aPosition pillar3a) {
    return pillar3a.totalBalance.state == PillarFactState.missing ||
        pillar3a.accountsCount.state == PillarFactState.missing;
  }
}
