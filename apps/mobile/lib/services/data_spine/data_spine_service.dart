import 'package:mint_mobile/models/budget_snapshot.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/data_spine_snapshot.dart';
import 'package:mint_mobile/services/budget_living_engine.dart';

abstract final class DataSpineService {
  static DataSpineSnapshot fromProfile(
    CoachProfile profile, {
    DateTime? now,
    BudgetSnapshot? budget,
  }) {
    final computedAt = now ?? DateTime.now();
    final resolvedBudget = budget ?? BudgetLivingEngine.compute(profile);
    return DataSpineSnapshot(
      situation: _situationFromProfile(profile),
      budget: resolvedBudget,
      pillars: _pillarsFromProfile(profile),
      trajectory: _trajectoryFromProfile(profile, resolvedBudget, computedAt),
      computedAt: computedAt,
    );
  }

  static FinancialSituation _situationFromProfile(CoachProfile profile) {
    return FinancialSituation(
      firstName:
          _value(profile.firstName, profile, 'firstName', sensitive: false),
      birthYear: _value(profile.birthYear == 0 ? null : profile.birthYear,
          profile, 'birthYear',
          sensitive: false),
      canton: _value(
          profile.canton.isEmpty ? null : profile.canton, profile, 'canton',
          sensitive: false),
      commune: _value(profile.commune, profile, 'commune', sensitive: false),
      grossAnnualIncome: _value(_positiveOrNull(profile.revenuBrutAnnuel),
          profile, 'revenuBrutAnnuel'),
      employmentStatus: _value(
          profile.employmentStatus, profile, 'employmentStatus',
          sensitive: false),
      monthlyHousingCost: _value(
          _explicitAmount(
            profile.depenses.loyer,
            profile,
            'housingCost',
            'depenses.loyer',
          ),
          profile,
          'depenses.loyer'),
      lamalPremiumMonthly: _value(
          _explicitAmount(
            profile.depenses.assuranceMaladie,
            profile,
            'lamalPremium',
            'depenses.assuranceMaladie',
          ),
          profile,
          'depenses.assuranceMaladie'),
      liquidSavings: _value(
          _explicitAmount(
            profile.patrimoine.epargneLiquide,
            profile,
            'liquidSavings',
            'patrimoine.epargneLiquide',
            allowZero: true,
          ),
          profile,
          'patrimoine.epargneLiquide'),
      investments: _value(_positiveOrNull(profile.patrimoine.investissements),
          profile, 'patrimoine.investissements'),
      totalDebt: _debtExposureValue(profile),
      housingStatus: _value(profile.housingStatus, profile, 'housingStatus',
          sensitive: false),
      activeGoalType:
          _value(profile.goalA.type, profile, 'goalA.type', sensitive: false),
    );
  }

  static PillarPosition _pillarsFromProfile(CoachProfile profile) {
    final p = profile.prevoyance;
    return PillarPosition(
      avs: AvsPosition(
        contributionYears: _pillarFact(
            p.anneesContribuees, profile, 'prevoyance.anneesContribuees'),
        gaps: _pillarFact(p.lacunesAVS, profile, 'prevoyance.lacunesAVS'),
        estimatedMonthlyPension: _pillarFact(p.renteAVSEstimeeMensuelle,
            profile, 'prevoyance.renteAVSEstimeeMensuelle'),
        ramd: _pillarFact(p.ramd, profile, 'prevoyance.ramd'),
      ),
      lpp: LppPosition(
        totalBalance:
            _pillarFact(p.avoirLppTotal, profile, 'prevoyance.avoirLppTotal'),
        mandatoryBalance: _pillarFact(
            p.avoirLppObligatoire, profile, 'prevoyance.avoirLppObligatoire'),
        supplementaryBalance: _pillarFact(p.avoirLppSurobligatoire, profile,
            'prevoyance.avoirLppSurobligatoire'),
        insuredSalary:
            _pillarFact(p.salaireAssure, profile, 'prevoyance.salaireAssure'),
        buybackMax:
            _pillarFact(p.rachatMaximum, profile, 'prevoyance.rachatMaximum'),
      ),
      pillar3a: Pillar3aPosition(
        totalBalance: _pillarFact(_positiveOrNull(p.totalEpargne3a), profile,
            'prevoyance.totalEpargne3a'),
        accountsCount: _pillarFact(
            p.nombre3a > 0 ? p.nombre3a : null, profile, 'prevoyance.nombre3a'),
        annualContribution: _pillarFact(
            profile.total3aMensuel > 0 ? profile.total3aMensuel * 12 : null,
            profile,
            'plannedContributions.3a'),
        canContribute: p.canContribute3a,
      ),
    );
  }

