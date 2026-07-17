import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';
import 'package:mint_mobile/services/financial_plan_ledger_inputs.dart';
import 'package:mint_mobile/services/regulatory_sync_service.dart';

const _owner = '11111111-1111-4111-8111-111111111111';

CoachProfile _generalProfile({
  String firstName = 'Avant',
  String canton = 'VD',
  double pillar3a = 10000,
}) {
  return CoachProfile(
    firstName: firstName,
    birthYear: 1986,
    canton: canton,
    salaireBrutMensuel: 8000,
    prevoyance: PrevoyanceProfile(totalEpargne3a: pillar3a),
    goalA: GoalA(
      type: GoalAType.custom,
      label: 'Objectif synthétique',
      targetDate: DateTime(2030, 6, 30),
    ),
    inferDataSources: false,
  );
}

({CoachProfile profile, LppEvidenceSnapshot snapshot}) _lppFixture({
  DateTime? now,
  DateTime? salaryUpdatedAt,
  DateTime? capitalUpdatedAt,
  DateTime? mandatoryUpdatedAt,
  DateTime? extraUpdatedAt,
  DateTime? dateOfBirth,
  DateTime? sourceDate,
  bool useExactDate = true,
  bool? affiliation = true,
  ProfileDataSource affiliationSource = ProfileDataSource.userInput,
  ProfileDataSource salarySource = ProfileDataSource.userInput,
  ProfileDataSource dateOfBirthSource = ProfileDataSource.userInput,
  String? gender = 'M',
  ProfileDataSource genderSource = ProfileDataSource.userInput,
  ProfileDataSource mandatorySource = ProfileDataSource.certificate,
  ProfileDataSource extraSource = ProfileDataSource.certificate,
  double? total = 150000,
  double mandatory = 100000,
  double extra = 50000,
  double insuredSalary = 80000,
  double bonification = 0.18,
  double historicalReturn = 0.02,
  String canton = 'VD',
  double pillar3a = 10000,
}) {
  final capturedAt = now ?? DateTime.utc(2026, 7, 1, 8);
  final salaryStamp = salaryUpdatedAt ?? capturedAt;
  final capitalStamp = capitalUpdatedAt ?? capturedAt;
  final mandatoryStamp = mandatoryUpdatedAt ?? capitalStamp;
  final extraStamp = extraUpdatedAt ?? capitalStamp;
  final evidenceDate = sourceDate ?? DateTime.utc(2026, 6, 30);
  const affiliationPath = 'prevoyance.hasPensionFund';
  const salaryPath = 'salaireBrutMensuel';
  const dateOfBirthPath = 'dateOfBirth';
  const genderPath = 'gender';
  const totalPath = 'prevoyance.avoirLppTotal';
  const mandatoryPath = 'prevoyance.avoirLppObligatoire';
  const extraPath = 'prevoyance.avoirLppSurobligatoire';
  final profile = CoachProfile(
    birthYear: 1986,
    dateOfBirth:
        useExactDate ? (dateOfBirth ?? DateTime.utc(1986, 8, 1)) : null,
    gender: gender,
    canton: canton,
    salaireBrutMensuel: 8000,
    prevoyance: PrevoyanceProfile(
      hasPensionFund: affiliation,
      avoirLppTotal: total,
      avoirLppObligatoire: mandatory,
      avoirLppSurobligatoire: extra,
      salaireAssure: insuredSalary,
      bonificationRate: bonification,
      rendementCaisse: historicalReturn,
      rendementCaisseConnu: true,
      totalEpargne3a: pillar3a,
    ),
    goalA: GoalA(
      type: GoalAType.retraite,
      label: 'Retraite synthétique',
      targetDate: DateTime.utc(2051, 8, 1),
    ),
    inferDataSources: false,
    dataSources: <String, ProfileDataSource>{
      affiliationPath: affiliationSource,
      salaryPath: salarySource,
      if (useExactDate) dateOfBirthPath: dateOfBirthSource,
      if (gender != null) genderPath: genderSource,
      if (total != null) totalPath: ProfileDataSource.certificate,
      mandatoryPath: mandatorySource,
      extraPath: extraSource,
    },
    dataTimestamps: <String, DateTime>{
      affiliationPath: capturedAt,
      salaryPath: salaryStamp,
      if (useExactDate) dateOfBirthPath: capturedAt,
      if (gender != null) genderPath: capturedAt,
      if (total != null) totalPath: capitalStamp,
      mandatoryPath: mandatoryStamp,
      extraPath: extraStamp,
    },
    dataSourceDates: <String, DateTime?>{
      affiliationPath: null,
      salaryPath: null,
      if (useExactDate) dateOfBirthPath: null,
      if (gender != null) genderPath: null,
      if (total != null) totalPath: evidenceDate,
      mandatoryPath: evidenceDate,
      extraPath: evidenceDate,
    },
  );
  LppEvidenceFact fact(
    double value, {
    required ProfileDataSource source,
    required DateTime updatedAt,
  }) =>
      LppEvidenceFact(
        value: value,
        unit: LppEvidenceUnit.chf,
        profileOwnerId: _owner,
        actorProfileOwnerId: _owner,
        source: source.name,
        sourceDate: evidenceDate,
        updatedAt: updatedAt,
      );
  return (
    profile: profile,
    snapshot: LppEvidenceSnapshot(
      snapshotId: '22222222-2222-4222-8222-222222222222',
      facts: <LppEvidenceFactKey, LppEvidenceFact>{
        if (total != null)
          LppEvidenceFactKey.vestedBenefitsCapitalChf: fact(
            total,
            source: ProfileDataSource.certificate,
            updatedAt: capitalStamp,
          ),
        LppEvidenceFactKey.mandatoryVestedBenefitsCapitalChf: fact(
          mandatory,
          source: mandatorySource,
          updatedAt: mandatoryStamp,
        ),
        LppEvidenceFactKey.extraMandatoryVestedBenefitsCapitalChf: fact(
          extra,
          source: extraSource,
          updatedAt: extraStamp,
        ),
      },
    ),
  );
}

