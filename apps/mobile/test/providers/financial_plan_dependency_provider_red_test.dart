import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/widgets.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/financial_plan.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/financial_plan_provider.dart';
import 'package:mint_mobile/services/financial_plan_service.dart';
import 'package:mint_mobile/services/plan_generation_service.dart';
import 'package:mint_mobile/services/secure_wizard_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

const _owner = '11111111-1111-4111-8111-111111111111';
const _otherOwner = '22222222-2222-4222-8222-222222222222';

class _Ledger extends CoachProfileProvider {
  _Ledger(this._testProfile, this._owner, {LppEvidenceSnapshot? lppSnapshot})
      : _lppSnapshot = lppSnapshot;

  CoachProfile _testProfile;
  String _owner;
  final LppEvidenceSnapshot? _lppSnapshot;

  @override
  CoachProfile get profile => _testProfile;

  @override
  bool get isLoaded => true;

  @override
  String get canonicalProfileOwnerId => _owner;

  @override
  LppEvidenceSnapshot? currentLppSnapshot(LppEvidenceOwnerKind ownerKind) =>
      ownerKind == LppEvidenceOwnerKind.self ? _lppSnapshot : null;

  void replaceProfile(CoachProfile profile) {
    _testProfile = profile;
    notifyListeners();
  }

  void replaceOwner(String owner) {
    _owner = owner;
    notifyListeners();
  }
}

class _OwnerChangesAtFinalPublication extends _Ledger {
  _OwnerChangesAtFinalPublication(CoachProfile profile)
      : super(profile, _owner);

  var ownerReads = 0;

  @override
  String get canonicalProfileOwnerId {
    ownerReads += 1;
    return ownerReads >= 4 ? _otherOwner : _owner;
  }
}

class _LifecycleLedger extends _Ledger {
  _LifecycleLedger(super.profile, super.owner);

  int addListenerCalls = 0;
  int removeListenerCalls = 0;

  @override
  void addListener(VoidCallback listener) {
    addListenerCalls++;
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    removeListenerCalls++;
    super.removeListener(listener);
  }
}

final class _FalseSetPreferencesStore extends InMemorySharedPreferencesStore {
  _FalseSetPreferencesStore() : super.empty();

  final failSetKeys = <String>{};

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (!failSetKeys.contains(key)) {
      return super.setValue(valueType, key, value);
    }
    await super.setValue(valueType, key, value);
    return false;
  }
}

final class _FailRollbackPointerStore extends InMemorySharedPreferencesStore {
  _FailRollbackPointerStore() : super.empty();

  var pointerWrites = 0;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key == 'flutter.financial_plan_active_slot_v1') {
      pointerWrites += 1;
      if (pointerWrites >= 5) return false;
    }
    return super.setValue(valueType, key, value);
  }
}

class _ManualTimer implements Timer {
  _ManualTimer(this.duration, this.callback);

  final Duration duration;
  final void Function() callback;
  bool _active = true;

  void fire() {
    if (!_active) return;
    _active = false;
    callback();
  }

  @override
  void cancel() => _active = false;

  @override
  bool get isActive => _active;

  @override
  int get tick => _active ? 0 : 1;
}

CoachProfile _profile({String firstName = 'Avant'}) => CoachProfile(
      firstName: firstName,
      birthYear: 1986,
      canton: 'VD',
      salaireBrutMensuel: 0,
      goalA: GoalA(
        type: GoalAType.custom,
        label: 'Objectif synthétique',
        targetDate: DateTime.utc(2030, 6, 30),
      ),
      inferDataSources: false,
    );

