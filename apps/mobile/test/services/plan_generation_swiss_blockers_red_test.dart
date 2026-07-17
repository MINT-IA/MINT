import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/financial_plan.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';
import 'package:mint_mobile/services/financial_plan_ledger_inputs.dart';
import 'package:mint_mobile/services/plan_generation_service.dart';

const _profileOwnerId = '11111111-1111-4111-8111-111111111111';
final _now = DateTime.utc(2026, 7, 16, 12);
final _target = DateTime.utc(2051, 2, 14);

({CoachProfile profile, LppEvidenceSnapshot? snapshot}) _fixture({
  bool? hasPensionFund = true,
  bool hasExactDateOfBirth = true,
  double grossMonthlySalary = 8000,
  double? total = 150000,
  double? mandatory = 100000,
  double? extra = 50000,
  DateTime? capitalUpdatedAt,
  String? gender = 'M',
}) {
  final updatedAt = capitalUpdatedAt ?? DateTime.utc(2026, 7, 1, 8);
  final sourceDate = DateTime.utc(2026, 6, 30);
  const affiliationPath = 'prevoyance.hasPensionFund';
  const salaryPath = 'salaireBrutMensuel';
  const dateOfBirthPath = 'dateOfBirth';
  const genderPath = 'gender';
  const totalPath = 'prevoyance.avoirLppTotal';
  const mandatoryPath = 'prevoyance.avoirLppObligatoire';
  const extraPath = 'prevoyance.avoirLppSurobligatoire';
  final profile = CoachProfile(
    birthYear: 1986,
    dateOfBirth: hasExactDateOfBirth ? DateTime.utc(1986, 2, 14) : null,
    gender: gender,
    canton: 'VD',
    salaireBrutMensuel: grossMonthlySalary,
    prevoyance: PrevoyanceProfile(
      hasPensionFund: hasPensionFund,
      avoirLppTotal: total,
      avoirLppObligatoire: mandatory,
      avoirLppSurobligatoire: extra,
      totalEpargne3a: 30000,
    ),
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: _target,
      label: 'Retraite synthétique',
    ),
    inferDataSources: false,
    dataSources: {
      affiliationPath: ProfileDataSource.userInput,
      if (grossMonthlySalary > 0) salaryPath: ProfileDataSource.userInput,
      if (hasExactDateOfBirth) dateOfBirthPath: ProfileDataSource.userInput,
      if (gender != null) genderPath: ProfileDataSource.userInput,
      if (total != null) totalPath: ProfileDataSource.certificate,
      if (mandatory != null) mandatoryPath: ProfileDataSource.certificate,
      if (extra != null) extraPath: ProfileDataSource.certificate,
    },
    dataTimestamps: {
      affiliationPath: _now,
      if (grossMonthlySalary > 0) salaryPath: _now,
      if (hasExactDateOfBirth) dateOfBirthPath: _now,
      if (gender != null) genderPath: _now,
      if (total != null) totalPath: updatedAt,
      if (mandatory != null) mandatoryPath: updatedAt,
      if (extra != null) extraPath: updatedAt,
    },
    dataSourceDates: {
      affiliationPath: null,
      if (grossMonthlySalary > 0) salaryPath: null,
      if (hasExactDateOfBirth) dateOfBirthPath: null,
      if (gender != null) genderPath: null,
      if (total != null) totalPath: sourceDate,
      if (mandatory != null) mandatoryPath: sourceDate,
      if (extra != null) extraPath: sourceDate,
    },
  );

  LppEvidenceFact fact(double value) => LppEvidenceFact(
        value: value,
        unit: LppEvidenceUnit.chf,
        profileOwnerId: _profileOwnerId,
        actorProfileOwnerId: _profileOwnerId,
        source: ProfileDataSource.certificate.name,
        sourceDate: sourceDate,
        updatedAt: updatedAt,
      );
  final facts = <LppEvidenceFactKey, LppEvidenceFact>{
    if (total != null) LppEvidenceFactKey.vestedBenefitsCapitalChf: fact(total),
    if (mandatory != null)
      LppEvidenceFactKey.mandatoryVestedBenefitsCapitalChf: fact(mandatory),
    if (extra != null)
      LppEvidenceFactKey.extraMandatoryVestedBenefitsCapitalChf: fact(extra),
  };
  return (
    profile: profile,
    snapshot: hasPensionFund == true && facts.isNotEmpty
        ? LppEvidenceSnapshot(
            snapshotId: '22222222-2222-4222-8222-222222222222',
            facts: facts,
          )
        : null,
  );
}

