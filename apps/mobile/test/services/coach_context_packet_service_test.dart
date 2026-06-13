import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/budget_snapshot.dart';
import 'package:mint_mobile/models/coach_context_packet.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/data_spine_snapshot.dart';
import 'package:mint_mobile/services/data_spine/coach_context_packet_service.dart';
import 'package:mint_mobile/services/data_spine/data_spine_service.dart';

void main() {
  final fixedNow = DateTime.utc(2026, 5, 23, 12);

  CoachProfile buildProfile({
    PrevoyanceProfile prevoyance = const PrevoyanceProfile(
      anneesContribuees: 18,
      lacunesAVS: 2,
      renteAVSEstimeeMensuelle: 1800,
      avoirLppTotal: 50000,
      salaireAssure: 70000,
      rachatMaximum: 25000,
      nombre3a: 1,
      totalEpargne3a: 12000,
    ),
    Map<String, ProfileDataSource> dataSources = const {
      'prevoyance.avoirLppTotal': ProfileDataSource.certificate,
      'prevoyance.totalEpargne3a': ProfileDataSource.userInput,
      'depenses.loyer': ProfileDataSource.userInput,
      'depenses.assuranceMaladie': ProfileDataSource.userInput,
      'patrimoine.epargneLiquide': ProfileDataSource.userInput,
      'dettes.totalDettes': ProfileDataSource.userInput,
    },
    Map<String, DateTime> dataTimestamps = const {},
    List<PlannedMonthlyContribution> plannedContributions = const [
      PlannedMonthlyContribution(
        id: 'primary_3a',
        label: '3a',
        amount: 500,
        category: '3a',
        isAutomatic: true,
      ),
    ],
    GoalA? goal,
  }) {
    return CoachProfile(
      firstName: 'Julien',
      birthYear: 1987,
      canton: 'VD',
      commune: 'Lausanne',
      salaireBrutMensuel: 8000,
      nombreDeMois: 13,
      employmentStatus: 'salarie',
      etatCivil: CoachCivilStatus.celibataire,
      depenses: const DepensesProfile(
        loyer: 2100,
        assuranceMaladie: 430,
        transport: 120,
        telecom: 80,
      ),
      prevoyance: prevoyance,
      patrimoine: const PatrimoineProfile(
        epargneLiquide: 18000,
        investissements: 7000,
      ),
      dettes: const DetteProfile(
        creditConsommation: 3000,
        mensualiteCreditConso: 250,
      ),
      goalA: goal ??
          GoalA(
            type: GoalAType.retraite,
            targetDate: DateTime.utc(2052),
            label: 'Retraite',
          ),
      plannedContributions: plannedContributions,
      dataSources: dataSources,
      dataTimestamps: dataTimestamps,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 5, 1),
    );
  }

  CoachContextPacket buildPacket({
    CoachProfile? profile,
  }) {
    final spine =
        DataSpineService.fromProfile(profile ?? buildProfile(), now: fixedNow);
    return CoachContextPacketService.fromSpine(spine);
  }

  CoachContextFact fact(CoachContextPacket packet, String id) {
    return packet.facts.singleWhere((f) => f.id == id);
  }

  DataSpineSnapshot syntheticSpine({
    TrajectoryStatus status = TrajectoryStatus.onTrack,
  }) {
    const knownMeta = SpineFieldMeta(
      source: ProfileDataSource.certificate,
      confidence: FieldConfidence.known,
      freshness: FieldFreshness.fresh,
      updatedAt: null,
      sensitive: true,
    );
    final monthlyRequired =
        status == TrajectoryStatus.insufficientData ? null : 111.0;
    final monthlyGap = switch (status) {
      TrajectoryStatus.onTrack => -22.0,
      TrajectoryStatus.drifting => 333.0,
      TrajectoryStatus.blocked => null,
      TrajectoryStatus.insufficientData => null,
    };
    return DataSpineSnapshot(
      situation: const FinancialSituation(
        firstName: SpineValue(value: 'Hidden', meta: knownMeta),
        birthYear: SpineValue(value: 1979, meta: knownMeta),
        canton: SpineValue(value: 'GE', meta: knownMeta),
        commune: SpineValue(value: 'DoNotExpose', meta: knownMeta),
        grossAnnualIncome: SpineValue(value: 123456, meta: knownMeta),
        employmentStatus: SpineValue(value: 'salarie', meta: knownMeta),
        monthlyHousingCost: SpineValue(value: 2222, meta: knownMeta),
        lamalPremiumMonthly: SpineValue(value: 444, meta: knownMeta),
        liquidSavings: SpineValue(value: 9999, meta: knownMeta),
        investments: SpineValue(value: 8888, meta: knownMeta),
        totalDebt: SpineValue(value: 7777, meta: knownMeta),
        housingStatus: SpineValue(value: 'locataire', meta: knownMeta),
        activeGoalType: SpineValue(value: GoalAType.custom, meta: knownMeta),
      ),
      budget: const BudgetSnapshot(
        present: PresentBudget(
          monthlyNet: 6100,
          monthlyCharges: 4100,
          monthlySavings: 600,
          monthlyFree: 1400,
        ),
        capImpacts: [],
        stage: BudgetStage.presentOnly,
        confidenceScore: 71,
      ),
      pillars: const PillarPosition(
        avs: AvsPosition(
          contributionYears: PillarFact(
            value: 31,
            state: PillarFactState.estimated,
            meta: knownMeta,
          ),
          gaps: PillarFact.missing(),
          estimatedMonthlyPension: PillarFact.missing(),
          ramd: PillarFact.missing(),
        ),
        lpp: LppPosition(
          totalBalance: PillarFact(
            value: 222000,
            state: PillarFactState.known,
            meta: knownMeta,
          ),
          mandatoryBalance: PillarFact.missing(),
          supplementaryBalance: PillarFact.missing(),
          insuredSalary: PillarFact.missing(),
          buybackMax: PillarFact.missing(),
        ),
        pillar3a: Pillar3aPosition(
          totalBalance: PillarFact.missing(),
          accountsCount: PillarFact.missing(),
          annualContribution: PillarFact.missing(),
          canContribute: true,
        ),
      ),
      trajectory: TrajectorySummary(
        status: status,
        currentMonthlyFree: 1400,
        currentMonthlyCapacity: 2000,
        targetAmount: status == TrajectoryStatus.insufficientData ? null : 1200,
        monthsToTarget: status == TrajectoryStatus.insufficientData ? null : 12,
        monthlyRequired: monthlyRequired,
        monthlyGap: monthlyGap,
        nextLeverId: switch (status) {
          TrajectoryStatus.onTrack => 'maintain_plan',
          TrajectoryStatus.drifting => 'increase_monthly_capacity',
          TrajectoryStatus.blocked => 'stabilize_budget',
          TrajectoryStatus.insufficientData => 'define_target',
        },
      ),
      computedAt: fixedNow,
    );
  }

  group('CoachContextPacketService', () {
    test('maps allowlisted known facts from DataSpineSnapshot', () {
      final packet = buildPacket();

      expect(fact(packet, 'profile.canton').value, 'VD');
      expect(fact(packet, 'profile.birth_year').value, 1987);
      expect(fact(packet, 'situation.gross_annual_income').value, 104000);
      expect(fact(packet, 'situation.monthly_housing_cost').value, 2100);
      expect(fact(packet, 'situation.lamal_premium_monthly').value, 430);
      expect(fact(packet, 'situation.liquid_savings').value, 18000);
      expect(fact(packet, 'situation.investments').value, 7000);
      expect(fact(packet, 'situation.total_debt').value, 3000);
      expect(fact(packet, 'budget.monthly_net').value, isA<double>());
      expect(fact(packet, 'budget.monthly_free').value, isA<double>());
      expect(fact(packet, 'budget.monthly_capacity').value, isA<double>());
      expect(fact(packet, 'pillar.avs.contribution_years').value, 18);
      expect(fact(packet, 'pillar.avs.gaps').value, 2);
      expect(fact(packet, 'pillar.lpp.total_balance').value, 50000);
      expect(fact(packet, 'pillar.3a.total_balance').value, 12000);
      expect(fact(packet, 'pillar.3a.annual_contribution').value, 6000);
    });

    test('emits displayed budget facts from the Data Spine snapshot', () {
      final profile = buildProfile(
        plannedContributions: const [],
      ).copyWith(
        explicitMonthlyNetIncome: 5000.4,
        depenses: const DepensesProfile(
          loyer: 1200.5,
          assuranceMaladie: 400.5,
        ),
        dettes: const DetteProfile(mensualiteCreditConso: 200.5),
      );
      final spine = DataSpineService.fromProfile(profile, now: fixedNow);
      final packet = CoachContextPacketService.fromSpine(spine);

      final monthlyNet = fact(packet, 'budget.monthly_net').value as double;
      final monthlyCharges =
          fact(packet, 'budget.monthly_charges').value as double;
      final monthlyFree = fact(packet, 'budget.monthly_free').value as double;

      expect(monthlyNet, spine.budget.present.monthlyNet);
      expect(monthlyCharges, spine.budget.present.monthlyCharges);
      expect(monthlyFree, spine.budget.present.monthlyFree);
      expect(monthlyNet, 5000);
      expect(monthlyNet, isNot(5000.4));
      expect(monthlyCharges, monthlyCharges.roundToDouble());
      expect(monthlyFree, monthlyFree.roundToDouble());
    });

    test('preserves source and freshness metadata on facts', () {
      final updatedAt = DateTime.utc(2026, 4, 20);
      final packet = buildPacket(
        profile: buildProfile(
          dataTimestamps: {'prevoyance.avoirLppTotal': updatedAt},
        ),
      );

      final lpp = fact(packet, 'pillar.lpp.total_balance');
      expect(lpp.source, 'certificate');
      expect(lpp.confidence, 'known');
      expect(lpp.freshness, 'fresh');
      expect(lpp.updatedAt, updatedAt);
    });

    test('serializes trust metadata for facts sent to the coach packet', () {
      final packet = buildPacket().toSafeMap();
      final facts =
          (packet['facts'] as List<dynamic>).cast<Map<String, dynamic>>();
      final lpp = facts.singleWhere(
        (f) => f['id'] == 'pillar.lpp.total_balance',
      );

      expect(lpp['storage_location'], 'secureLocal');
      expect(lpp['sync_state'], 'localOnly');
      expect(lpp['ai_sharing_state'], 'sentToMintBackend');
      expect(lpp['delete_consequence'], 'clearsLocally');
    });

    test('passes through synthetic spine values and pillar fact state', () {
      final packet =
          CoachContextPacketService.fromSpine(syntheticSpine()).toSafeMap();
      final facts = packet['facts'] as List<dynamic>;
      final lpp = facts.cast<Map<String, dynamic>>().singleWhere(
            (f) => f['id'] == 'pillar.lpp.total_balance',
          );
      final avs = facts.cast<Map<String, dynamic>>().singleWhere(
            (f) => f['id'] == 'pillar.avs.contribution_years',
          );

      expect(lpp['value'], 222000);
      expect(lpp['state'], 'known');
      expect(avs['value'], 31);
      expect(avs['state'], 'estimated');
      expect(packet.toString(), isNot(contains('Hidden')));
      expect(packet.toString(), isNot(contains('DoNotExpose')));
    });

    test('emits missing fields for missing pillar facts and target amount', () {
      final packet = buildPacket(
        profile: buildProfile(prevoyance: const PrevoyanceProfile()),
      );

      expect(
        packet.missingFields.map((f) => f.fieldPath),
        containsAll([
          'pillars.avs.contributionYears',
          'pillars.avs.gaps',
          'pillars.avs.estimatedMonthlyPension',
          'pillars.lpp.totalBalance',
          'pillars.lpp.insuredSalary',
          'pillars.lpp.buybackMax',
          'pillars.pillar3a.totalBalance',
          'pillars.pillar3a.accountsCount',
          'trajectory.targetAmount',
        ]),
      );
    });

    test('omits untrusted situation amounts and asks for missing budget facts',
        () {
      final profile = CoachProfile(
        birthYear: 1987,
        canton: 'VD',
        salaireBrutMensuel: 8000,
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime.utc(2052),
          label: 'Retraite',
        ),
        depenses: const DepensesProfile(
          loyer: 1500,
          assuranceMaladie: 420,
        ),
      );

      final packet = buildPacket(profile: profile);
      final safe = packet.toSafeMap();
      final facts = (safe['facts'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map((fact) => fact['id'] as String)
          .toSet();
      final missing = (safe['missing_fields'] as List<dynamic>)
          .cast<Map<String, dynamic>>();

      expect(facts, isNot(contains('situation.monthly_housing_cost')));
      expect(facts, isNot(contains('situation.lamal_premium_monthly')));
      expect(
        missing,
        containsAll([
          containsPair('field_path', 'situation.monthlyHousingCost'),
          containsPair('field_path', 'situation.lamalPremiumMonthly'),
        ]),
      );
    });

    test('exposes trajectory status, next lever, and next question', () {
      final packet = buildPacket(
        profile: buildProfile(
          goal: GoalA(
            type: GoalAType.custom,
            targetDate: DateTime.utc(2027, 5, 23),
            targetAmount: 1200,
            label: 'Coussin',
          ),
        ),
      );

      expect(packet.trajectory.status, 'onTrack');
      expect(packet.trajectory.nextLeverId, 'maintain_plan');
      expect(
        packet.nextQuestions.map((q) => q.id),
        contains('confirm_plan_tracking'),
      );
    });

    test('maps every trajectory status to the expected next question', () {
      final expected = {
        TrajectoryStatus.onTrack: 'confirm_plan_tracking',
        TrajectoryStatus.blocked: 'review_fixed_charges',
        TrajectoryStatus.drifting: 'increase_monthly_capacity',
        TrajectoryStatus.insufficientData: 'define_target_amount',
      };

      for (final entry in expected.entries) {
        final packet = CoachContextPacketService.fromSpine(
          syntheticSpine(status: entry.key),
        );

        expect(packet.trajectory.status, entry.key.name);
        expect(packet.nextQuestions.single.id, entry.value);
      }
    });

    test('toSafeMap serializes only structured packet sections', () {
      final packet = buildPacket();
      final safe = packet.toSafeMap();

      expect(
          safe.keys,
          containsAll([
            'computed_at',
            'facts',
            'missing_fields',
            'trajectory',
            'next_questions',
            'readiness',
          ]));
      expect(safe.containsKey('wizard_answers_v2'), isFalse);
      expect(safe.containsKey('profile'), isFalse);

      final facts = safe['facts'] as List<dynamic>;
      final firstFact = facts.first as Map<String, dynamic>;
      expect(
          firstFact.keys, containsAll(['id', 'domain', 'field_path', 'value']));
      expect(firstFact.containsKey('raw_value'), isFalse);

      final missing = safe['missing_fields'] as List<dynamic>;
      if (missing.isNotEmpty) {
        final firstMissing = missing.first as Map<String, dynamic>;
        expect(
            firstMissing.keys, containsAll(['field_path', 'domain', 'reason']));
      }

      final trajectory = safe['trajectory'] as Map<String, dynamic>;
      expect(
        trajectory.keys,
        containsAll([
          'status',
          'current_monthly_free',
          'current_monthly_capacity',
          'next_lever_id',
        ]),
      );

      final readiness = safe['readiness'] as Map<String, dynamic>;
      expect(
        readiness.keys,
        containsAll([
          'overall_status',
          'sections',
          'missing_domains',
          'next_action_id',
        ]),
      );
    });

    test(
        'readiness summarizes missing domains and next action for partial data',
        () {
      final packet = buildPacket(
        profile: buildProfile(
          prevoyance: const PrevoyanceProfile(),
          goal: GoalA(
            type: GoalAType.custom,
            targetDate: DateTime.utc(2027, 5, 23),
            label: 'Coussin',
          ),
        ),
      );

      final readiness = packet.toSafeMap()['readiness'] as Map<String, dynamic>;

      expect(readiness['overall_status'], 'partial');
      expect(readiness['next_action_id'], 'define_target');
      expect(
        readiness['missing_domains'],
        containsAll(<String>[
          'pillar_avs',
          'pillar_lpp',
          'pillar_3a',
          'trajectory',
        ]),
      );
      expect(readiness.toString(), isNot(contains('Julien')));
      expect(readiness.toString(), isNot(contains('Lausanne')));
    });

    test('readiness prioritizes budget stabilization when budget is blocked',
        () {
      final base = syntheticSpine();
      final packet = CoachContextPacketService.fromSpine(
        DataSpineSnapshot(
          situation: base.situation,
          budget: const BudgetSnapshot(
            present: PresentBudget(
              monthlyNet: 6100,
              monthlyCharges: 6200,
              monthlySavings: 0,
              monthlyFree: -100,
            ),
            capImpacts: [],
            stage: BudgetStage.presentOnly,
            confidenceScore: 71,
          ),
          pillars: base.pillars,
          trajectory: base.trajectory,
          computedAt: base.computedAt,
        ),
      );

      final readiness = packet.toSafeMap()['readiness'] as Map<String, dynamic>;

      expect(readiness['overall_status'], 'blocked');
      expect(readiness['next_action_id'], 'stabilize_budget');
      expect(readiness['missing_domains'], contains('budget'));
    });

    test('toSafeMap does not expose excluded PII or raw profile fields', () {
      final safe = buildPacket().toSafeMap().toString();

      expect(safe, isNot(contains('Julien')));
      expect(safe, isNot(contains('Lausanne')));
      expect(safe.toLowerCase(), isNot(contains('employer')));
      expect(safe.toLowerCase(), isNot(contains('address')));
      expect(safe.toLowerCase(), isNot(contains('npa')));
      expect(safe.toLowerCase(), isNot(contains('wizard_answers')));
    });

    test('facts stay inside the strict allowlist', () {
      final packet = buildPacket();

      expect(
        packet.facts.map((f) => f.id).toSet().difference(
              CoachContextPacketService.allowedFactIds,
            ),
        isEmpty,
      );
    });
  });
}
