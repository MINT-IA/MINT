import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/mint_next_versements_3a_fact.dart';
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
    ReportPersistenceService.debugResetTransactionQueueForTest();
    SecureWizardStore.debugResetCanonicalQueueForTest();
  });

  tearDown(() {
    SecureWizardStore.resetSealFallbackForTest();
    SecureWizardStore.debugCanonicalVersements3aWriteOverride = null;
  });

  final t0 = DateTime.utc(2026, 8, 11, 20);
  final t1 = DateTime.utc(2026, 8, 11, 21);

  MintNextVersement3aEntry entry({
    String id = 'v1',
    int amountCents = 200000,
    int taxYear = 2026,
  }) =>
      MintNextVersement3aEntry(
        id: id,
        amountCents: amountCents,
        creditedAt: DateTime.utc(2026, 3, 15),
        taxYear: taxYear,
      );

  test('adding an entry commits the whole list atomically', () async {
    await ReportPersistenceService.saveAnswers({'q_birth_year': 1988});
    final provider = CoachProfileProvider();

    final fact =
        MintNextVersements3aFact.empty(at: t0).withEntryAdded(entry(), t0);
    await provider.saveVersements3aFact(fact);

    expect(provider.versements3aFact!.entries.length, 1);
    expect(provider.versements3aFact!.totalForYearCents(2026), 200000);
    final canonical = await SecureWizardStore.readCanonicalVersements3a();
    expect(canonical.status, CanonicalHousingStatus.present);
    final persisted = await ReportPersistenceService.loadAnswers();
    expect(persisted['q_birth_year'], 1988);
  });

  test('the list rehydrates from sealed storage after reload', () async {
    final provider = CoachProfileProvider();
    final fact = MintNextVersements3aFact.empty(at: t0)
        .withEntryAdded(entry(), t0)
        .withEntryAdded(entry(id: 'v2', taxYear: 2025), t1);
    await provider.saveVersements3aFact(fact);

    final reloaded = CoachProfileProvider();
    await reloaded.loadFromWizard();
    expect(reloaded.versements3aFact!.entries.length, 2);
    expect(reloaded.versements3aFact!.totalForYearCents(2025), 200000);
    expect(reloaded.versements3aFact!.bucketRevision(2025),
        t1.toIso8601String());
  });

  test('correcting one entry through the sealed commit keeps the others and '
      'bumps only its bucket', () async {
    final provider = CoachProfileProvider();
    final fact = MintNextVersements3aFact.empty(at: t0)
        .withEntryAdded(entry(), t0)
        .withEntryAdded(entry(id: 'v2', taxYear: 2025), t0);
    await provider.saveVersements3aFact(fact);

    final corrected = provider.versements3aFact!
        .withEntryUpdated('v1', entry(amountCents: 300000), t1);
    await provider.saveVersements3aFact(corrected);

    final reloaded = CoachProfileProvider();
    await reloaded.loadFromWizard();
    expect(reloaded.versements3aFact!.entryById('v1')!.amountCents, 300000);
    expect(reloaded.versements3aFact!.entryById('v2'), isNotNull);
    expect(reloaded.versements3aFact!.bucketRevision(2026),
        t1.toIso8601String());
    expect(reloaded.versements3aFact!.bucketRevision(2025),
        t0.toIso8601String(),
        reason: 'a 2026 correction never stales the 2025 bucket');
  });

  test('delete tombstones the whole list and preserves unrelated answers',
      () async {
    final provider = CoachProfileProvider();
    await provider.mergeAnswers({'q_birth_year': 1988}, syncToBackend: false);
    await provider.saveVersements3aFact(
        MintNextVersements3aFact.empty(at: t0).withEntryAdded(entry(), t0));

    await provider.deleteVersements3aFact();

    expect(provider.versements3aFact, isNull);
    final canonical = await SecureWizardStore.readCanonicalVersements3a();
    expect(canonical.status, CanonicalHousingStatus.deleted);
    final persisted = await ReportPersistenceService.loadAnswers();
    expect(persisted.containsKey('q_versements_3a_fact_entries'), isFalse);
    expect(persisted['q_birth_year'], 1988);
  });

  test('a failed canonical write leaves no half-written list', () async {
    final provider = CoachProfileProvider();
    await provider.mergeAnswers({'q_birth_year': 1988}, syncToBackend: false);

    SecureWizardStore.debugCanonicalVersements3aWriteOverride =
        () async => false;
    addTearDown(() =>
        SecureWizardStore.debugCanonicalVersements3aWriteOverride = null);

    await expectLater(
      provider.saveVersements3aFact(
          MintNextVersements3aFact.empty(at: t0).withEntryAdded(entry(), t0)),
      throwsA(isA<StateError>()),
    );

    SecureWizardStore.debugCanonicalVersements3aWriteOverride = null;
    final persisted = await ReportPersistenceService.loadAnswers();
    expect(persisted.containsKey('q_versements_3a_fact_entries'), isFalse);
    expect(persisted['q_birth_year'], 1988);
  });

  test('a corrupt canonical record masks the cached list', () async {
    final provider = CoachProfileProvider();
    await provider.saveVersements3aFact(
        MintNextVersements3aFact.empty(at: t0).withEntryAdded(entry(), t0));

    await const FlutterSecureStorage().write(
        key: '_mint_canonical_versements_3a_v1', value: '{"state":"???"}');

    final reloaded = CoachProfileProvider();
    await reloaded.loadFromWizard();
    expect(reloaded.versements3aFact, isNull,
        reason: 'a corrupt canonical never resurrects a stale list');
  });
}