  static TrajectorySummary _trajectoryFromProfile(
    CoachProfile profile,
    BudgetSnapshot budget,
    DateTime now,
  ) {
    final currentMonthlyFree = budget.monthlyFree;
    final currentMonthlyCapacity = budget.present.monthlySavings +
        (currentMonthlyFree > 0 ? currentMonthlyFree : 0);
    final targetAmount = profile.goalA.targetAmount;
    final monthsToTarget = _monthsBetween(now, profile.goalA.targetDate);

    if (currentMonthlyFree < 0) {
      return TrajectorySummary(
        status: TrajectoryStatus.blocked,
        currentMonthlyFree: currentMonthlyFree,
        currentMonthlyCapacity: currentMonthlyCapacity,
        targetAmount: targetAmount,
        monthsToTarget: monthsToTarget,
        monthlyRequired: targetAmount != null && monthsToTarget > 0
            ? targetAmount / monthsToTarget
            : null,
        monthlyGap: null,
        nextLeverId: 'stabilize_budget',
      );
    }

    if (targetAmount == null || targetAmount <= 0 || monthsToTarget <= 0) {
      return TrajectorySummary(
        status: TrajectoryStatus.insufficientData,
        currentMonthlyFree: currentMonthlyFree,
        currentMonthlyCapacity: currentMonthlyCapacity,
        targetAmount: targetAmount,
        monthsToTarget: monthsToTarget > 0 ? monthsToTarget : null,
        monthlyRequired: null,
        monthlyGap: null,
        nextLeverId: 'define_target',
      );
    }

    final monthlyRequired = targetAmount / monthsToTarget;
    final monthlyGap = monthlyRequired - currentMonthlyCapacity;
    final status =
        monthlyGap <= 0 ? TrajectoryStatus.onTrack : TrajectoryStatus.drifting;

    return TrajectorySummary(
      status: status,
      currentMonthlyFree: currentMonthlyFree,
      currentMonthlyCapacity: currentMonthlyCapacity,
      targetAmount: targetAmount,
      monthsToTarget: monthsToTarget,
      monthlyRequired: monthlyRequired,
      monthlyGap: monthlyGap,
      nextLeverId: status == TrajectoryStatus.onTrack
          ? 'maintain_plan'
          : 'increase_monthly_capacity',
    );
  }

  static SpineValue<T> _value<T>(
    T? value,
    CoachProfile profile,
    String fieldPath, {
    bool sensitive = true,
  }) {
    return SpineValue<T>(
      value: value,
      meta: _metaFor(
        profile,
        fieldPath,
        hasValue: value != null,
        sensitive: sensitive,
      ),
    );
  }

  static PillarFact<T> _pillarFact<T>(
    T? value,
    CoachProfile profile,
    String fieldPath,
  ) {
    if (value == null) return PillarFact<T>.missing();
    return PillarFact<T>(
      value: value,
      state: _isEstimated(profile, fieldPath)
          ? PillarFactState.estimated
          : PillarFactState.known,
      meta: _metaFor(profile, fieldPath, hasValue: true),
    );
  }

