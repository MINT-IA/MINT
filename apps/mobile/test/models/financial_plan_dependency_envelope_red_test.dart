import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/financial_plan.dart';

const _hash =
    'mint-plan-dependency:v3:sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

FinancialPlan _plan({bool strictEnvelope = true}) => FinancialPlan(
      id: 'plan-v3',
      goalDescription: 'Objectif',
      goalCategory: 'goal_general',
      monthlyTarget: 1000,
      milestones: const [],
      projectedOutcome: 120000,
      targetDate: DateTime.utc(2030, 6, 30),
      generatedAt: DateTime.utc(2026, 7, 16, 9),
      profileHashAtGeneration: _hash,
      coachNarrative: 'mint-plan-narrative:v2:goal_general',
      confidenceLevel: 100,
      sources: const [],
      disclaimer: 'Éducatif.',
      goalAmount: strictEnvelope ? 120000 : null,
      profileOwnerId:
          strictEnvelope ? '11111111-1111-4111-8111-111111111111' : null,
      dependencySchemaVersion: strictEnvelope ? 3 : null,
      dependencyBranch: strictEnvelope ? 'general' : null,
      dependencyBasis: strictEnvelope ? 'none' : null,
      dependencyHash: strictEnvelope ? _hash : null,
      scenarioId:
          strictEnvelope ? '22222222-2222-4222-8222-222222222222' : null,
      inputAsOf: strictEnvelope ? DateTime.utc(2026, 7, 16, 9) : null,
      validUntil: strictEnvelope ? DateTime.utc(2030, 6, 30) : null,
    );

FinancialPlanProjectionAssumptions _noLppAssumptions({
  double? caisseReturnBase,
  double? caisseReturnLow,
  double? caisseReturnHigh,
  String salaryKind = 'notApplicable',
  double? annualSalary,
  String bonificationKind = 'notApplicable',
  double? annualBonificationRate,
  bool annualProjectionUsesWholeYears = false,
  bool requiresFundAuthorizationBefore63 = false,
  bool assumesPostReferenceGainfulActivity = false,
}) =>
    FinancialPlanProjectionAssumptions(
      caisseReturnBase: caisseReturnBase,
      caisseReturnLow: caisseReturnLow,
      caisseReturnHigh: caisseReturnHigh,
      supplementalMonthlySavingsReturn: 0,
      salaryBasis: FinancialPlanSalaryBasis(
        kind: salaryKind,
        annualChf: annualSalary,
      ),
      bonificationBasis: FinancialPlanBonificationBasis(
        kind: bonificationKind,
        annualRate: annualBonificationRate,
      ),
      projectionAsOf: DateTime.utc(2026, 7, 16, 9),
      annualProjectionUsesWholeYears: annualProjectionUsesWholeYears,
      requiresFundAuthorizationBefore63: requiresFundAuthorizationBefore63,
      assumesPostReferenceGainfulActivity: assumesPostReferenceGainfulActivity,
    );

FinancialPlanProjectionAssumptions _lppAssumptions({
  double base = 0.02,
  double low = 0.01,
  double high = 0.03,
  double supplementalReturn = 0,
  String salaryKind = 'monthlySalaryTimesTwelve',
  double? annualSalary = 96000,
  String bonificationKind = 'legalAgeSchedule',
  double? annualBonificationRate,
  DateTime? projectionAsOf,
  bool annualProjectionUsesWholeYears = true,
  bool requiresFundAuthorizationBefore63 = false,
  bool assumesPostReferenceGainfulActivity = false,
}) =>
    FinancialPlanProjectionAssumptions(
      caisseReturnBase: base,
      caisseReturnLow: low,
      caisseReturnHigh: high,
      supplementalMonthlySavingsReturn: supplementalReturn,
      salaryBasis: FinancialPlanSalaryBasis(
        kind: salaryKind,
        annualChf: annualSalary,
      ),
      bonificationBasis: FinancialPlanBonificationBasis(
        kind: bonificationKind,
        annualRate: annualBonificationRate,
      ),
      projectionAsOf: projectionAsOf ?? DateTime.utc(2026, 7, 16, 9),
      annualProjectionUsesWholeYears: annualProjectionUsesWholeYears,
      requiresFundAuthorizationBefore63: requiresFundAuthorizationBefore63,
      assumesPostReferenceGainfulActivity: assumesPostReferenceGainfulActivity,
    );