CoachProfile _noLppProfile() => CoachProfile(
      birthYear: 1986,
      dateOfBirth: DateTime.utc(1986, 1, 1),
      canton: 'VD',
      salaireBrutMensuel: 8000,
      prevoyance: const PrevoyanceProfile(hasPensionFund: false),
      goalA: GoalA(
        type: GoalAType.retraite,
        label: 'Retraite synthétique',
        targetDate: DateTime.utc(2051, 8, 1),
      ),
      inferDataSources: false,
      dataSources: const {
        'prevoyance.hasPensionFund': ProfileDataSource.userInput,
        'dateOfBirth': ProfileDataSource.userInput,
      },
      dataTimestamps: {
        'prevoyance.hasPensionFund': DateTime.utc(2026, 7, 16, 9),
        'dateOfBirth': DateTime.utc(2026, 7, 16, 9),
      },
      dataSourceDates: const {
        'prevoyance.hasPensionFund': null,
        'dateOfBirth': null,
      },
    );

({CoachProfile profile, LppEvidenceSnapshot snapshot}) _lppFixture() {
  final stamp = DateTime.utc(2026, 7, 1, 9);
  const capital = 150000.0;
  final profile = CoachProfile(
    birthYear: 1986,
    dateOfBirth: DateTime.utc(1986, 1, 1),
    gender: 'M',
    canton: 'VD',
    salaireBrutMensuel: 8000,
    prevoyance: const PrevoyanceProfile(
      hasPensionFund: true,
      avoirLppTotal: capital,
    ),
    goalA: GoalA(
      type: GoalAType.retraite,
      label: 'Retraite synthétique',
      targetDate: DateTime.utc(2051, 8, 1),
    ),
    inferDataSources: false,
    dataSources: const {
      'prevoyance.hasPensionFund': ProfileDataSource.userInput,
      'dateOfBirth': ProfileDataSource.userInput,
      'gender': ProfileDataSource.userInput,
      'salaireBrutMensuel': ProfileDataSource.userInput,
      'prevoyance.avoirLppTotal': ProfileDataSource.certificate,
    },
    dataTimestamps: {
      'prevoyance.hasPensionFund': stamp,
      'dateOfBirth': stamp,
      'gender': stamp,
      'salaireBrutMensuel': stamp,
      'prevoyance.avoirLppTotal': stamp,
    },
    dataSourceDates: const {
      'prevoyance.hasPensionFund': null,
      'dateOfBirth': null,
      'gender': null,
      'salaireBrutMensuel': null,
      'prevoyance.avoirLppTotal': null,
    },
  );
  final fact = LppEvidenceFact(
    value: capital,
    unit: LppEvidenceUnit.chf,
    profileOwnerId: _owner,
    actorProfileOwnerId: _owner,
    source: ProfileDataSource.certificate.name,
    sourceDate: null,
    updatedAt: stamp,
  );
  return (
    profile: profile,
    snapshot: LppEvidenceSnapshot(
      snapshotId: '44444444-4444-4444-8444-444444444444',
      facts: {
        LppEvidenceFactKey.vestedBenefitsCapitalChf: fact,
      },
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  test('one timer flips freshness exactly at the exclusive validUntil',
      () async {
    var now = DateTime.utc(2026, 7, 16, 9);
    final plan = await PlanGenerationService.generate(
      goalDescription: 'Objectif synthétique',
      goalCategory: 'goal_general',
      targetDate: DateTime.utc(2030, 6, 30),
      profile: _profile(),
      profileOwnerId: _owner,
      selfLppSnapshot: null,
      goalAmount: 120000,
      now: now,
    );
    final confirmedPlan = plan.copyWith(confirmedAt: now);
    final timers = <_ManualTimer>[];
    final ledger = _Ledger(_profile(), _owner);
    final provider = FinancialPlanProvider(
      clock: () => now,
      timerFactory: (duration, callback) {
        final timer = _ManualTimer(duration, callback);
        timers.add(timer);
        return timer;
      },
    )
      ..setPlanDirect(confirmedPlan)
      ..attachProfileProvider(ledger);
    addTearDown(ledger.dispose);
    addTearDown(provider.dispose);

    expect(provider.isPlanStale, isFalse);
    expect(timers.where((timer) => timer.isActive), hasLength(1));

    now = confirmedPlan.validUntil!;
    timers.last.fire();
    expect(provider.isPlanStale, isTrue);
  });

  test('general plan ignores unrelated profile drift but not owner drift',
      () async {
    final now = DateTime.utc(2026, 7, 16, 9);
    final plan = await PlanGenerationService.generate(
      goalDescription: 'Objectif synthétique',
      goalCategory: 'goal_general',
      targetDate: DateTime.utc(2030, 6, 30),
      profile: _profile(),
      profileOwnerId: _owner,
      selfLppSnapshot: null,
      goalAmount: 120000,
      now: now,
    );
    final confirmedPlan = plan.copyWith(confirmedAt: now);
    final ledger = _Ledger(_profile(), _owner);
    final provider = FinancialPlanProvider(clock: () => now)
      ..setPlanDirect(confirmedPlan)
      ..attachProfileProvider(ledger);
    addTearDown(ledger.dispose);
    addTearDown(provider.dispose);

    ledger.replaceProfile(_profile(firstName: 'Après'));
    expect(provider.isPlanStale, isFalse);

    ledger.replaceOwner(_otherOwner);
    expect(provider.isPlanStale, isTrue);
  });

  test('unauthorized plan is rejected before persistence', () async {
    final now = DateTime.utc(2026, 7, 16, 9);
    final plan = await PlanGenerationService.generate(
      goalDescription: 'Objectif synthétique',
      goalCategory: 'goal_general',
      targetDate: DateTime.utc(2030, 6, 30),
      profile: _profile(),
      profileOwnerId: _owner,
      selfLppSnapshot: null,
      goalAmount: 120000,
      now: now,
    );
    final ledger = _Ledger(_profile(), _otherOwner);
    final provider = FinancialPlanProvider(clock: () => now)
      ..attachProfileProvider(ledger);
    addTearDown(ledger.dispose);
    addTearDown(provider.dispose);

    await expectLater(provider.setPlan(plan), throwsStateError);
    expect(await FinancialPlanService.loadCurrent(), isNull);
    expect(provider.currentPlan, isNull);
  });

  test('false durable publication never publishes the plan provider', () async {
    final now = DateTime.utc(2026, 7, 16, 9);
    final draft = await PlanGenerationService.generate(
      goalDescription: 'Objectif synthétique',
      goalCategory: 'goal_general',
      targetDate: DateTime.utc(2030, 6, 30),
      profile: _profile(),
      profileOwnerId: _owner,
      selfLppSnapshot: null,
      goalAmount: 120000,
      now: now,
    );
    final store = _FalseSetPreferencesStore()
      ..failSetKeys.add('flutter.financial_plan_active_slot_v1');
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = store;
    final ledger = _Ledger(_profile(), _owner);
    final provider = FinancialPlanProvider(clock: () => now)
      ..attachProfileProvider(ledger);
    addTearDown(ledger.dispose);
    addTearDown(provider.dispose);

    await expectLater(
      provider.setPlan(draft.copyWith(confirmedAt: now)),
      throwsStateError,
    );

    expect(provider.currentPlan, isNull);
    expect(await FinancialPlanService.loadCurrent(), isNull);
    expect(
      (await store.getAll()),
      isNot(contains('flutter.financial_plan_active_slot_v1')),
    );
  });

  test('an unconfirmed generation draft is never persisted', () async {
    final now = DateTime.utc(2026, 7, 16, 9);
    final draft = await PlanGenerationService.generate(
      goalDescription: 'Objectif synthétique',
      goalCategory: 'goal_general',
      targetDate: DateTime.utc(2030, 6, 30),
      profile: _profile(),
      profileOwnerId: _owner,
      selfLppSnapshot: null,
      goalAmount: 120000,
      now: now,
    );
    final ledger = _Ledger(_profile(), _owner);
    final provider = FinancialPlanProvider(clock: () => now)
      ..attachProfileProvider(ledger);
    addTearDown(ledger.dispose);
    addTearDown(provider.dispose);

    expect(draft.confirmedAt, isNull);
    await expectLater(provider.setPlan(draft), throwsStateError);
    expect(await FinancialPlanService.loadCurrent(), isNull);
    expect(provider.currentPlan, isNull);
  });

  test('no-LPP plan with a caisse assumption is stale and rejected', () async {
    final now = DateTime.utc(2026, 7, 16, 9);
    final profile = _noLppProfile();
    final draft = await PlanGenerationService.generate(
      goalDescription: 'Retraite synthétique',
      goalCategory: 'goal_retirement_plan',
      targetDate: DateTime.utc(2051, 8, 1),
      profile: profile,
      profileOwnerId: _owner,
      selfLppSnapshot: null,
      goalAmount: 3000000,
      prospectiveLppReturn: null,
      now: now,
    );
    final assumptions = draft.projectionAssumptions!;
    final malformed = draft.copyWith(
      confirmedAt: now,
      projectionAssumptions: FinancialPlanProjectionAssumptions(
        caisseReturnBase: 0.02,
        caisseReturnLow: assumptions.caisseReturnLow,
        caisseReturnHigh: assumptions.caisseReturnHigh,
        supplementalMonthlySavingsReturn:
            assumptions.supplementalMonthlySavingsReturn,
        salaryBasis: assumptions.salaryBasis,
        bonificationBasis: assumptions.bonificationBasis,
        projectionAsOf: assumptions.projectionAsOf,
      ),
    );
    final ledger = _Ledger(profile, _owner);
    final provider = FinancialPlanProvider(clock: () => now)
      ..setPlanDirect(malformed)
      ..attachProfileProvider(ledger);
    addTearDown(ledger.dispose);
    addTearDown(provider.dispose);

    expect(provider.isPlanStale, isTrue);
    await expectLater(provider.setPlan(malformed), throwsStateError);
    expect(provider.currentPlan, malformed);
  });

  test('provider rejects persisted salary and confidence drift outside hash',
      () async {
    final now = DateTime.utc(2026, 7, 16, 9);
    final fixture = _lppFixture();
    final draft = await PlanGenerationService.generate(
      goalDescription: 'Retraite synthétique',
      goalCategory: 'goal_retirement_plan',
      targetDate: DateTime.utc(2051, 8, 1),
      profile: fixture.profile,
      profileOwnerId: _owner,
      selfLppSnapshot: fixture.snapshot,
      goalAmount: 3000000,
      prospectiveLppReturn: 0.02,
      now: now,
    );
    final assumptions = draft.projectionAssumptions!;
    final wrongSalary = draft.copyWith(
      confirmedAt: now,
      projectionAssumptions: FinancialPlanProjectionAssumptions(
        caisseReturnBase: assumptions.caisseReturnBase,
        caisseReturnLow: assumptions.caisseReturnLow,
        caisseReturnHigh: assumptions.caisseReturnHigh,
        supplementalMonthlySavingsReturn:
            assumptions.supplementalMonthlySavingsReturn,
        salaryBasis: const FinancialPlanSalaryBasis(
          kind: 'monthlySalaryTimesTwelve',
          annualChf: 120000,
        ),
        bonificationBasis: assumptions.bonificationBasis,
        projectionAsOf: assumptions.projectionAsOf,
      ),
    );
    final wrongConfidence = draft.copyWith(
      confirmedAt: now,
      confidenceLevel: draft.confidenceLevel + 1,
    );
    final ledger = _Ledger(
      fixture.profile,
      _owner,
      lppSnapshot: fixture.snapshot,
    );
    final provider = FinancialPlanProvider(clock: () => now)
      ..attachProfileProvider(ledger);
    addTearDown(ledger.dispose);
    addTearDown(provider.dispose);

    provider.setPlanDirect(wrongSalary);
    expect(provider.isPlanStale, isTrue);
    await expectLater(provider.setPlan(wrongSalary), throwsStateError);

    provider.setPlanDirect(wrongConfidence);
    expect(provider.isPlanStale, isTrue);
    await expectLater(provider.setPlan(wrongConfidence), throwsStateError);
  });

  test('provider marks every tampered material projection flag stale',
      () async {
    final now = DateTime.utc(2026, 7, 16, 9);
    final fixture = _lppFixture();
    final draft = await PlanGenerationService.generate(
      goalDescription: 'Retraite synthétique',
      goalCategory: 'goal_retirement_plan',
      targetDate: DateTime.utc(2051, 8, 1),
      profile: fixture.profile,
      profileOwnerId: _owner,
      selfLppSnapshot: fixture.snapshot,
      goalAmount: 3000000,
      prospectiveLppReturn: 0.02,
      now: now,
    );
    final original = draft.projectionAssumptions!;
    FinancialPlanProjectionAssumptions tamper({
      bool? annual,
      bool? early,
      bool? postReference,
    }) =>
        FinancialPlanProjectionAssumptions(
          caisseReturnBase: original.caisseReturnBase,
          caisseReturnLow: original.caisseReturnLow,
          caisseReturnHigh: original.caisseReturnHigh,
          supplementalMonthlySavingsReturn:
              original.supplementalMonthlySavingsReturn,
          salaryBasis: original.salaryBasis,
          bonificationBasis: original.bonificationBasis,
          projectionAsOf: original.projectionAsOf,
          annualProjectionUsesWholeYears:
              annual ?? original.annualProjectionUsesWholeYears,
          requiresFundAuthorizationBefore63:
              early ?? original.requiresFundAuthorizationBefore63,
          assumesPostReferenceGainfulActivity:
              postReference ?? original.assumesPostReferenceGainfulActivity,
        );
    final ledger = _Ledger(
      fixture.profile,
      _owner,
      lppSnapshot: fixture.snapshot,
    );
    final provider = FinancialPlanProvider(clock: () => now)
      ..attachProfileProvider(ledger);
    addTearDown(ledger.dispose);
    addTearDown(provider.dispose);

    for (final assumptions in <FinancialPlanProjectionAssumptions>[
      tamper(annual: false),
      tamper(early: !original.requiresFundAuthorizationBefore63),
      tamper(postReference: !original.assumesPostReferenceGainfulActivity),
    ]) {
      final tampered = draft.copyWith(
        confirmedAt: now,
        projectionAssumptions: assumptions,
      );
      provider.setPlanDirect(tampered);
      expect(provider.isPlanStale, isTrue);
      await expectLater(provider.setPlan(tampered), throwsStateError);

      final coldProvider = FinancialPlanProvider(
        clock: () => now,
        loadAction: () async => tampered,
      )..attachProfileProvider(ledger);
      await coldProvider.loadFromPersistence();
      expect(coldProvider.currentPlan, tampered);
      expect(coldProvider.isPlanStale, isTrue);
      coldProvider.dispose();
    }
  });

  test('postcommit authority drift publishes durable B only as stale',
      () async {
    final now = DateTime.utc(2026, 7, 16, 9);
    final draft = await PlanGenerationService.generate(
      goalDescription: 'Objectif synthétique',
      goalCategory: 'goal_general',
      targetDate: DateTime.utc(2030, 6, 30),
      profile: _profile(),
      profileOwnerId: _owner,
      selfLppSnapshot: null,
      goalAmount: 120000,
      now: now,
    );
    final plan = draft.copyWith(confirmedAt: now);
    final ledger = _OwnerChangesAtFinalPublication(_profile());
    final provider = FinancialPlanProvider(clock: () => now)
      ..attachProfileProvider(ledger);
    addTearDown(ledger.dispose);
    addTearDown(provider.dispose);

    await expectLater(provider.setPlan(plan), completes);
    expect(ledger.ownerReads, 4);
    expect(provider.currentPlan?.id, plan.id);
    expect(provider.isPlanStale, isTrue);
    expect((await FinancialPlanService.loadCurrent())?.id, plan.id);
  });

  test('drift plus impossible rollback never throws while durable B survives',
      () async {
    final store = _FailRollbackPointerStore();
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = store;
    final now = DateTime.utc(2026, 7, 16, 9);
    final seedDraft = await PlanGenerationService.generate(
      goalDescription: 'Plan durable antérieur',
      goalCategory: 'goal_general',
      targetDate: DateTime.utc(2030, 6, 30),
      profile: _profile(),
      profileOwnerId: _owner,
      selfLppSnapshot: null,
      goalAmount: 90000,
      now: now,
    );
    for (var index = 0; index < 3; index++) {
      await FinancialPlanService.save(
        seedDraft.copyWith(
          id: 'seed-$index',
          scenarioId: '33333333-3333-4333-8333-33333333333$index',
          confirmedAt: now,
        ),
      );
    }
    final preferences = await SharedPreferences.getInstance();
    final pointerBefore =
        preferences.getString('financial_plan_active_slot_v1');
    expect(pointerBefore, isNotNull);
    final durableBefore =
        await SecureWizardStore.readFinancialPlanSlot(pointerBefore!);
    expect(durableBefore, isNotNull);

    final candidateDraft = await PlanGenerationService.generate(
      goalDescription: 'Nouveau plan rejeté',
      goalCategory: 'goal_general',
      targetDate: DateTime.utc(2031, 6, 30),
      profile: _profile(),
      profileOwnerId: _owner,
      selfLppSnapshot: null,
      goalAmount: 120000,
      now: now,
    );
    final candidate = candidateDraft.copyWith(confirmedAt: now);
    final ledger = _OwnerChangesAtFinalPublication(_profile());
    final provider = FinancialPlanProvider(clock: () => now)
      ..attachProfileProvider(ledger);
    addTearDown(ledger.dispose);
    addTearDown(provider.dispose);

    await expectLater(provider.setPlan(candidate), completes);

    expect(ledger.ownerReads, 4);
    expect(provider.currentPlan?.id, candidate.id);
    expect(provider.isPlanStale, isTrue);
    expect(preferences.getString('financial_plan_v1'), isNull);
    expect(
      preferences.getString('financial_plan_active_slot_v1'),
      isNot(pointerBefore),
      reason: 'After B is durably committed, late drift must not attempt a '
          'fallible rollback that can return thrown+B.',
    );
    expect(durableBefore, isNotNull);
    expect((await FinancialPlanService.loadCurrent())?.id, candidate.id);

    final coldLedger = _Ledger(_profile(), _otherOwner);
    final cold = FinancialPlanProvider(clock: () => now)
      ..attachProfileProvider(coldLedger);
    addTearDown(coldLedger.dispose);
    addTearDown(cold.dispose);
    await cold.loadFromPersistence();
    expect(cold.currentPlan?.id, candidate.id);
    expect(cold.isPlanStale, isTrue);
    expect(store.pointerWrites, 4,
        reason: 'No rollback pointer write is legal');
  });

  test('rebind detaches the old ledger and idempotent bind adds once',
      () async {
    final now = DateTime.utc(2026, 7, 16, 9);
    final draft = await PlanGenerationService.generate(
      goalDescription: 'Objectif synthétique',
      goalCategory: 'goal_general',
      targetDate: DateTime.utc(2030, 6, 30),
      profile: _profile(),
      profileOwnerId: _owner,
      selfLppSnapshot: null,
      goalAmount: 120000,
      now: now,
    );
    final first = _LifecycleLedger(_profile(), _owner);
    final second = _LifecycleLedger(_profile(), _owner);
    final provider = FinancialPlanProvider(clock: () => now)
      ..setPlanDirect(draft.copyWith(confirmedAt: now))
      ..attachProfileProvider(first)
      ..attachProfileProvider(first)
      ..attachProfileProvider(second);
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    addTearDown(provider.dispose);

    expect(first.addListenerCalls, 1);
    expect(first.removeListenerCalls, 1);
    expect(second.addListenerCalls, 1);
    first.replaceOwner(_otherOwner);
    expect(provider.isPlanStale, isFalse);
    second.replaceOwner(_otherOwner);
    expect(provider.isPlanStale, isTrue);
  });

  test('provider replays and rejects every persisted calculator output drift',
      () async {
    final now = DateTime.utc(2026, 7, 16, 9);
    final fixture = _lppFixture();
    final draft = await PlanGenerationService.generate(
      goalDescription: 'Retraite synthétique',
      goalCategory: 'goal_retirement_plan',
      targetDate: DateTime.utc(2051, 8, 1),
      profile: fixture.profile,
      profileOwnerId: _owner,
      selfLppSnapshot: fixture.snapshot,
      goalAmount: 3000000,
      prospectiveLppReturn: 0.02,
      now: now,
    );
    final confirmed = draft.copyWith(confirmedAt: now);
    final firstMilestone = confirmed.milestones.first;
    final remainingMilestones = confirmed.milestones.skip(1).toList();
    final tampered = <String, FinancialPlan>{
      'monthly target': confirmed.copyWith(
        monthlyTarget: confirmed.monthlyTarget + 1,
      ),
      'projected outcome': confirmed.copyWith(
        projectedOutcome: confirmed.projectedOutcome + 1,
      ),
      'projected low': confirmed.copyWith(
        projectedLow: confirmed.projectedLow! + 1,
      ),
      'projected high': confirmed.copyWith(
        projectedHigh: confirmed.projectedHigh! + 1,
      ),
      'milestone date': confirmed.copyWith(
        milestones: [
          PlanMilestone(
            targetDate: firstMilestone.targetDate.add(const Duration(days: 1)),
            targetAmount: firstMilestone.targetAmount,
            description: firstMilestone.description,
          ),
          ...remainingMilestones,
        ],
      ),
      'milestone amount': confirmed.copyWith(
        milestones: [
          PlanMilestone(
            targetDate: firstMilestone.targetDate,
            targetAmount: firstMilestone.targetAmount + 1,
            description: firstMilestone.description,
          ),
          ...remainingMilestones,
        ],
      ),
      'milestone description': confirmed.copyWith(
        milestones: [
          PlanMilestone(
            targetDate: firstMilestone.targetDate,
            targetAmount: firstMilestone.targetAmount,
            description: '${firstMilestone.description} falsifié',
          ),
          ...remainingMilestones,
        ],
      ),
      'sources': confirmed.copyWith(
        sources: [...confirmed.sources, 'Source inventée'],
      ),
    };

    for (final entry in tampered.entries) {
      final ledger = _Ledger(
        fixture.profile,
        _owner,
        lppSnapshot: fixture.snapshot,
      );
      final provider = FinancialPlanProvider(clock: () => now)
        ..setPlanDirect(entry.value)
        ..attachProfileProvider(ledger);
      try {
        expect(provider.isPlanStale, isTrue, reason: entry.key);
        await expectLater(
          provider.setPlan(entry.value),
          throwsStateError,
          reason: entry.key,
        );
      } finally {
        provider.dispose();
        ledger.dispose();
      }
    }
  });

  test('dispose removes the ledger listener and cancels the authority timer',
      () async {
    final now = DateTime.utc(2026, 7, 16, 9);
    final draft = await PlanGenerationService.generate(
      goalDescription: 'Objectif synthétique',
      goalCategory: 'goal_general',
      targetDate: DateTime.utc(2030, 6, 30),
      profile: _profile(),
      profileOwnerId: _owner,
      selfLppSnapshot: null,
      goalAmount: 120000,
      now: now,
    );
    final timers = <_ManualTimer>[];
    final ledger = _LifecycleLedger(_profile(), _owner);
    final provider = FinancialPlanProvider(
      clock: () => now,
      timerFactory: (duration, callback) {
        final timer = _ManualTimer(duration, callback);
        timers.add(timer);
        return timer;
      },
    )
      ..setPlanDirect(draft.copyWith(confirmedAt: now))
      ..attachProfileProvider(ledger);
    addTearDown(ledger.dispose);

    expect(timers.where((timer) => timer.isActive), hasLength(1));
    provider.dispose();
    expect(ledger.removeListenerCalls, 1);
    expect(timers.where((timer) => timer.isActive), isEmpty);
  });

  test('cold hydration reconciles immediately and repeated load is idempotent',
      () async {
    final now = DateTime.utc(2026, 7, 16, 9);
    final draft = await PlanGenerationService.generate(
      goalDescription: 'Objectif synthétique',
      goalCategory: 'goal_general',
      targetDate: DateTime.utc(2030, 6, 30),
      profile: _profile(),
      profileOwnerId: _owner,
      selfLppSnapshot: null,
      goalAmount: 120000,
      now: now,
    );
    await FinancialPlanService.save(draft.copyWith(confirmedAt: now));
    final ledger = _LifecycleLedger(_profile(), _otherOwner);
    final provider = FinancialPlanProvider(clock: () => now)
      ..attachProfileProvider(ledger);
    addTearDown(ledger.dispose);
    addTearDown(provider.dispose);

    final firstLoad = provider.loadFromPersistence();
    final secondLoad = provider.loadFromPersistence();
    expect(identical(firstLoad, secondLoad), isTrue);
    await firstLoad;
    expect(provider.currentPlan?.id, draft.id);
    expect(provider.isPlanStale, isTrue);
    expect(ledger.addListenerCalls, 1);
  });

  test('a write started with hydration wins without mutating the ledger',
      () async {
    final now = DateTime.utc(2026, 7, 16, 9);
    final oldDraft = await PlanGenerationService.generate(
      goalDescription: 'Ancien',
      goalCategory: 'goal_general',
      targetDate: DateTime.utc(2030, 6, 30),
      profile: _profile(),
      profileOwnerId: _owner,
      selfLppSnapshot: null,
      goalAmount: 90000,
      now: now,
    );
    final newDraft = await PlanGenerationService.generate(
      goalDescription: 'Nouveau',
      goalCategory: 'goal_general',
      targetDate: DateTime.utc(2031, 6, 30),
      profile: _profile(),
      profileOwnerId: _owner,
      selfLppSnapshot: null,
      goalAmount: 120000,
      now: now,
    );
    await FinancialPlanService.save(oldDraft.copyWith(confirmedAt: now));
    final ledger = _LifecycleLedger(_profile(), _owner);
    final ledgerBefore = jsonEncode(ledger.profile.toJson());
    final provider = FinancialPlanProvider(clock: () => now)
      ..attachProfileProvider(ledger);
    addTearDown(ledger.dispose);
    addTearDown(provider.dispose);

    final hydration = provider.loadFromPersistence();
    await provider.setPlan(newDraft.copyWith(confirmedAt: now));
    await hydration;

    expect(provider.currentPlan?.goalDescription, 'Nouveau');
    expect(
        (await FinancialPlanService.loadCurrent())?.goalDescription, 'Nouveau');
    expect(jsonEncode(ledger.profile.toJson()), ledgerBefore);
  });

  testWidgets('one ledger mutation emits one plan notification',
      (tester) async {
    await tester.pumpWidget(const SizedBox());
    final now = DateTime.utc(2026, 7, 16, 9);
    final draft = await PlanGenerationService.generate(
      goalDescription: 'Objectif synthétique',
      goalCategory: 'goal_general',
      targetDate: DateTime.utc(2030, 6, 30),
      profile: _profile(),
      profileOwnerId: _owner,
      selfLppSnapshot: null,
      goalAmount: 120000,
      now: now,
    );
    final ledger = _LifecycleLedger(_profile(), _owner);
    final provider = FinancialPlanProvider(clock: () => now)
      ..setPlanDirect(draft.copyWith(confirmedAt: now))
      ..attachProfileProvider(ledger);
    addTearDown(ledger.dispose);
    addTearDown(provider.dispose);
    var notifications = 0;
    provider.addListener(() => notifications++);

    ledger.replaceOwner(_otherOwner);
    expect(provider.isPlanStale, isTrue);
    tester.binding.scheduleFrame();
    await tester.pumpAndSettle();

    expect(notifications, 1);
    expect(provider.isPlanStale, isTrue);
  });
}
