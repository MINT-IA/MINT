import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/financial_plan.dart';
import 'package:mint_mobile/providers/financial_plan_provider.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';
import 'package:mint_mobile/services/financial_plan_ledger_inputs.dart';
import 'package:mint_mobile/services/plan_generation_service.dart';

const _retirementGoalAmount = 3000000.0;

CoachProfile _retirementProfile({
  double? total = 150000,
  double? mandatory = 100000,
  double? extraMandatory = 50000,
  double caisseReturn = 0.02,
  bool caisseReturnKnown = true,
  double? insuredSalary,
  double? bonificationRate,
  double monthlySalary = 8000,
  double salaryMonths = 12,
  Map<String, ProfileDataSource>? dataSources,
  Map<String, DateTime>? dataTimestamps,
  Map<String, DateTime?>? dataSourceDates,
}) {
  final ownedPaths = <String>[
    'salaireBrutMensuel',
    if (total != null) 'prevoyance.avoirLppTotal',
    if (mandatory != null) 'prevoyance.avoirLppObligatoire',
    if (extraMandatory != null) 'prevoyance.avoirLppSurobligatoire',
    'prevoyance.rendementCaisse',
    'prevoyance.rendementCaisseConnu',
    if (insuredSalary != null) 'prevoyance.salaireAssure',
    if (bonificationRate != null) 'prevoyance.bonificationRate',
  ];
  final resolvedSources = <String, ProfileDataSource>{
    for (final path in ownedPaths) path: ProfileDataSource.userInput,
    ...?dataSources,
  };
  final resolvedTimestamps = <String, DateTime>{
    for (final path in ownedPaths) path: DateTime.utc(2026, 7, 1, 8),
    ...?dataTimestamps,
  };
  final resolvedSourceDates = <String, DateTime?>{
    for (final path in ownedPaths) path: DateTime.utc(2026, 7, 1),
    ...?dataSourceDates,
  };
  return CoachProfile(
    birthYear: 1986,
    dateOfBirth: DateTime(1986, 2, 14),
    canton: 'VD',
    salaireBrutMensuel: monthlySalary,
    nombreDeMois: salaryMonths,
    prevoyance: PrevoyanceProfile(
      avoirLppTotal: total,
      avoirLppObligatoire: mandatory,
      avoirLppSurobligatoire: extraMandatory,
      rendementCaisse: caisseReturn,
      rendementCaisseConnu: caisseReturnKnown,
      salaireAssure: insuredSalary,
      bonificationRate: bonificationRate,
      totalEpargne3a: 30000,
    ),
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2051, 7, 16),
      label: 'Retraite synthétique',
    ),
    financialLiteracyLevel: FinancialLiteracyLevel.advanced,
    inferDataSources: false,
    dataSources: resolvedSources,
    dataTimestamps: resolvedTimestamps,
    dataSourceDates: resolvedSourceDates,
    createdAt: DateTime(2026, 7, 1),
    updatedAt: DateTime(2026, 7, 1),
  );
}

DateTime _targetInMonths(int months) {
  final now = DateTime.now();
  return DateTime(now.year, now.month + months, now.day);
}