Future<FinancialPlan> _generate(
  ({CoachProfile profile, LppEvidenceSnapshot? snapshot}) fixture, {
  double? prospectiveLppReturn = 0.02,
  String goalCategory = 'goal_retirement_plan',
  DateTime? targetDate,
  DateTime? now,
}) {
  return PlanGenerationService.generate(
    goalDescription: 'Retraite synthétique',
    goalCategory: goalCategory,
    targetDate: targetDate ?? _target,
    profile: fixture.profile,
    profileOwnerId: _profileOwnerId,
    selfLppSnapshot: fixture.snapshot,
    goalAmount: 3000000,
    prospectiveLppReturn: prospectiveLppReturn,
    now: now ?? _now,
  );
}

Matcher _blockedBy(String blocker) => throwsA(
      isA<FinancialPlanDependencyBlocked>().having(
        (error) => error.blocker.name,
        'blocker',
        blocker,
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('G1-BND-06 Swiss v3 blockers', () {
    test('strict total basis produces a replayable legal-schedule draft',
        () async {
      final plan = await _generate(_fixture(
        mandatory: null,
        extra: null,
      ));

      expect(plan.hasValidDependencyEnvelope, isTrue);
      expect(plan.dependencyBranch, 'retirementLpp');
      expect(plan.dependencyBasis, 'total/legalSchedule');
      expect(plan.confirmedAt, isNull);
      expect(
        plan.sources,
        equals(<String>[
          'LPP art. 7',
          'LPP art. 8',
          'LPP art. 13 et 13b',
          'LPP art. 15–16',
          'OFAS — AVS 21 (âge de référence transitoire)',
        ]),
      );
      expect(
        plan.sources.where((source) => source.startsWith('LAVS')),
        isEmpty,
      );
      expect(plan.monthlyTarget, greaterThanOrEqualTo(0));
      expect(
        plan.projectionAssumptions?.bonificationBasis.kind,
        'legalAgeSchedule',
      );
      expect(
        plan.projectionAssumptions?.annualProjectionUsesWholeYears,
        isTrue,
      );
      expect(
        plan.projectionAssumptions?.requiresFundAuthorizationBefore63,
        isFalse,
      );
      expect(
        plan.projectionAssumptions?.assumesPostReferenceGainfulActivity,
        isFalse,
      );
    });

    test('material LPP conditions are structured, persisted and replayable',
        () async {
      final early = await _generate(
        _fixture(mandatory: null, extra: null),
        targetDate: DateTime.utc(2048, 2, 13),
      );
      final postReference = await _generate(
        _fixture(mandatory: null, extra: null),
        targetDate: DateTime.utc(2051, 2, 15),
      );

      expect(
        (
          early.projectionAssumptions?.annualProjectionUsesWholeYears,
          early.projectionAssumptions?.requiresFundAuthorizationBefore63,
          early.projectionAssumptions?.assumesPostReferenceGainfulActivity,
        ),
        (true, true, false),
      );
      expect(
        (
          postReference.projectionAssumptions?.annualProjectionUsesWholeYears,
          postReference
              .projectionAssumptions?.requiresFundAuthorizationBefore63,
          postReference
              .projectionAssumptions?.assumesPostReferenceGainfulActivity,
        ),
        (true, false, true),
      );
      expect(early.sources, postReference.sources);
      expect(postReference.sources, isNot(contains('LAVS art. 39')));

      final restored = FinancialPlan.fromJson(postReference.toJson());
      expect(restored.hasValidDependencyEnvelope, isTrue);
      expect(
        restored.projectionAssumptions?.assumesPostReferenceGainfulActivity,
        isTrue,
      );
      expect(restored.sources, postReference.sources);
    });

    test('complete coherent splits are selected when total is absent',
        () async {
      final plan = await _generate(_fixture(total: null));

      expect(plan.dependencyBasis, 'splits/legalSchedule');
      expect(plan.monthlyTarget, greaterThanOrEqualTo(0));
    });

    test('unknown affiliation emits the exact typed blocker', () {
      expectLater(
        _generate(_fixture(hasPensionFund: null)),
        _blockedBy('affiliation'),
      );
    });

    test('missing exact date of birth emits the exact typed blocker', () {
      expectLater(
        _generate(_fixture(hasExactDateOfBirth: false)),
        _blockedBy('dateOfBirth'),
      );
    });

    test('missing canonical AVS gender emits the exact typed blocker', () {
      expectLater(
        _generate(_fixture(gender: null)),
        _blockedBy('gender'),
      );
    });

    test('missing gross salary emits the exact typed blocker', () {
      expectLater(
        _generate(_fixture(grossMonthlySalary: 0)),
        _blockedBy('salary'),
      );
    });

    test('missing owned capital evidence fails closed', () {
      expectLater(
        _generate(_fixture(total: null, mandatory: null, extra: null)),
        throwsStateError,
      );
    });

    test('incoherent total and splits fail closed', () {
      expectLater(_generate(_fixture(total: 150002)), throwsStateError);
    });

    test('selected capital at the exact 24-month boundary is expired', () {
      expectLater(
        _generate(_fixture(
          mandatory: null,
          extra: null,
          capitalUpdatedAt: DateTime.utc(2024, 7, 16, 12),
        )),
        throwsStateError,
      );
    });

    test('explicit no-LPP branch uses no capital or return assumption',
        () async {
      final plan = await _generate(
        _fixture(
          hasPensionFund: false,
          total: null,
          mandatory: null,
          extra: null,
        ),
        prospectiveLppReturn: null,
      );

      expect(plan.dependencyBranch, 'retirementNoLpp');
      expect(plan.dependencyBasis, 'none');
      expect(plan.projectedLow, isNull);
      expect(plan.projectedHigh, isNull);
      expect(plan.sources, isEmpty);
      expect(
        (
          plan.projectionAssumptions?.annualProjectionUsesWholeYears,
          plan.projectionAssumptions?.requiresFundAuthorizationBefore63,
          plan.projectionAssumptions?.assumesPostReferenceGainfulActivity,
        ),
        (false, false, false),
      );
    });

    test('retirement LPP legal contract blocks at Zurich 2027 civil midnight',
        () {
      expectLater(
        _generate(
          _fixture(mandatory: null, extra: null),
          now: DateTime.utc(2026, 12, 31, 23),
        ),
        _blockedBy('legalContract'),
      );
    });

    test('retirement LPP remains valid immediately before Zurich legal expiry',
        () async {
      final plan = await _generate(
        _fixture(mandatory: null, extra: null),
        now: DateTime.utc(2026, 12, 31, 22, 59, 59, 999, 999),
      );

      expect(plan.hasValidDependencyEnvelope, isTrue);
      expect(plan.validUntil,
          FinancialPlanDependencySnapshot.legalContractValidUntil);
    });

    test('general and no-LPP remain available at LPP legal expiry', () async {
      final exactExpiry = DateTime.utc(2026, 12, 31, 23);
      final general = await _generate(
        _fixture(),
        goalCategory: 'goal_general',
        prospectiveLppReturn: null,
        now: exactExpiry,
      );
      final noLpp = await _generate(
        _fixture(
          hasPensionFund: false,
          total: null,
          mandatory: null,
          extra: null,
        ),
        prospectiveLppReturn: null,
        now: exactExpiry,
      );

      expect(general.dependencyBranch, 'general');
      expect(noLpp.dependencyBranch, 'retirementNoLpp');
    });

    for (final boundary in <({String name, DateTime target})>[
      (name: '58th birthday', target: DateTime.utc(2044, 2, 14)),
      (name: 'day after 58th birthday', target: DateTime.utc(2044, 2, 15)),
      (name: 'day before 70th birthday', target: DateTime.utc(2056, 2, 13)),
      (name: '70th birthday', target: DateTime.utc(2056, 2, 14)),
    ]) {
      test('v3 retirement fixture accepts ${boundary.name}', () async {
        final plan = await _generate(
          _fixture(mandatory: null, extra: null),
          targetDate: boundary.target,
        );

        expect(plan.hasValidDependencyEnvelope, isTrue);
      });
    }

    for (final boundary in <({String name, DateTime target})>[
      (name: 'day before 58th birthday', target: DateTime.utc(2044, 2, 13)),
      (name: 'day after 70th birthday', target: DateTime.utc(2056, 2, 15)),
    ]) {
      test('v3 retirement fixture rejects ${boundary.name}', () {
        expectLater(
          _generate(
            _fixture(mandatory: null, extra: null),
            targetDate: boundary.target,
          ),
          throwsArgumentError,
        );
      });
    }
  });
}