FinancialPlanDependencySnapshot _retirementSnapshot(
  ({CoachProfile profile, LppEvidenceSnapshot snapshot}) fixture, {
  DateTime? now,
  DateTime? targetDate,
}) {
  return FinancialPlanDependencySnapshot.fromProfile(
    fixture.profile,
    profileOwnerId: _owner,
    goalCategory: 'goal_retirement_plan',
    goalAmount: 3000000,
    targetDate: targetDate ?? DateTime.utc(2051, 8, 1),
    prospectiveLppReturn: 0.02,
    selfLppSnapshot: fixture.snapshot,
    now: now ?? DateTime.utc(2026, 7, 16, 12),
  );
}

void main() {
  test('v3 general dependency hashes owner and scenario only', () {
    final first = FinancialPlanDependencySnapshot.fromProfile(
      _generalProfile(),
      profileOwnerId: _owner,
      goalCategory: 'goal_general',
      goalAmount: 120000,
      targetDate: DateTime.utc(2030, 6, 30),
      prospectiveLppReturn: null,
      selfLppSnapshot: null,
      now: DateTime.utc(2026, 7, 16, 12),
    );
    final irrelevantMutation = FinancialPlanDependencySnapshot.fromProfile(
      _generalProfile(
        firstName: 'Après',
        canton: 'GE',
        pillar3a: 99000,
      ),
      profileOwnerId: _owner,
      goalCategory: 'goal_general',
      goalAmount: 120000,
      targetDate: DateTime.utc(2030, 6, 30),
      prospectiveLppReturn: null,
      selfLppSnapshot: null,
      now: DateTime.utc(2026, 12, 1, 8),
    );

    expect(first.schemaVersion, 3);
    expect(first.branch, FinancialPlanDependencyBranch.general);
    expect(first.basis, FinancialPlanDependencyBasis.none);
    expect(
      first.fingerprint,
      matches(RegExp(r'^mint-plan-dependency:v3:sha256:[0-9a-f]{64}$')),
    );
    expect(irrelevantMutation.fingerprint, first.fingerprint);
    expect(first.validUntil, DateTime.utc(2030, 6, 29, 22));
  });

  test('general branch rejects an unconsumed prospective LPP return', () {
    expect(
      () => FinancialPlanDependencySnapshot.fromProfile(
        _generalProfile(),
        profileOwnerId: _owner,
        goalCategory: 'goal_general',
        goalAmount: 120000,
        targetDate: DateTime.utc(2030, 6, 30),
        prospectiveLppReturn: 0.02,
        selfLppSnapshot: null,
        now: DateTime.utc(2026, 7, 16, 12),
      ),
      throwsArgumentError,
    );
  });

  test('retirement no-LPP rejects an unconsumed prospective LPP return', () {
    final fixture = _lppFixture(affiliation: false);

    expect(
      () => FinancialPlanDependencySnapshot.fromProfile(
        fixture.profile,
        profileOwnerId: _owner,
        goalCategory: 'goal_retirement_plan',
        goalAmount: 3000000,
        targetDate: DateTime.utc(2051, 8, 1),
        prospectiveLppReturn: 0.02,
        selfLppSnapshot: null,
        now: DateTime.utc(2026, 7, 16, 12),
      ),
      throwsArgumentError,
    );
  });

  test('total basis wins and ignores splits and caisse-only assumptions', () {
    final first = _retirementSnapshot(_lppFixture());
    final changed = _retirementSnapshot(_lppFixture(
      mandatory: 90000,
      extra: 60000,
      mandatorySource: ProfileDataSource.userInput,
      extraSource: ProfileDataSource.crossValidated,
      mandatoryUpdatedAt: DateTime.utc(2025, 1, 1),
      extraUpdatedAt: DateTime.utc(2026, 7, 10),
      insuredSalary: 91000,
      bonification: 0.25,
      historicalReturn: 0.06,
      canton: 'GE',
      pillar3a: 99000,
    ));

    expect(first.basis, FinancialPlanDependencyBasis.totalLegalSchedule);
    expect(
      first.calculatorContractVersion,
      'financial-plan-calculator:legal-lpp-2026:v2',
    );
    expect(changed.fingerprint, first.fingerprint);
    expect(changed.confidenceLevel, first.confidenceLevel);
    expect(changed.validUntil, first.validUntil);
  });

  test('selected LPP splits require one coherent review envelope', () {
    final incoherent = _lppFixture(
      total: null,
      mandatorySource: ProfileDataSource.certificate,
      extraSource: ProfileDataSource.userInput,
      mandatoryUpdatedAt: DateTime.utc(2026, 7, 1, 8),
      extraUpdatedAt: DateTime.utc(2026, 7, 1, 9),
    );

    expect(() => _retirementSnapshot(incoherent), throwsStateError);
  });

  test('unknown affiliation and missing exact LPP birth date fail closed', () {
    final unknown = _lppFixture(affiliation: null);
    final missingDob = _lppFixture(useExactDate: false);

    expect(() => _retirementSnapshot(unknown), throwsStateError);
    expect(
      () => _retirementSnapshot((
        profile: missingDob.profile,
        snapshot: missingDob.snapshot,
      )),
      throwsStateError,
    );
  });

  test('no-LPP retirement rejects a raw birth year without exact owned DOB',
      () {
    final fixture = _lppFixture(
      affiliation: false,
      useExactDate: false,
      total: null,
    );

    expect(
      () => FinancialPlanDependencySnapshot.fromProfile(
        fixture.profile,
        profileOwnerId: _owner,
        goalCategory: 'goal_retirement_plan',
        goalAmount: 3000000,
        targetDate: DateTime.utc(2051, 8, 1),
        prospectiveLppReturn: null,
        selfLppSnapshot: null,
        now: DateTime.utc(2026, 7, 16, 12),
      ),
      throwsA(
        isA<FinancialPlanDependencyBlocked>()
            .having(
              (error) => error.blocker,
              'blocker',
              FinancialPlanDependencyBlocker.dateOfBirth,
            )
            .having(
              (error) => error.collectorRoute,
              'collectorRoute',
              '/data-block/revenu?inputKey=q_date_of_birth',
            ),
      ),
    );
  });

  test('profile facts enforce their DATA_LEDGER provenance allowlist by path',
      () {
    final disallowedByPath = <({
      String path,
      Iterable<ProfileDataSource> sources,
      FinancialPlanDependencyBlocker blocker,
    })>[
      (
        path: 'prevoyance.hasPensionFund',
        sources: ProfileDataSource.values.where(
          (source) => source != ProfileDataSource.userInput,
        ),
        blocker: FinancialPlanDependencyBlocker.affiliation,
      ),
      (
        path: 'dateOfBirth',
        sources: ProfileDataSource.values.where(
          (source) =>
              source != ProfileDataSource.userInput &&
              source != ProfileDataSource.certificate,
        ),
        blocker: FinancialPlanDependencyBlocker.dateOfBirth,
      ),
      (
        path: 'gender',
        sources: ProfileDataSource.values.where(
          (source) =>
              source != ProfileDataSource.userInput &&
              source != ProfileDataSource.certificate,
        ),
        blocker: FinancialPlanDependencyBlocker.gender,
      ),
      (
        path: 'salaireBrutMensuel',
        sources: ProfileDataSource.values.where(
          (source) =>
              source != ProfileDataSource.userInput &&
              source != ProfileDataSource.certificate,
        ),
        blocker: FinancialPlanDependencyBlocker.salary,
      ),
    ];

    for (final pathCase in disallowedByPath) {
      for (final source in pathCase.sources) {
        final fixture = _lppFixture(
          affiliationSource: pathCase.path == 'prevoyance.hasPensionFund'
              ? source
              : ProfileDataSource.userInput,
          dateOfBirthSource: pathCase.path == 'dateOfBirth'
              ? source
              : ProfileDataSource.userInput,
          genderSource:
              pathCase.path == 'gender' ? source : ProfileDataSource.userInput,
          salarySource: pathCase.path == 'salaireBrutMensuel'
              ? source
              : ProfileDataSource.userInput,
        );

        expect(
          () => _retirementSnapshot(fixture),
          throwsA(
            isA<FinancialPlanDependencyBlocked>().having(
              (error) => error.blocker,
              'blocker for ${pathCase.path}/$source',
              pathCase.blocker,
            ),
          ),
        );
      }
    }
  });

  test('gross LPP salary accepts only declared or certified authority', () {
    for (final source in const <ProfileDataSource>[
      ProfileDataSource.userInput,
      ProfileDataSource.certificate,
    ]) {
      expect(
        () => _retirementSnapshot(_lppFixture(salarySource: source)),
        returnsNormally,
      );
    }
    expect(
      () => _retirementSnapshot(
        _lppFixture(salarySource: ProfileDataSource.openBanking),
      ),
      throwsA(
        isA<FinancialPlanDependencyBlocked>().having(
          (error) => error.blocker,
          'blocker',
          FinancialPlanDependencyBlocker.salary,
        ),
      ),
    );
  });

  test('LPP exact birth date is owned and every date mutation is hashed', () {
    expect(
      () => _retirementSnapshot(_lppFixture(
        dateOfBirthSource: ProfileDataSource.estimated,
      )),
      throwsStateError,
    );

    final first = _retirementSnapshot(
      _lppFixture(dateOfBirth: DateTime.utc(1986, 8, 1)),
    );
    final changed = _retirementSnapshot(
      _lppFixture(dateOfBirth: DateTime.utc(1986, 8, 2)),
    );
    expect(changed.fingerprint, isNot(first.fingerprint));
  });

  test('retirement consumer independently rejects implausible exact DOB facts',
      () {
    final now = DateTime.utc(2026, 7, 16, 12);
    for (final invalidBirthDate in <DateTime>[
      DateTime.utc(2026, 7, 17),
      DateTime.utc(2009, 7, 16),
      DateTime.utc(1899, 12, 31),
    ]) {
      expect(
        () => _retirementSnapshot(
          _lppFixture(dateOfBirth: invalidBirthDate),
          now: now,
        ),
        throwsA(
          isA<FinancialPlanDependencyBlocked>()
              .having(
                (error) => error.blocker,
                'blocker',
                FinancialPlanDependencyBlocker.dateOfBirth,
              )
              .having(
                (error) => error.collectorRoute,
                'collectorRoute',
                '/data-block/revenu?inputKey=q_date_of_birth',
              ),
        ),
        reason: '$invalidBirthDate must not reach age, AVS or fingerprint math',
      );
    }
  });

  test('impossible persisted ISO DOB is not normalized into a usable fact', () {
    final restored = CoachProfile.fromWizardAnswers({
      'q_date_of_birth': '1986-02-30',
      'q_birth_year': 1986,
    });

    expect(restored.dateOfBirth, isNull);
  });

  test('LPP exact birth source changes confidence without changing hard gates',
      () {
    final userOwned = _retirementSnapshot(
      _lppFixture(dateOfBirthSource: ProfileDataSource.userInput),
    );
    final certificateOwned = _retirementSnapshot(
      _lppFixture(dateOfBirthSource: ProfileDataSource.certificate),
    );

    expect(
      (
        certificateOwned.branch,
        certificateOwned.basis,
        certificateOwned.validUntil,
        certificateOwned.currentLppCapital,
      ),
      equals((
        userOwned.branch,
        userOwned.basis,
        userOwned.validUntil,
        userOwned.currentLppCapital,
      )),
      reason: 'Both sources are owned and authorized exact DOB facts.',
    );
    expect(certificateOwned.fingerprint, isNot(userOwned.fingerprint));
    expect(certificateOwned.confidenceLevel,
        greaterThan(userOwned.confidenceLevel));
  });

  test('AVS21 female cohorts preserve each transitional reference boundary',
      () {
    for (final cohort in <({
      int year,
      DateTime referenceDate,
    })>[
      (year: 1961, referenceDate: DateTime.utc(2026, 3, 31)),
      (year: 1962, referenceDate: DateTime.utc(2027, 6, 30)),
      (year: 1963, referenceDate: DateTime.utc(2028, 9, 30)),
    ]) {
      final atBoundary = _retirementSnapshot(
        _lppFixture(
          now: DateTime.utc(2025, 12, 1),
          sourceDate: DateTime.utc(2025, 11, 30),
          dateOfBirth: DateTime.utc(cohort.year, 12, 31),
          gender: 'F',
        ),
        now: DateTime.utc(2025, 12, 1),
        targetDate: cohort.referenceDate,
      );
      final afterBoundary = _retirementSnapshot(
        _lppFixture(
          now: DateTime.utc(2025, 12, 1),
          sourceDate: DateTime.utc(2025, 11, 30),
          dateOfBirth: DateTime.utc(cohort.year, 12, 31),
          gender: 'F',
        ),
        now: DateTime.utc(2025, 12, 1),
        targetDate: cohort.referenceDate.add(const Duration(days: 1)),
      );

      expect(atBoundary.gender, 'F');
      expect(atBoundary.avsReferenceDate, cohort.referenceDate);
      expect(atBoundary.requiresPostReferenceActivity, isFalse);
      expect(afterBoundary.requiresPostReferenceActivity, isTrue);
    }
  });

  test('LPP gender is canonical owned authority with exact recovery metadata',
      () {
    for (final invalidGender in <String?>[null, '', 'f', 'female', 'X']) {
      expect(
        () => _retirementSnapshot(_lppFixture(gender: invalidGender)),
        throwsA(
          isA<FinancialPlanDependencyBlocked>()
              .having(
                (error) => error.blocker,
                'blocker',
                FinancialPlanDependencyBlocker.gender,
              )
              .having(
                (error) => error.code,
                'code',
                'financial_plan_dependency.gender',
              )
              .having((error) => error.ledgerPath, 'ledgerPath', 'gender')
              .having(
                (error) => error.collectorRoute,
                'collectorRoute',
                '/data-block/revenu?inputKey=q_gender',
              ),
        ),
      );
    }

    expect(
      () => _retirementSnapshot(_lppFixture(
        gender: 'F',
        genderSource: ProfileDataSource.estimated,
      )),
      throwsA(
        isA<FinancialPlanDependencyBlocked>().having(
          (error) => error.blocker,
          'blocker',
          FinancialPlanDependencyBlocker.gender,
        ),
      ),
    );
  });

  test('gender value and provenance participate in the LPP fingerprint', () {
    final male = _retirementSnapshot(_lppFixture(gender: 'M'));
    final female = _retirementSnapshot(_lppFixture(gender: 'F'));
    final certifiedFemale = _retirementSnapshot(_lppFixture(
      gender: 'F',
      genderSource: ProfileDataSource.certificate,
    ));

    expect(female.fingerprint, isNot(male.fingerprint));
    expect(certifiedFemale.fingerprint, isNot(female.fingerprint));
    expect(
        certifiedFemale.confidenceLevel, greaterThan(female.confidenceLevel));
  });

  test('salary and selected capital expire on updatedAt plus 24 months', () {
    final stamp = DateTime.utc(2024, 7, 16, 12);
    final fixture = _lppFixture(
      salaryUpdatedAt: stamp,
      capitalUpdatedAt: stamp,
    );

    expect(
      () => _retirementSnapshot(
        fixture,
        now: DateTime.utc(2026, 7, 16, 11, 59, 59, 999, 999),
      ),
      returnsNormally,
    );
    expect(
      () => _retirementSnapshot(
        fixture,
        now: DateTime.utc(2026, 7, 16, 12),
      ),
      throwsStateError,
    );
  });

  test('sourceDate freshness follows Zurich civil midnight in CEST and CET',
      () {
    for (final boundary in <({
      String season,
      DateTime sourceDate,
      DateTime beforeLocalMidnight,
      DateTime atLocalMidnight,
    })>[
      (
        season: 'CEST',
        sourceDate: DateTime.utc(2026, 7, 17),
        beforeLocalMidnight: DateTime.utc(2026, 7, 16, 21, 59, 59),
        atLocalMidnight: DateTime.utc(2026, 7, 16, 22),
      ),
      (
        season: 'CET',
        sourceDate: DateTime.utc(2026, 1, 17),
        beforeLocalMidnight: DateTime.utc(2026, 1, 16, 22, 59, 59),
        atLocalMidnight: DateTime.utc(2026, 1, 16, 23),
      ),
    ]) {
      expect(
        () => _retirementSnapshot(
          _lppFixture(
            now: boundary.beforeLocalMidnight,
            sourceDate: boundary.sourceDate,
          ),
          now: boundary.beforeLocalMidnight,
        ),
        throwsA(
          isA<FinancialPlanDependencyBlocked>().having(
            (error) => error.blocker,
            'blocker',
            FinancialPlanDependencyBlocker.lpp,
          ),
        ),
        reason: '${boundary.season}: tomorrow is still future before midnight',
      );
      expect(
        () => _retirementSnapshot(
          _lppFixture(
            now: boundary.atLocalMidnight,
            sourceDate: boundary.sourceDate,
          ),
          now: boundary.atLocalMidnight,
        ),
        returnsNormally,
        reason: '${boundary.season}: today is admissible from local midnight',
      );
    }
  });

  test('LPP validUntil is exclusive minimum of birthday legal target freshness',
      () {
    final birthdayFirst = _retirementSnapshot(_lppFixture());
    expect(birthdayFirst.validUntil, DateTime.utc(2026, 7, 31, 22));

    final targetFirst = _retirementSnapshot(
      _lppFixture(dateOfBirth: DateTime.utc(1986, 12, 1)),
      targetDate: DateTime.utc(2026, 10, 1),
    );
    expect(targetFirst.validUntil, DateTime.utc(2026, 9, 30, 22));
  });

  test('Zurich civil today changes at CET and CEST midnight, not UTC midnight',
      () {
    FinancialPlanDependencySnapshot general(DateTime now) =>
        FinancialPlanDependencySnapshot.fromProfile(
          _generalProfile(),
          profileOwnerId: _owner,
          goalCategory: 'goal_general',
          goalAmount: 120000,
          targetDate: DateTime.utc(2026, 7, 1),
          prospectiveLppReturn: null,
          selfLppSnapshot: null,
          now: now,
        );

    expect(
      () => general(DateTime.utc(2026, 6, 30, 21, 59, 59, 999, 999)),
      returnsNormally,
      reason: '21:59 UTC is still 30 June in Zurich during CEST.',
    );
    expect(
      () => general(DateTime.utc(2026, 6, 30, 22)),
      throwsArgumentError,
      reason: '22:00 UTC is 1 July 00:00 in Zurich during CEST.',
    );
    expect(
      () => FinancialPlanDependencySnapshot.fromProfile(
        _generalProfile(),
        profileOwnerId: _owner,
        goalCategory: 'goal_general',
        goalAmount: 120000,
        targetDate: DateTime.utc(2026, 1, 1),
        prospectiveLppReturn: null,
        selfLppSnapshot: null,
        now: DateTime.utc(2025, 12, 31, 23),
      ),
      throwsArgumentError,
      reason: '23:00 UTC is 1 January 00:00 in Zurich during CET.',
    );
  });

  test('every consumed regulatory value changes the LPP fingerprint', () {
    addTearDown(RegulatorySyncService.clearCache);
    final fixture = _lppFixture();
    RegulatorySyncService.clearCache();
    final baseline = _retirementSnapshot(fixture).fingerprint;

    for (final entry in <String, double>{
      'lpp.entry_threshold': 23000,
      'lpp.coordination_deduction': 27000,
      'lpp.min_coordinated_salary': 4000,
      'lpp.max_coordinated_salary': 65000,
    }.entries) {
      RegulatorySyncService.setMockCache(<String, double>{
        entry.key: entry.value,
      });
      expect(_retirementSnapshot(fixture).fingerprint, isNot(baseline));
    }
  });
}