  static SpineFieldMeta _metaFor(
    CoachProfile profile,
    String fieldPath, {
    required bool hasValue,
    bool sensitive = true,
  }) {
    if (!hasValue) return const SpineFieldMeta.missing();
    final source = profile.dataSources[fieldPath];
    final updatedAt = profile.dataTimestamps[fieldPath] ?? profile.updatedAt;
    return SpineFieldMeta(
      source: source,
      confidence: _confidenceFor(source),
      freshness: _freshnessFor(updatedAt),
      updatedAt: updatedAt,
      sensitive: sensitive,
      storageLocation: sensitive
          ? FieldStorageLocation.secureLocal
          : FieldStorageLocation.local,
      syncState: FieldSyncState.localOnly,
      aiSharingState: FieldAiSharingState.neverSent,
      deleteConsequence: FieldDeleteConsequence.clearsLocally,
    );
  }

  static FieldConfidence _confidenceFor(ProfileDataSource? source) {
    return switch (source) {
      ProfileDataSource.estimated => FieldConfidence.estimated,
      ProfileDataSource.userInput => FieldConfidence.known,
      ProfileDataSource.crossValidated => FieldConfidence.known,
      ProfileDataSource.certificate => FieldConfidence.known,
      ProfileDataSource.openBanking => FieldConfidence.known,
      null => FieldConfidence.inferred,
    };
  }

  static FieldFreshness _freshnessFor(DateTime? updatedAt) {
    if (updatedAt == null) return FieldFreshness.unknown;
    final age = DateTime.now().difference(updatedAt);
    return age.inDays > 365 ? FieldFreshness.stale : FieldFreshness.fresh;
  }

  static bool _isEstimated(CoachProfile profile, String fieldPath) {
    return profile.dataSources[fieldPath] == ProfileDataSource.estimated;
  }

  static double? _positiveOrNull(double value) => value > 0 ? value : null;

  // Monthly-only debt is a budget signal, not a certified principal.
  // Use a 24-month exposure proxy so Coach can reason about debt pressure
  // without pretending the remaining capital is known.
  static const _consumerDebtExposureHorizonMonths = 24;

  static SpineValue<double> _debtExposureValue(CoachProfile profile) {
    final totalDebt = profile.dettes.totalDettes;
    if (totalDebt > 0) {
      return _value(
        _explicitAmount(
          totalDebt,
          profile,
          'debt',
          'dettes.totalDettes',
          allowZero: true,
        ),
        profile,
        'dettes.totalDettes',
      );
    }

    final monthlyPayment = profile.dettes.totalMensualite;
    if (monthlyPayment > 0) {
      final updatedAt =
          profile.dataTimestamps['dettes.totalDettes'] ?? profile.updatedAt;
      return SpineValue<double>(
        value: monthlyPayment * _consumerDebtExposureHorizonMonths,
        meta: SpineFieldMeta(
          source: ProfileDataSource.estimated,
          confidence: FieldConfidence.estimated,
          freshness: _freshnessFor(updatedAt),
          updatedAt: updatedAt,
        ),
      );
    }

    if (profile.userProvidedFields.contains('debt')) {
      return _value(
        0,
        profile,
        'dettes.totalDettes',
      );
    }
    return const SpineValue<double>(
        value: null, meta: SpineFieldMeta.missing());
  }

  static double? _explicitAmount(
    double value,
    CoachProfile profile,
    String providedField,
    String fieldPath, {
    bool allowZero = false,
  }) {
    final amount =
        allowZero ? (value >= 0 ? value : null) : _positiveOrNull(value);
    if (amount == null) return null;
    if (profile.userProvidedFields.contains(providedField)) return amount;
    final source = profile.dataSources[fieldPath];
    if (source != null && source != ProfileDataSource.estimated) {
      return amount;
    }
    return null;
  }

  static int _monthsBetween(DateTime from, DateTime to) {
    var months = (to.year - from.year) * 12 + to.month - from.month;
    if (to.day < from.day) months -= 1;
    return months;
  }
}