Future<FinancialPlan> _generate(CoachProfile profile) {
  return PlanGenerationService.generate(
    goalDescription: 'Retraite synthétique',
    goalCategory: 'goal_retirement_plan',
    targetDate: _targetInMonths(300),
    profile: profile,
    goalAmount: _retirementGoalAmount,
    prospectiveLppReturn: 0.02,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('G1-BND-06 Swiss blockers RED — owned retirement inputs', () {
    test(
      'total-only retirement keeps both split facts unknown and remains computable',
      () async {
        final profile = _retirementProfile(
          mandatory: null,
          extraMandatory: null,
        );

        final plan = await _generate(profile);
        final inputs = FinancialPlanLedgerInputs.fromProfile(
          profile,
          now: DateTime.utc(2026, 7, 16, 12),
        );

        expect(plan.monthlyTarget, greaterThanOrEqualTo(0));
        expect(
          (inputs.lppMandatoryBalance, inputs.lppExtraMandatoryBalance),
          equals((null, null)),
          reason: 'A current combined capital is sufficient for the combined '
              'projection, but it does not own either component split.',
        );
      },
    );

    test('complete split balances without a total remain computable', () async {
      final plan = await _generate(_retirementProfile(total: null));

      expect(plan.monthlyTarget, greaterThanOrEqualTo(0));
    });

    test('retirement with no owned capital fact fails closed', () async {
      expect(
        () => _generate(_retirementProfile(
          total: null,
          mandatory: null,
          extraMandatory: null,
        )),
        throwsA(isA<ArgumentError>()),
      );
    });

    test(
      'total plus exactly one split preserves the missing counterpart as unknown',
      () async {
        final mandatoryOnly = _retirementProfile(extraMandatory: null);
        final extraOnly = _retirementProfile(mandatory: null);

        await _generate(mandatoryOnly);
        await _generate(extraOnly);
        final mandatoryInputs = FinancialPlanLedgerInputs.fromProfile(
          mandatoryOnly,
          now: DateTime.utc(2026, 7, 16, 12),
        );
        final extraInputs = FinancialPlanLedgerInputs.fromProfile(
          extraOnly,
          now: DateTime.utc(2026, 7, 16, 12),
        );

        expect(
          (
            (
              mandatoryInputs.lppMandatoryBalance,
              mandatoryInputs.lppExtraMandatoryBalance,
            ),
            (
              extraInputs.lppMandatoryBalance,
              extraInputs.lppExtraMandatoryBalance,
            ),
          ),
          equals(((100000.0, null), (null, 50000.0))),
          reason: 'A combined total permits calculation, but never grants '
              'ownership of an absent mandatory or supra-mandatory split.',
        );
      },
    );

    test('one split balance without a total fails closed', () async {
      expect(
        () => _generate(
          _retirementProfile(total: null, extraMandatory: null),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('total and complete splits differing by more than CHF 1 fail closed',
        () async {
      expect(
        () => _generate(_retirementProfile(total: 150001.01)),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('total and complete splits may differ by exactly CHF 1', () async {
      final plan = await _generate(_retirementProfile(total: 150001));

      expect(plan.monthlyTarget, greaterThanOrEqualTo(0));
    });

    test('declared insured salary is ignored by the legal projection',
        () async {
      final lower = await _generate(_retirementProfile(
        insuredSalary: 80000,
        bonificationRate: 0.18,
      ));
      final higher = await _generate(_retirementProfile(
        insuredSalary: 90000,
        bonificationRate: 0.18,
      ));

      expect(
        (
          higher.monthlyTarget,
          lower.monthlyTarget,
          higher.projectionAssumptions?.salaryBasis.kind,
          higher.projectionAssumptions?.salaryBasis.annualChf,
        ),
        equals((
          lower.monthlyTarget,
          lower.monthlyTarget,
          'monthlySalaryTimesTwelve',
          96000.0
        )),
        reason: 'Without a typed caisse bonification schedule, MINT must not '
            'combine an insured caisse salary with the statutory age table.',
      );
    });

    test(
        'an insured caisse salary without its bonification schedule falls back to the complete legal basis',
        () async {
      final legal = await _generate(_retirementProfile());
      final incompleteCaisse = await _generate(
        _retirementProfile(insuredSalary: 200000),
      );

      expect(
        (
          incompleteCaisse.monthlyTarget,
          incompleteCaisse.projectionAssumptions?.salaryBasis.kind,
          incompleteCaisse.projectionAssumptions?.salaryBasis.annualChf,
          incompleteCaisse.projectionAssumptions?.bonificationBasis.kind,
        ),
        equals((
          legal.monthlyTarget,
          'monthlySalaryTimesTwelve',
          96000.0,
          'legalAgeSchedule',
        )),
        reason: 'A caisse salary and the legal age schedule are not a valid '
            'actuarial pair. An incomplete caisse pair must use gross monthly '
            'salary × 12 and the coordinated legal basis together.',
      );
    });

    test('declared caisse bonification is ignored by the legal projection',
        () async {
      final lower = await _generate(_retirementProfile(
        insuredSalary: 90000,
        bonificationRate: 0.10,
      ));
      final higher = await _generate(_retirementProfile(
        insuredSalary: 90000,
        bonificationRate: 0.20,
      ));

      expect(
        (
          higher.monthlyTarget,
          lower.monthlyTarget,
          higher.projectionAssumptions?.bonificationBasis.kind,
        ),
        equals((lower.monthlyTarget, lower.monthlyTarget, 'legalAgeSchedule')),
        reason: 'A single current caisse rate is not a future schedule and '
            'cannot replace the statutory legal age schedule.',
      );
    });

    for (final path in const [
      'prevoyance.salaireAssure',
      'prevoyance.bonificationRate',
    ]) {
      test('$path provenance and freshness belong to the v2 fingerprint', () {
        CoachProfile profile({
          ProfileDataSource source = ProfileDataSource.userInput,
          DateTime? updatedAt,
          DateTime? sourceDate,
        }) {
          return _retirementProfile(
            insuredSalary: 90000,
            bonificationRate: 0.18,
            dataSources: {path: source},
            dataTimestamps: {
              path: updatedAt ?? DateTime.utc(2026, 7, 1, 8),
            },
            dataSourceDates: {
              path: sourceDate ?? DateTime.utc(2026, 1, 1),
            },
          );
        }

        String fingerprint(CoachProfile value) =>
            FinancialPlanLedgerInputs.fromProfile(
              value,
              now: DateTime.utc(2026, 7, 16, 12),
            ).fingerprint;

        final fingerprints = <String>{
          fingerprint(profile()),
          fingerprint(profile(source: ProfileDataSource.certificate)),
          fingerprint(profile(updatedAt: DateTime.utc(2026, 7, 2, 8))),
          fingerprint(profile(sourceDate: DateTime.utc(2026, 1, 2))),
        };

        expect(
          fingerprints,
          hasLength(4),
          reason: 'The same owned value with different source, captured-at, '
              'or source-as-of metadata is a different ledger snapshot.',
        );
      });
    }

    test('owned LPP override freshness has an explicit 24-month boundary', () {
      final now = DateTime.utc(2026, 7, 16, 12);
      FinancialPlanLedgerInputs inputs(DateTime sourceAsOf) {
        return FinancialPlanLedgerInputs.fromProfile(
          _retirementProfile(
            insuredSalary: 90000,
            bonificationRate: 0.18,
            dataSourceDates: {
              'prevoyance.salaireAssure': sourceAsOf,
              'prevoyance.bonificationRate': sourceAsOf,
            },
          ),
          now: now,
        );
      }

      final atBoundary = inputs(DateTime.utc(2024, 7, 16));
      final beyondBoundary = inputs(DateTime.utc(2024, 7, 15));

      expect(
        (
          FinancialPlanLedgerInputs.currentOwnedFactMaxAgeMonths,
          atBoundary.insuredSalaryAnnual,
          atBoundary.bonificationRate,
          beyondBoundary.insuredSalaryAnnual,
          beyondBoundary.bonificationRate,
        ),
        equals((24, 90000.0, 0.18, null, null)),
      );
    });

    test('fallback insured salary is monthly base times 12, not salary months',
        () async {
      final twelveMonths = await _generate(_retirementProfile(
        monthlySalary: 5000,
        salaryMonths: 12,
      ));
      final thirteenMonths = await _generate(_retirementProfile(
        monthlySalary: 5000,
        salaryMonths: 13,
      ));

      expect(
        (
          (thirteenMonths.monthlyTarget - twelveMonths.monthlyTarget).abs() <
              0.000001,
          thirteenMonths.profileHashAtGeneration ==
              twelveMonths.profileHashAtGeneration,
        ),
        equals((true, true)),
        reason: 'A 13th salary month is neither silently part of the LPP '
            'insured-salary fallback nor a consumed retirement fingerprint '
            'fact; without a certificate the basis is monthly base × 12.',
      );
    });

    test(
      'historical caisse return never becomes a future scenario assumption implicitly',
      () async {
        final profile = _retirementProfile(caisseReturn: 0.02);

        expect(
          () => PlanGenerationService.generate(
            goalDescription: 'Retraite sans hypothèse prospective',
            goalCategory: 'goal_retirement_plan',
            targetDate: _targetInMonths(300),
            profile: profile,
            goalAmount: _retirementGoalAmount,
          ),
          throwsA(isA<ArgumentError>()),
          reason: 'A historical or currently credited caisse rate is a ledger '
              'fact, not user consent to project that rate every future year.',
        );
      },
    );

    test(
        'retirement plan serializes the legal basis despite declared caisse inputs',
        () async {
      final plan = await _generate(_retirementProfile(
        insuredSalary: 90000,
        bonificationRate: 0.18,
      ));

      expect(
        plan.toJson()['projectionAssumptions'],
        equals(<String, Object>{
          'caisseReturnBase': 0.02,
          'caisseReturnLow': 0.01,
          'caisseReturnHigh': 0.03,
          'supplementalMonthlySavingsReturn': 0.0,
          'salaryBasis': <String, Object>{
            'kind': 'monthlySalaryTimesTwelve',
            'annualChf': 96000.0,
          },
          'bonificationBasis': <String, Object>{
            'kind': 'legalAgeSchedule',
          },
          'projectionAsOf': plan.generatedAt.toUtc().toIso8601String(),
        }),
        reason:
            'The UI must expose that the calculator ignored caisse-specific '
            'inputs and used one internally coherent statutory basis.',
      );
    });

    test('retirement plan serializes visible legal fallback bases', () async {
      final plan = await _generate(_retirementProfile());

      expect(
        plan.toJson()['projectionAssumptions'],
        equals(<String, Object>{
          'caisseReturnBase': 0.02,
          'caisseReturnLow': 0.01,
          'caisseReturnHigh': 0.03,
          'supplementalMonthlySavingsReturn': 0.0,
          'salaryBasis': <String, Object>{
            'kind': 'monthlySalaryTimesTwelve',
            'annualChf': 96000.0,
          },
          'bonificationBasis': <String, Object>{
            'kind': 'legalAgeSchedule',
          },
          'projectionAsOf': plan.generatedAt.toUtc().toIso8601String(),
        }),
        reason: 'Fallback inputs are explicit assumptions, not silent facts '
            'owned by a pension-fund certificate.',
      );
    });

    group('retirement target age guard', () {
      late DateTime now;
      late CoachProfile profile;

      setUp(() {
        now = DateTime.now();
        profile = CoachProfile(
          birthYear: now.year - 40,
          dateOfBirth: DateTime(now.year - 40, now.month, 1),
          canton: 'VD',
          salaireBrutMensuel: 8000,
          prevoyance: const PrevoyanceProfile(
            avoirLppTotal: 150000,
            avoirLppObligatoire: 100000,
            avoirLppSurobligatoire: 50000,
            rendementCaisse: 0.02,
          ),
          goalA: GoalA(
            type: GoalAType.retraite,
            targetDate: DateTime(now.year + 18, now.month, now.day),
            label: 'Retraite synthétique',
          ),
          financialLiteracyLevel: FinancialLiteracyLevel.advanced,
          dataSources: const {
            'salaireBrutMensuel': ProfileDataSource.userInput,
            'dateOfBirth': ProfileDataSource.userInput,
            'prevoyance.avoirLppTotal': ProfileDataSource.userInput,
            'prevoyance.avoirLppObligatoire': ProfileDataSource.userInput,
            'prevoyance.avoirLppSurobligatoire': ProfileDataSource.userInput,
            'prevoyance.rendementCaisse': ProfileDataSource.userInput,
          },
          dataTimestamps: {
            for (final path in const [
              'salaireBrutMensuel',
              'dateOfBirth',
              'prevoyance.avoirLppTotal',
              'prevoyance.avoirLppObligatoire',
              'prevoyance.avoirLppSurobligatoire',
              'prevoyance.rendementCaisse',
            ])
              path: now,
          },
          inferDataSources: false,
        );
      });

      Future<FinancialPlan> atAge(int age) => PlanGenerationService.generate(
            goalDescription: 'Retraite à $age ans',
            goalCategory: 'goal_retirement_plan',
            targetDate: DateTime(
              now.year + (age - 40),
              now.month,
              now.day,
            ),
            profile: profile,
            goalAmount: _retirementGoalAmount,
            prospectiveLppReturn: 0.02,
          );

      test('ages 58 and 70 remain valid boundaries', () async {
        await expectLater(atAge(58), completes);
        await expectLater(atAge(70), completes);
      });

      test('age 57 fails closed', () async {
        await expectLater(atAge(57), throwsA(isA<ArgumentError>()));
      });

      test('age 71 fails closed', () async {
        await expectLater(atAge(71), throwsA(isA<ArgumentError>()));
      });
    });

    test('confidence below projection threshold blocks durable retirement',
        () async {
      final now = DateTime.now();
      final profile = CoachProfile(
        birthYear: now.year - 40,
        canton: 'VD',
        salaireBrutMensuel: 1000,
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 150000,
          rendementCaisse: 0.02,
        ),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(now.year + 20, now.month, now.day),
          label: 'Retraite peu documentée',
        ),
        dataSources: const {
          'prevoyance.avoirLppTotal': ProfileDataSource.estimated,
          'prevoyance.rendementCaisse': ProfileDataSource.estimated,
        },
        inferDataSources: false,
      );
      final confidence = ConfidenceScorer.scoreEnhanced(profile).combined;
      expect(
        confidence,
        lessThan(ConfidenceScorer.minConfidenceForProjection),
        reason: 'Fixture intentionally represents an explicit low-confidence '
            'fallback rather than a current certificate snapshot.',
      );

      expect(
        () => PlanGenerationService.generate(
          goalDescription: 'Retraite peu documentée',
          goalCategory: 'goal_retirement_plan',
          targetDate: DateTime(now.year + 20, now.month, now.day),
          profile: profile,
          goalAmount: _retirementGoalAmount,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test(
      'explicit no-pension-fund retirement is simple supplemental savings math',
      () async {
        final now = DateTime.now();
        final targetDate = DateTime(now.year + 20, now.month, now.day);
        final profile = CoachProfile(
          birthYear: now.year - 40,
          dateOfBirth: DateTime(now.year - 40, now.month, 1),
          canton: 'VD',
          salaireBrutMensuel: 8000,
          prevoyance: const PrevoyanceProfile(
            hasPensionFund: false,
            rendementCaisseConnu: false,
          ),
          goalA: GoalA(
            type: GoalAType.retraite,
            targetDate: targetDate,
            label: 'Épargne retraite sans caisse de pension',
          ),
          dataSources: const {
            'prevoyance.hasPensionFund': ProfileDataSource.userInput,
          },
          inferDataSources: false,
        );

        final plan = await PlanGenerationService.generate(
          goalDescription: 'Épargne retraite sans caisse de pension',
          goalCategory: 'goal_retirement_plan',
          targetDate: targetDate,
          profile: profile,
          goalAmount: 240000,
        );

        expect(
          (
            plan.monthlyTarget,
            plan.projectedOutcome,
            plan.projectedLow,
            plan.projectedHigh,
            plan.sources,
          ),
          equals((1000.0, 240000.0, null, null, const <String>[])),
          reason: 'An explicit no-LPP scenario owns only supplemental savings; '
              'it does not need a caisse return or cite LPP projection rules.',
        );
      },
    );

    test('v2 fingerprint has a deterministic pinned-now golden', () {
      final profile = CoachProfile(
        birthYear: 1986,
        dateOfBirth: DateTime(1986, 2, 14),
        canton: 'VD',
        salaireBrutMensuel: 8000,
        nombreDeMois: 13,
        prevoyance: const PrevoyanceProfile(
          avoirLppTotal: 150000,
          avoirLppObligatoire: 100000,
          avoirLppSurobligatoire: 50000,
          rendementCaisse: 0.02,
          salaireAssure: 90000,
          bonificationRate: 0.18,
          totalEpargne3a: 30000,
        ),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2051, 7, 16),
          label: 'Retraite synthétique',
        ),
        financialLiteracyLevel: FinancialLiteracyLevel.advanced,
        dataSources: const {
          'prevoyance.salaireAssure': ProfileDataSource.certificate,
          'prevoyance.bonificationRate': ProfileDataSource.certificate,
        },
        dataTimestamps: {
          'prevoyance.salaireAssure': DateTime.utc(2026, 7, 1, 8),
          'prevoyance.bonificationRate': DateTime.utc(2026, 7, 1, 8),
        },
        dataSourceDates: {
          'prevoyance.salaireAssure': DateTime.utc(2026, 7, 1),
          'prevoyance.bonificationRate': DateTime.utc(2026, 7, 1),
        },
        inferDataSources: false,
        createdAt: DateTime(2026, 7, 1),
        updatedAt: DateTime(2026, 7, 1),
      );

      final inputs = FinancialPlanLedgerInputs.fromProfile(
        profile,
        now: DateTime.utc(2026, 7, 16, 12),
      );

      expect(
        inputs.fingerprint,
        'mint-plan-input:v2:sha256:'
        '11d09c50ab6a48e4f0f210a9574fbe2236f3b2dc2fea6a2fa85dc0fd96cf36b6',
        reason: 'The pinned v2 canonical payload includes insured salary, '
            'bonification rate, effective age, and canonical confidence.',
      );
    });

    test('scenario ownership fields survive FinancialPlan JSON roundtrip',
        () async {
      final generated = await _generate(_retirementProfile());
      final confirmedAt = DateTime.utc(2026, 7, 16, 12, 30);
      final inputAsOf = DateTime.utc(2026, 7, 15);
      final decoded = FinancialPlan.fromJson({
        ...generated.toJson(),
        'goalAmount': _retirementGoalAmount,
        'scenarioId': 'scenario-g1-bnd06-synthetic',
        'confirmedAt': confirmedAt.toIso8601String(),
        'inputAsOf': inputAsOf.toIso8601String(),
      }).toJson();

      expect(
        {
          'goalAmount': decoded['goalAmount'],
          'scenarioId': decoded['scenarioId'],
          'confirmedAt': decoded['confirmedAt'],
          'inputAsOf': decoded['inputAsOf'],
        },
        equals({
          'goalAmount': _retirementGoalAmount,
          'scenarioId': 'scenario-g1-bnd06-synthetic',
          'confirmedAt': confirmedAt.toIso8601String(),
          'inputAsOf': inputAsOf.toIso8601String(),
        }),
        reason: 'A confirmed plan owns a durable scenario; GoalA is neither '
            'its amount store nor its identity.',
      );
    });

    test('legacy JSON recovers goal amount from one valid 100% milestone only',
        () async {
      final generated = await _generate(_retirementProfile());
      final legacy = Map<String, dynamic>.from(generated.toJson())
        ..remove('goalAmount')
        ..['milestones'] = [
          {
            'targetDate': generated.targetDate.toIso8601String(),
            'targetAmount': 24000.0,
            'description': '100% atteint — 24000 CHF',
          },
        ];

      expect(
        FinancialPlan.fromJson(legacy).toJson()['goalAmount'],
        24000.0,
        reason: 'Legacy recovery is a bounded one-time migration, not a '
            'general rule that the last milestone owns the scenario amount.',
      );
    });

    test('explicit invalid goal amount never falls back to milestone output',
        () async {
      final generated = await _generate(_retirementProfile());
      for (final invalidAmount in <Object>[0, -1, double.nan, 'corrupted']) {
        final corrupted = <String, dynamic>{
          ...generated.toJson(),
          'goalAmount': invalidAmount,
          'milestones': [
            {
              'targetDate': generated.targetDate.toIso8601String(),
              'targetAmount': 24000.0,
              'description': '100% atteint — 24000 CHF',
            },
          ],
        };

        expect(
          FinancialPlan.fromJson(corrupted).goalAmount,
          isNull,
          reason: 'Only an absent legacy field can use bounded migration. An '
              'explicit corrupted scenario amount ($invalidAmount) must '
              'remain fail-closed.',
        );
      }
    });

    test('GoalA drift does not stale an unlinked confirmed scenario', () async {
      final original = _retirementProfile();
      final plan = await _generate(original);
      final changedGoal = original.copyWith(
        goalA: GoalA(
          type: GoalAType.achatImmo,
          targetDate: DateTime(2032, 1, 1),
          targetAmount: 900000,
          label: 'Projet sans lien avec le scénario retraite',
        ),
      );
      final provider = FinancialPlanProvider()..setPlanDirect(plan);
      addTearDown(provider.dispose);

      provider.checkStalenessForTest(changedGoal);

      expect(provider.isPlanStale, isFalse);
    });
  });
}
