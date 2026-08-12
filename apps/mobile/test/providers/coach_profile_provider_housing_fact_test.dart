import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/mint_next_housing_fact.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/services/secure_wizard_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    SecureWizardStore.resetSealFallbackForTest();
    CoachProfileProvider.debugHousingAfterDrain = null;
    CoachProfileProvider.debugHousingAfterCanonicalWrite = null;
    ReportPersistenceService.debugHousingBeforeAction = null;
  });

  tearDown(SecureWizardStore.resetSealFallbackForTest);

  test('save hydrates canonical fact and preserves unrelated answers',
      () async {
    await ReportPersistenceService.saveAnswers({'q_canton': 'VD'});
    final provider = CoachProfileProvider();
    final fact = MintNextHousingFact(
      tenure: PrimaryHomeTenure.ownerOccupier,
      mortgageStatus: HousingMortgageStatus.yes,
      statementAvailability: MortgageStatementAvailability.ready,
      statementYear: 2025,
      annualInterestCents: 101,
      debtBalanceCents: 25000001,
      assertedAt: DateTime.utc(2026, 8, 8),
      source: 'housing_flow',
      schemaVersion: 1,
      needsConfirmation: false,
    );

    await provider.saveHousingFact(fact);
    expect(provider.housingFact, fact);
    expect((await ReportPersistenceService.loadAnswers())['q_canton'], 'VD');

    final reloaded = CoachProfileProvider();
    await reloaded.loadFromWizard();
    expect(reloaded.housingFact, fact);
  });

  test('delete removes whole owned bundle and preserves unrelated keys',
      () async {
    final provider = CoachProfileProvider();
    await provider.mergeAnswers({'q_canton': 'GE'});
    await provider.saveHousingFact(MintNextHousingFact(
      tenure: PrimaryHomeTenure.tenant,
      assertedAt: DateTime.utc(2026, 8, 8),
      source: 'housing_flow',
      schemaVersion: 1,
      needsConfirmation: true,
    ));

    await provider.deleteHousingFact();
    final answers = await ReportPersistenceService.loadAnswers();
    expect(provider.housingFact, isNull);
    expect(answers['q_canton'], 'GE');
    for (final key in MintNextHousingFact.wizardKeys) {
      expect(answers.containsKey(key), isFalse);
      expect(await const FlutterSecureStorage().read(key: key), isNull);
    }
  });

  test('housing save and delete explicitly suppress remote synchronization',
      () async {
    final provider = _SyncPolicySpyProvider();
    final fact = MintNextHousingFact(
      tenure: PrimaryHomeTenure.tenant,
      assertedAt: DateTime.utc(2026, 8, 8),
      source: 'housing_flow',
      schemaVersion: 1,
      needsConfirmation: false,
    );

    await provider.saveHousingFact(fact);
    await provider.deleteHousingFact();
    await provider.mergeAnswers({'q_canton': 'VD'});

    expect(provider.syncPolicies, [true]);
    expect(provider.failurePolicies, [false]);
  });

  test('failed secure delete leaves memory and restart state unchanged',
      () async {
    final provider = CoachProfileProvider();
    final fact = MintNextHousingFact(
      tenure: PrimaryHomeTenure.ownerOccupier,
      mortgageStatus: HousingMortgageStatus.yes,
      assertedAt: DateTime.utc(2026, 8, 8),
      source: 'housing_flow',
      schemaVersion: 1,
      needsConfirmation: false,
    );
    await provider.saveHousingFact(fact);

    SecureWizardStore.debugDeleteKeysOverride = (_) async => false;
    await provider.deleteHousingFact();
    expect(provider.housingFact, isNull);
    expect(
      await const FlutterSecureStorage().read(key: 'q_housing_status'),
      'owner_occupier',
    );
    SecureWizardStore.debugDeleteKeysOverride = null;
    final reloaded = CoachProfileProvider();
    await reloaded.loadFromWizard();
    expect(reloaded.housingFact, isNull);
    expect(
      await const FlutterSecureStorage().read(key: 'q_housing_status'),
      isNull,
    );
  });

  test(
      'partial secure delete with impossible restoration survives a cold reload',
      () async {
    final provider = CoachProfileProvider();
    final fact = MintNextHousingFact(
      tenure: PrimaryHomeTenure.ownerOccupier,
      mortgageStatus: HousingMortgageStatus.yes,
      debtBalanceCents: 34500000,
      assertedAt: DateTime.utc(2026, 8, 8),
      source: 'housing_flow',
      schemaVersion: 1,
      needsConfirmation: false,
    );
    await provider.saveHousingFact(fact);

    // Hostile storage: one original disappears and the operation then fails.
    // No restoration write is permitted/needed: recovery must come from the
    // durable encrypted transaction backup after constructing a new provider.
    SecureWizardStore.debugDeleteKeysOverride = (keys) async {
      await const FlutterSecureStorage().delete(key: 'q_housing_status');
      return false;
    };
    await provider.deleteHousingFact();
    SecureWizardStore.debugDeleteKeysOverride = null;

    final reloaded = CoachProfileProvider();
    await reloaded.loadFromWizard();
    expect(reloaded.housingFact, isNull);
    expect(
      await const FlutterSecureStorage().read(key: 'q_housing_status'),
      isNull,
    );
  });

  test('journal commit failure surfaces and preserves fact across restart',
      () async {
    final provider = CoachProfileProvider();
    final fact = MintNextHousingFact(
      tenure: PrimaryHomeTenure.tenant,
      assertedAt: DateTime.utc(2026, 8, 8),
      source: 'housing_flow',
      schemaVersion: 1,
      needsConfirmation: false,
    );
    await provider.saveHousingFact(fact);
    SecureWizardStore.debugCommitDeleteOverride = () async => false;

    await provider.deleteHousingFact();
    expect(provider.housingFact, isNull);
    SecureWizardStore.debugCommitDeleteOverride = null;

    final reloaded = CoachProfileProvider();
    await reloaded.loadFromWizard();
    expect(reloaded.housingFact, isNull);
  });

  test('post-commit finalize failure remains deleted after cold reload',
      () async {
    final provider = CoachProfileProvider();
    await provider.saveHousingFact(MintNextHousingFact(
      tenure: PrimaryHomeTenure.tenant,
      assertedAt: DateTime.utc(2026, 8, 8),
      source: 'housing_flow',
      schemaVersion: 1,
      needsConfirmation: false,
    ));
    await provider.deleteHousingFact();
    expect(provider.housingFact, isNull);

    final reloaded = CoachProfileProvider();
    await reloaded.loadFromWizard();
    expect(reloaded.housingFact, isNull);
  });

  test('explicit complete housing save supersedes committed tombstone',
      () async {
    final provider = CoachProfileProvider();
    final first = MintNextHousingFact(
      tenure: PrimaryHomeTenure.tenant,
      assertedAt: DateTime.utc(2026, 8, 8),
      source: 'housing_flow',
      schemaVersion: 1,
      needsConfirmation: false,
    );
    await provider.saveHousingFact(first);
    await provider.deleteHousingFact();

    final replacement = MintNextHousingFact(
      tenure: PrimaryHomeTenure.ownerOccupier,
      assertedAt: DateTime.utc(2026, 8, 9),
      source: 'housing_flow',
      schemaVersion: 1,
      needsConfirmation: false,
    );
    await provider.saveHousingFact(replacement);

    final reloaded = CoachProfileProvider();
    await reloaded.loadFromWizard();
    expect(reloaded.housingFact, replacement);
  });

  test('pending old purge drains before delete and cache save keeps tombstone',
      () async {
    await (await SharedPreferences.getInstance())
        .setBool('secure_delete_pending_v1', true);
    final provider = CoachProfileProvider();

    await provider.deleteHousingFact();
    await ReportPersistenceService.saveAnswers({'q_canton': 'VD'});

    expect((await SecureWizardStore.readCanonicalHousing()).status,
        CanonicalHousingStatus.deleted);
    expect(provider.housingFact, isNull);
  });

  test('reset requested after canonical save wins without false publish',
      () async {
    final provider = CoachProfileProvider();
    Future<void>? reset;
    CoachProfileProvider.debugHousingAfterCanonicalWrite = () async {
      reset = ReportPersistenceService.clearDiagnostic();
    };
    final fact = MintNextHousingFact(
      tenure: PrimaryHomeTenure.tenant,
      assertedAt: DateTime.utc(2026, 8, 8),
      source: 'housing_flow',
      schemaVersion: 1,
      needsConfirmation: false,
    );

    await expectLater(provider.saveHousingFact(fact), throwsStateError);
    await reset;
    expect(provider.housingFact, isNull);
    expect((await SecureWizardStore.readCanonicalHousing()).status,
        CanonicalHousingStatus.missing);
  });

  test('reset requested before transaction action prevents snapshot replay',
      () async {
    await ReportPersistenceService.saveAnswers({
      'q_canton': 'VD',
      'q_net_income_period_chf': 7000,
    });
    final provider = CoachProfileProvider();
    Future<void>? reset;
    ReportPersistenceService.debugHousingBeforeAction = () async {
      reset = ReportPersistenceService.clearDiagnostic();
    };
    final fact = MintNextHousingFact(
      tenure: PrimaryHomeTenure.tenant,
      assertedAt: DateTime.utc(2026, 8, 8),
      source: 'housing_flow',
      schemaVersion: 1,
      needsConfirmation: false,
    );

    await expectLater(provider.saveHousingFact(fact), throwsStateError);
    await reset;
    expect(await ReportPersistenceService.loadAnswers(), isEmpty);
    expect(provider.housingFact, isNull);
  });

  test('failing pre-action hook releases the housing transaction tail',
      () async {
    ReportPersistenceService.debugHousingBeforeAction =
        () async => throw StateError('injected hook failure');

    await expectLater(
      ReportPersistenceService.runHousingTransaction(() async {}),
      throwsA(isA<StateError>()),
    );

    ReportPersistenceService.debugHousingBeforeAction = null;
    await expectLater(
      ReportPersistenceService.runHousingTransaction(() async => 'released'),
      completion('released'),
    );
  });

  test('marker failure after canonical write remains cold-load authoritative',
      () async {
    final provider = CoachProfileProvider();
    final fact = MintNextHousingFact(
      tenure: PrimaryHomeTenure.ownerOccupier,
      assertedAt: DateTime.utc(2026, 8, 8),
      source: 'housing_flow',
      schemaVersion: 1,
      needsConfirmation: false,
    );
    SecureWizardStore.debugCanonicalMarkerWriteOverride = () async {
      throw StateError('marker unavailable');
    };

    await provider.saveHousingFact(fact);
    SecureWizardStore.debugCanonicalMarkerWriteOverride = null;
    final reloaded = CoachProfileProvider();
    await reloaded.loadFromWizard();
    expect(reloaded.housingFact, fact);
  });

  test('reset requested after canonical delete wins without false publish',
      () async {
    final provider = CoachProfileProvider();
    final fact = MintNextHousingFact(
      tenure: PrimaryHomeTenure.tenant,
      assertedAt: DateTime.utc(2026, 8, 8),
      source: 'housing_flow',
      schemaVersion: 1,
      needsConfirmation: false,
    );
    await provider.saveHousingFact(fact);
    Future<void>? reset;
    CoachProfileProvider.debugHousingAfterCanonicalWrite = () async {
      reset = ReportPersistenceService.clearDiagnostic();
    };

    await expectLater(provider.deleteHousingFact(), throwsStateError);
    await reset;
    expect(provider.housingFact, isNull);
    expect((await SecureWizardStore.readCanonicalHousing()).status,
        CanonicalHousingStatus.missing);
  });
}

class _SyncPolicySpyProvider extends CoachProfileProvider {
  final syncPolicies = <bool>[];
  final failurePolicies = <bool>[];

  @override
  Future<void> mergeAnswers(
    Map<String, dynamic> partial, {
    bool syncToBackend = true,
    bool failOnPersistenceError = false,
  }) async {
    syncPolicies.add(syncToBackend);
    failurePolicies.add(failOnPersistenceError);
  }
}
