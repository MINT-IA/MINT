import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile_owner.dart';
import 'package:mint_mobile/models/financial_plan.dart';
import 'package:mint_mobile/services/financial_plan_service.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

const _legacyPlanKey = 'financial_plan_v1';
const _activePlanSlotKey = 'financial_plan_active_slot_v1';
const _owner = '11111111-1111-4111-8111-111111111111';

final class _ControllablePreferencesStore
    extends InMemorySharedPreferencesStore {
  _ControllablePreferencesStore([Map<String, Object> data = const {}])
      : super.withData({
          for (final entry in data.entries)
            entry.key.startsWith('flutter.')
                ? entry.key
                : 'flutter.${entry.key}': entry.value,
        });

  final failSetKeys = <String>{};
  final failRemoveKeys = <String>{};
  bool mutateBeforeFalse = true;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (!failSetKeys.contains(key)) {
      return super.setValue(valueType, key, value);
    }
    if (mutateBeforeFalse) {
      await super.setValue(valueType, key, value);
    }
    return false;
  }

  @override
  Future<bool> remove(String key) async {
    if (!failRemoveKeys.contains(key)) return super.remove(key);
    if (mutateBeforeFalse) await super.remove(key);
    return false;
  }
}

void _installPreferencesStore(_ControllablePreferencesStore store) {
  SharedPreferences.resetStatic();
  SharedPreferencesStorePlatform.instance = store;
}

FinancialPlan _sensitivePlan(String id) => FinancialPlan(
      id: id,
      goalDescription: 'Plan synthétique',
      goalCategory: 'goal_retirement_plan',
      monthlyTarget: 1250,
      milestones: [
        PlanMilestone(
          targetDate: DateTime.utc(2030, 1, 1),
          targetAmount: 15000,
          description: '25%',
        ),
      ],
      projectedOutcome: 250000,
      projectedLow: 225000,
      projectedHigh: 275000,
      targetDate: DateTime.utc(2051, 1, 1),
      generatedAt: DateTime.utc(2026, 7, 16, 9),
      profileHashAtGeneration: 'mint-plan-dependency:v3:sha256:${'1' * 64}',
      coachNarrative: 'mint-plan-narrative:v2:goal_retirement_plan',
      confidenceLevel: 80,
      sources: const ['LPP art. 8'],
      disclaimer: 'Outil éducatif.',
      goalAmount: 300000,
      scenarioId: '22222222-2222-4222-8222-222222222222',
      confirmedAt: DateTime.utc(2026, 7, 16, 9),
      inputAsOf: DateTime.utc(2026, 7, 16, 9),
      profileOwnerId: _owner,
      dependencySchemaVersion: 3,
      dependencyBranch: 'retirementLpp',
      dependencyBasis: 'total/legalSchedule',
      dependencyHash: 'mint-plan-dependency:v3:sha256:${'1' * 64}',
      validUntil: DateTime.utc(2027, 1, 1),
      projectionAssumptions: FinancialPlanProjectionAssumptions(
        caisseReturnBase: 0.02,
        caisseReturnLow: 0.01,
        caisseReturnHigh: 0.03,
        supplementalMonthlySavingsReturn: 0,
        salaryBasis: const FinancialPlanSalaryBasis(
          kind: 'monthlySalaryTimesTwelve',
          annualChf: 96000,
        ),
        bonificationBasis: const FinancialPlanBonificationBasis(
          kind: 'legalAgeSchedule',
        ),
        projectionAsOf: DateTime.utc(2026, 7, 16, 9),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  tearDown(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  test('wizard publication throws when SharedPreferences returns false',
      () async {
    final store = _ControllablePreferencesStore()
      ..failSetKeys.add('flutter.wizard_answers_v2');
    _installPreferencesStore(store);

    await expectLater(
      ReportPersistenceService.saveAnswers(<String, dynamic>{
        'q_birth_year': 1986,
        coachProfileOwnerRootKey:
            const CoachProfileOwnerRoot(_owner).toJsonString(),
      }),
      throwsStateError,
    );
  });

  test('plan save throws on a false durable write and publishes no pointer',
      () async {
    final store = _ControllablePreferencesStore()
      ..failSetKeys.addAll({
        'flutter.$_legacyPlanKey',
        'flutter.$_activePlanSlotKey',
      });
    _installPreferencesStore(store);

    await expectLater(
      FinancialPlanService.save(_sensitivePlan('candidate')),
      throwsStateError,
    );
    final persisted = await store.getAll();
    expect(persisted, isNot(contains('flutter.$_activePlanSlotKey')));
  });

  test('successful plan save leaves only an opaque validated pointer in prefs',
      () async {
    final store = _ControllablePreferencesStore();
    _installPreferencesStore(store);

    await FinancialPlanService.save(_sensitivePlan('private'));

    final prefs = await SharedPreferences.getInstance();
    final slotId = prefs.getString(_activePlanSlotKey);
    expect(slotId, matches(RegExp(r'^[a-f0-9]{32}$')));
    expect(prefs.containsKey(_legacyPlanKey), isFalse);
    final persisted = await store.getAll();
    final prefsText = jsonEncode(persisted);
    expect(prefsText, isNot(contains(_owner)));
    expect(prefsText, isNot(contains('96000')));
    expect(prefsText, isNot(contains('Plan synthétique')));
    expect((await FinancialPlanService.loadCurrent())?.id, 'private');
  });

  test('valid legacy plaintext migrates atomically then disappears', () async {
    final legacyBytes = jsonEncode([_sensitivePlan('legacy').toJson()]);
    final store = _ControllablePreferencesStore({_legacyPlanKey: legacyBytes});
    _installPreferencesStore(store);

    final plans = await FinancialPlanService.loadAll();

    expect(plans.single.id, 'legacy');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(_legacyPlanKey), isFalse);
    expect(
      prefs.getString(_activePlanSlotKey),
      matches(RegExp(r'^[a-f0-9]{32}$')),
    );
  });

  test('legacy migration fails closed when pointer publication returns false',
      () async {
    final legacyBytes = jsonEncode([_sensitivePlan('legacy').toJson()]);
    final store = _ControllablePreferencesStore({_legacyPlanKey: legacyBytes})
      ..failSetKeys.add('flutter.$_activePlanSlotKey');
    _installPreferencesStore(store);

    await expectLater(FinancialPlanService.loadAll(), throwsStateError);

    SharedPreferences.resetStatic();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_legacyPlanKey), legacyBytes);
    expect(prefs.containsKey(_activePlanSlotKey), isFalse);
  });
}
