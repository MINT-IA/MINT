import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/mint_next_lpp_affiliation_fact.dart';
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
    SecureWizardStore.debugCanonicalLppAffiliationWriteOverride = null;
  });

  MintNextLppAffiliationFact affiliated({DateTime? at, bool value = true}) =>
      MintNextLppAffiliationFact(
        affiliated: value,
        assertedAt: at ?? DateTime.utc(2026, 8, 11, 14),
        source: MintNextLppAffiliationFact.userDeclarationSource,
        schemaVersion: 1,
        needsConfirmation: false,
      );

  test('confirm persists the sealed bundle atomically', () async {
    await ReportPersistenceService.saveAnswers({'q_birth_year': 1988});
    final provider = CoachProfileProvider();

    await provider.saveLppAffiliationFact(affiliated());
    expect(provider.lppAffiliationFact, affiliated());

    final canonical = await SecureWizardStore.readCanonicalLppAffiliation();
    expect(canonical.status, CanonicalHousingStatus.present);
    expect(canonical.fact, affiliated());
    final persisted = await ReportPersistenceService.loadAnswers();
    expect(persisted['q_lpp_affiliation_fact_value'], isTrue);
    expect(persisted['q_birth_year'], 1988);
  });

  test('lpp affiliation fact rehydrates from sealed storage after reload',
      () async {
    final provider = CoachProfileProvider();
    await provider.saveLppAffiliationFact(affiliated(value: false));

    final reloaded = CoachProfileProvider();
    await reloaded.loadFromWizard();
    expect(reloaded.lppAffiliationFact, affiliated(value: false));
    expect(
        MintNextLppAffiliationFact.statusOf(reloaded.lppAffiliationFact),
        MintNextLppAffiliationStatus.confirmedNo,
        reason: 'a confirmed no is a real answer — distinct from unknown');
  });

  test('delete tombstones the fact and the reading returns to unknown '
      'never to confirmed_no', () async {
    final provider = CoachProfileProvider();
    await provider.mergeAnswers({'q_birth_year': 1988}, syncToBackend: false);
    await provider.saveLppAffiliationFact(affiliated());

    await provider.deleteLppAffiliationFact();

    expect(provider.lppAffiliationFact, isNull);
    expect(MintNextLppAffiliationFact.statusOf(provider.lppAffiliationFact),
        MintNextLppAffiliationStatus.unknown,
        reason: 'deletion returns the affiliation to unknown, never no');
    final canonical = await SecureWizardStore.readCanonicalLppAffiliation();
    expect(canonical.status, CanonicalHousingStatus.deleted);
    final persisted = await ReportPersistenceService.loadAnswers();
    expect(persisted.containsKey('q_lpp_affiliation_fact_value'), isFalse);
    expect(persisted['q_birth_year'], 1988);

    final reloaded = CoachProfileProvider();
    await reloaded.loadFromWizard();
    expect(reloaded.lppAffiliationFact, isNull,
        reason: 'the tombstone survives a cold reload');
  });

  test('a failed canonical write leaves no half-written fact', () async {
    final provider = CoachProfileProvider();
    await provider.mergeAnswers({'q_birth_year': 1988}, syncToBackend: false);

    SecureWizardStore.debugCanonicalLppAffiliationWriteOverride =
        () async => false;
    addTearDown(() =>
        SecureWizardStore.debugCanonicalLppAffiliationWriteOverride = null);

    await expectLater(
      provider.saveLppAffiliationFact(affiliated()),
      throwsA(isA<StateError>()),
    );

    SecureWizardStore.debugCanonicalLppAffiliationWriteOverride = null;
    final persisted = await ReportPersistenceService.loadAnswers();
    expect(persisted.containsKey('q_lpp_affiliation_fact_value'), isFalse,
        reason: 'no cache write may precede a failed canonical commit');
    expect(persisted['q_birth_year'], 1988);
  });

  test('a corrected affiliation changes the revision', () async {
    final provider = CoachProfileProvider();
    await provider.saveLppAffiliationFact(affiliated());
    final before = provider.lppAffiliationFact!.revision;

    await provider.saveLppAffiliationFact(
        affiliated(at: DateTime.utc(2026, 8, 11, 15), value: false));

    expect(provider.lppAffiliationFact!.affiliated, isFalse);
    expect(provider.lppAffiliationFact!.revision, isNot(before));
  });
}
