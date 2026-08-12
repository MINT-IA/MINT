import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/mint_next_civil_status_fact.dart';
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

  tearDown(SecureWizardStore.resetSealFallbackForTest);

  MintNextCivilStatusFact marie({DateTime? at}) => MintNextCivilStatusFact(
        status: MintNextCivilStatus.marie,
        assertedAt: at ?? DateTime.utc(2026, 8, 11, 10),
        source: MintNextCivilStatusFact.userDeclarationSource,
        schemaVersion: 1,
        needsConfirmation: false,
      );

  test('confirm persists the sealed bundle atomically', () async {
    await ReportPersistenceService.saveAnswers({'q_birth_year': 1988});
    final provider = CoachProfileProvider();

    await provider.saveCivilStatusFact(marie());
    expect(provider.civilStatusFact, marie());

    final canonical = await SecureWizardStore.readCanonicalCivilStatus();
    expect(canonical.status, CanonicalHousingStatus.present,
        reason: 'the sealed canonical record is the sole authority');
    expect(canonical.fact, marie());
    final persisted = await ReportPersistenceService.loadAnswers();
    expect(persisted['q_civil_status'], 'marie');
    expect(persisted['q_birth_year'], 1988);
  });

  test('civil status fact rehydrates from sealed storage after reload',
      () async {
    final provider = CoachProfileProvider();
    await provider.saveCivilStatusFact(marie());

    final reloaded = CoachProfileProvider();
    await reloaded.loadFromWizard();
    expect(reloaded.civilStatusFact, marie());
  });

  test('delete tombstones the fact and preserves unrelated answers', () async {
    final provider = CoachProfileProvider();
    await provider.mergeAnswers({'q_birth_year': 1988}, syncToBackend: false);
    await provider.saveCivilStatusFact(marie());

    await provider.deleteCivilStatusFact();

    expect(provider.civilStatusFact, isNull);
    final canonical = await SecureWizardStore.readCanonicalCivilStatus();
    expect(canonical.status, CanonicalHousingStatus.deleted,
        reason: 'deletion is a value-free tombstone, not an absence');
    final persisted = await ReportPersistenceService.loadAnswers();
    expect(persisted.containsKey('q_civil_status'), isFalse);
    expect(persisted['q_birth_year'], 1988);

    final reloaded = CoachProfileProvider();
    await reloaded.loadFromWizard();
    expect(reloaded.civilStatusFact, isNull,
        reason: 'the tombstone survives a cold reload');
  });

  test('a failed canonical write leaves no half-written fact', () async {
    final provider = CoachProfileProvider();
    await provider.mergeAnswers({'q_birth_year': 1988}, syncToBackend: false);

    SecureWizardStore.debugCanonicalCivilStatusWriteOverride =
        () async => false;
    addTearDown(() =>
        SecureWizardStore.debugCanonicalCivilStatusWriteOverride = null);

    await expectLater(
      provider.saveCivilStatusFact(marie()),
      throwsA(isA<StateError>()),
    );

    SecureWizardStore.debugCanonicalCivilStatusWriteOverride = null;
    final persisted = await ReportPersistenceService.loadAnswers();
    expect(persisted.containsKey('q_civil_status'), isFalse,
        reason: 'no cache write may precede a failed canonical commit');
    expect(persisted.containsKey(MintNextCivilStatusFact.assertedAtKey),
        isFalse);
    expect(persisted['q_birth_year'], 1988,
        reason: 'unrelated answers untouched by the aborted transaction');
  });

  test('the tombstone dominates a lingering legacy alias', () async {
    final provider = CoachProfileProvider();
    await provider.mergeAnswers(
      {'q_civil_status_choice': 'married', 'q_birth_year': 1988},
      syncToBackend: false,
    );
    await provider.saveCivilStatusFact(marie());

    await provider.deleteCivilStatusFact();

    final persisted = await ReportPersistenceService.loadAnswers();
    expect(persisted.containsKey('q_civil_status'), isFalse);
    expect(persisted.containsKey('q_civil_status_choice'), isFalse,
        reason: 'without purging the alias, CoachProfile resurrects the old '
            'status through the q_civil_status_choice fallback');
    expect(persisted['q_birth_year'], 1988);

    final reloaded = CoachProfileProvider();
    await reloaded.loadFromWizard();
    expect(reloaded.civilStatusFact, isNull);
    expect(reloaded.profile?.etatCivil, isNot(CoachCivilStatus.marie),
        reason: 'the deleted fact never comes back through the legacy alias');
  });

  test('a bare merged q_civil_status never outlives the canonical fact',
      () async {
    final provider = CoachProfileProvider();
    await provider.saveCivilStatusFact(marie());

    await provider.mergeAnswers(
      {'q_civil_status': 'divorce'},
      syncToBackend: false,
    );

    final reloaded = CoachProfileProvider();
    await reloaded.loadFromWizard();
    expect(reloaded.civilStatusFact, marie(),
        reason: 'the sealed canonical record is the sole authority — a bare '
            'write through the plain merge path is overwritten on reload, '
            'which is why every writer must use saveCivilStatusFact');
  });

  test('a corrected status changes the revision', () async {
    final provider = CoachProfileProvider();
    await provider.saveCivilStatusFact(marie());
    final before = provider.civilStatusFact!.revision;

    await provider.saveCivilStatusFact(MintNextCivilStatusFact(
      status: MintNextCivilStatus.divorce,
      assertedAt: DateTime.utc(2026, 8, 11, 11),
      source: MintNextCivilStatusFact.userDeclarationSource,
      schemaVersion: 1,
      needsConfirmation: false,
    ));

    expect(provider.civilStatusFact!.status, MintNextCivilStatus.divorce);
    expect(provider.civilStatusFact!.revision, isNot(before));
  });
}
