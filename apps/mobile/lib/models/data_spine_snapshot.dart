import 'package:mint_mobile/models/budget_snapshot.dart';
import 'package:mint_mobile/models/coach_profile.dart';

enum FieldConfidence {
  known,
  inferred,
  estimated,
  stale,
  missing,
}

enum FieldFreshness {
  fresh,
  stale,
  unknown,
}

enum FieldStorageLocation {
  local,
  secureLocal,
  backend,
  mixed,
  unknown,
}

enum FieldSyncState {
  localOnly,
  syncOff,
  pending,
  synced,
  conflict,
  deleted,
  unknown,
}

enum FieldAiSharingState {
  neverSent,
  redacted,
  bucketed,
  sentToMintBackend,
  sentToProvider,
  unknown,
}

enum FieldDeleteConsequence {
  clearsLocally,
  clearsBackend,
  anonymized,
  retentionException,
  pending,
  unknown,
}

enum PillarFactState {
  known,
  estimated,
  missing,
}

enum TrajectoryStatus {
  onTrack,
  drifting,
  blocked,
  insufficientData,
}

enum DataSpineReadinessStatus {
  ready,
  partial,
  blocked,
}

class SpineFieldMeta {
  final ProfileDataSource? source;
  final FieldConfidence confidence;
  final FieldFreshness freshness;
  final DateTime? updatedAt;
  final bool sensitive;
  final FieldStorageLocation storageLocation;
  final FieldSyncState syncState;
  final FieldAiSharingState aiSharingState;
  final FieldDeleteConsequence deleteConsequence;

  const SpineFieldMeta({
    this.source,
    required this.confidence,
    required this.freshness,
    this.updatedAt,
    this.sensitive = true,
    this.storageLocation = FieldStorageLocation.secureLocal,
    this.syncState = FieldSyncState.localOnly,
    this.aiSharingState = FieldAiSharingState.neverSent,
    this.deleteConsequence = FieldDeleteConsequence.clearsLocally,
  });

  const SpineFieldMeta.missing()
      : source = null,
        confidence = FieldConfidence.missing,
        freshness = FieldFreshness.unknown,
        updatedAt = null,
        sensitive = true,
        storageLocation = FieldStorageLocation.unknown,
        syncState = FieldSyncState.unknown,
        aiSharingState = FieldAiSharingState.neverSent,
        deleteConsequence = FieldDeleteConsequence.unknown;
}

class SpineValue<T> {
  final T? value;
  final SpineFieldMeta meta;

  const SpineValue({
    required this.value,
    required this.meta,
  });

  bool get hasValue => value != null;
}

class PillarFact<T> {
  final T? value;
  final PillarFactState state;
  final SpineFieldMeta meta;

  const PillarFact({
    required this.value,
    required this.state,
    required this.meta,
  });

  const PillarFact.missing()
      : value = null,
        state = PillarFactState.missing,
        meta = const SpineFieldMeta.missing();
}

class FinancialSituation {
  final SpineValue<String> firstName;
  final SpineValue<int> birthYear;
  final SpineValue<String> canton;
  final SpineValue<String> commune;
  final SpineValue<double> grossAnnualIncome;
  final SpineValue<String> employmentStatus;
  final SpineValue<double> monthlyHousingCost;
  final SpineValue<double> lamalPremiumMonthly;
  final SpineValue<double> liquidSavings;
  final SpineValue<double> investments;
  final SpineValue<double> totalDebt;
  final SpineValue<String> housingStatus;
  final SpineValue<GoalAType> activeGoalType;

  const FinancialSituation({
    required this.firstName,
    required this.birthYear,
    required this.canton,
    required this.commune,
    required this.grossAnnualIncome,
    required this.employmentStatus,
    required this.monthlyHousingCost,
    required this.lamalPremiumMonthly,
    required this.liquidSavings,
    required this.investments,
    required this.totalDebt,
    required this.housingStatus,
    required this.activeGoalType,
  });
}

class AvsPosition {
  final PillarFact<int> contributionYears;
  final PillarFact<int> gaps;
  final PillarFact<double> estimatedMonthlyPension;
  final PillarFact<double> ramd;

  const AvsPosition({
    required this.contributionYears,
    required this.gaps,
    required this.estimatedMonthlyPension,
    required this.ramd,
  });
}

class LppPosition {
  final PillarFact<double> totalBalance;
  final PillarFact<double> mandatoryBalance;
  final PillarFact<double> supplementaryBalance;
  final PillarFact<double> insuredSalary;
  final PillarFact<double> buybackMax;

  const LppPosition({
    required this.totalBalance,
    required this.mandatoryBalance,
    required this.supplementaryBalance,
    required this.insuredSalary,
    required this.buybackMax,
  });
}

class Pillar3aPosition {
  final PillarFact<double> totalBalance;
  final PillarFact<int> accountsCount;
  final PillarFact<double> annualContribution;
  final bool canContribute;

  const Pillar3aPosition({
    required this.totalBalance,
    required this.accountsCount,
    required this.annualContribution,
    required this.canContribute,
  });
}

class PillarPosition {
  final AvsPosition avs;
  final LppPosition lpp;
  final Pillar3aPosition pillar3a;

  const PillarPosition({
    required this.avs,
    required this.lpp,
    required this.pillar3a,
  });
}

class TrajectorySummary {
  final TrajectoryStatus status;
  final double currentMonthlyFree;
  final double currentMonthlyCapacity;
  final double? targetAmount;
  final int? monthsToTarget;
  final double? monthlyRequired;
  final double? monthlyGap;
  final String nextLeverId;

  const TrajectorySummary({
    required this.status,
    required this.currentMonthlyFree,
    required this.currentMonthlyCapacity,
    required this.targetAmount,
    required this.monthsToTarget,
    required this.monthlyRequired,
    required this.monthlyGap,
    required this.nextLeverId,
  });
}

class DataSpineReadinessSection {
  final String id;
  final DataSpineReadinessStatus status;
  final int knownCount;
  final int missingCount;

  const DataSpineReadinessSection({
    required this.id,
    required this.status,
    required this.knownCount,
    required this.missingCount,
  });
}

class DataSpineReadinessDigest {
  final DataSpineReadinessStatus overallStatus;
  final List<DataSpineReadinessSection> sections;
  final List<String> missingDomains;
  final String nextActionId;
  final DateTime computedAt;

  const DataSpineReadinessDigest({
    required this.overallStatus,
    required this.sections,
    required this.missingDomains,
    required this.nextActionId,
    required this.computedAt,
  });
}

class DataSpineSnapshot {
  final FinancialSituation situation;
  final BudgetSnapshot budget;
  final PillarPosition pillars;
  final TrajectorySummary trajectory;
  final DateTime computedAt;

  const DataSpineSnapshot({
    required this.situation,
    required this.budget,
    required this.pillars,
    required this.trajectory,
    required this.computedAt,
  });
}