void main() {
  test('v3 dependency envelope persists exactly and legacy remains invalid',
      () {
    final plan = _plan();
    final decoded = FinancialPlan.fromJson(plan.toJson());

    expect(decoded.profileOwnerId, plan.profileOwnerId);
    expect(decoded.dependencySchemaVersion, 3);
    expect(decoded.dependencyBranch, 'general');
    expect(decoded.dependencyBasis, 'none');
    expect(decoded.dependencyHash, plan.dependencyHash);
    expect(decoded.scenarioId, plan.scenarioId);
    expect(decoded.inputAsOf, plan.inputAsOf);
    expect(decoded.validUntil, plan.validUntil);
    expect(decoded.hasValidDependencyEnvelope, isTrue);
    expect(_plan(strictEnvelope: false).hasValidDependencyEnvelope, isFalse);
  });

  test('v3 dependency envelope rejects every ambiguous authority shape', () {
    final valid = _plan().toJson();
    bool accepts(Map<String, dynamic> mutation) => FinancialPlan.fromJson(
          <String, dynamic>{...valid, ...mutation},
        ).hasValidDependencyEnvelope;

    expect(
      accepts({'profileOwnerId': 'AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA'}),
      isFalse,
    );
    expect(accepts({'scenarioId': 'not-a-uuid'}), isFalse);
    expect(accepts({'dependencySchemaVersion': 2}), isFalse);
    expect(accepts({'dependencyBranch': 'retirementLpp'}), isFalse);
    expect(accepts({'dependencyBasis': 'total/legalSchedule'}), isFalse);
    expect(accepts({'dependencyHash': _hash.replaceFirst('a', 'b')}), isFalse);
    expect(accepts({'goalAmount': 0}), isFalse);
    expect(
      accepts({'validUntil': DateTime.utc(2026, 7, 16, 9).toIso8601String()}),
      isFalse,
    );
  });

  test('retirement no-LPP envelope accepts only not-applicable assumptions',
      () {
    final valid = _plan().copyWith(
      goalCategory: 'goal_retirement_plan',
      dependencyBranch: 'retirementNoLpp',
      projectionAssumptions: _noLppAssumptions(),
    );

    expect(valid.hasValidDependencyEnvelope, isTrue);
    for (final malformed in <FinancialPlanProjectionAssumptions>[
      _noLppAssumptions(caisseReturnBase: 0.02),
      _noLppAssumptions(caisseReturnLow: 0.01),
      _noLppAssumptions(caisseReturnHigh: 0.03),
      _noLppAssumptions(salaryKind: 'monthlySalaryTimesTwelve'),
      _noLppAssumptions(annualSalary: 96000),
      _noLppAssumptions(bonificationKind: 'legalAgeSchedule'),
      _noLppAssumptions(annualBonificationRate: 0.18),
      _noLppAssumptions(annualProjectionUsesWholeYears: true),
      _noLppAssumptions(requiresFundAuthorizationBefore63: true),
      _noLppAssumptions(assumesPostReferenceGainfulActivity: true),
    ]) {
      expect(
        valid
            .copyWith(projectionAssumptions: malformed)
            .hasValidDependencyEnvelope,
        isFalse,
      );
    }
  });

  test('general envelope rejects every persisted projection assumption', () {
    expect(
      _plan()
          .copyWith(projectionAssumptions: _noLppAssumptions())
          .hasValidDependencyEnvelope,
      isFalse,
    );
  });

  test(
      'retirement LPP envelope requires exact calculator assumptions and bands',
      () {
    final valid = _plan().copyWith(
      goalCategory: 'goal_retirement_plan',
      dependencyBranch: 'retirementLpp',
      dependencyBasis: 'total/legalSchedule',
      projectedLow: 250000,
      projectedOutcome: 300000,
      projectedHigh: 350000,
      projectionAssumptions: _lppAssumptions(),
    );

    expect(valid.hasValidDependencyEnvelope, isTrue);
    for (final malformed in <FinancialPlan>[
      valid.copyWith(projectedLow: double.nan),
      valid.copyWith(projectedHigh: double.infinity),
      valid.copyWith(projectedLow: 310000),
      valid.copyWith(projectedHigh: 290000),
      valid.copyWith(projectionAssumptions: _lppAssumptions(base: -0.001)),
      valid.copyWith(projectionAssumptions: _lppAssumptions(base: 0.101)),
      valid.copyWith(
        projectionAssumptions: _lppAssumptions(base: 0, low: 0, high: 0.02),
      ),
      valid.copyWith(
        projectionAssumptions:
            _lppAssumptions(base: 0.10, low: 0.08, high: 0.10),
      ),
      valid.copyWith(
        projectionAssumptions: _lppAssumptions(supplementalReturn: 0.01),
      ),
      valid.copyWith(
        projectionAssumptions:
            _lppAssumptions(salaryKind: 'declaredInsuredSalary'),
      ),
      valid.copyWith(
        projectionAssumptions: _lppAssumptions(annualSalary: 0),
      ),
      valid.copyWith(
        projectionAssumptions:
            _lppAssumptions(bonificationKind: 'declaredFundRate'),
      ),
      valid.copyWith(
        projectionAssumptions: _lppAssumptions(annualBonificationRate: 0.18),
      ),
      valid.copyWith(
        projectionAssumptions: _lppAssumptions(
          projectionAsOf: DateTime.utc(2026, 7, 16, 9, 0, 1),
        ),
      ),
      valid.copyWith(
        projectionAssumptions:
            _lppAssumptions(annualProjectionUsesWholeYears: false),
      ),
      valid.copyWith(
        projectionAssumptions: _lppAssumptions(
          requiresFundAuthorizationBefore63: true,
          assumesPostReferenceGainfulActivity: true,
        ),
      ),
    ]) {
      expect(malformed.hasValidDependencyEnvelope, isFalse);
    }

    final material = valid.copyWith(
      projectionAssumptions: _lppAssumptions(
        requiresFundAuthorizationBefore63: true,
      ),
    );
    final restored = FinancialPlan.fromJson(material.toJson());
    expect(restored.hasValidDependencyEnvelope, isTrue);
    expect(
      (
        restored.projectionAssumptions?.annualProjectionUsesWholeYears,
        restored.projectionAssumptions?.requiresFundAuthorizationBefore63,
        restored.projectionAssumptions?.assumesPostReferenceGainfulActivity,
      ),
      (true, true, false),
    );
  });
}
