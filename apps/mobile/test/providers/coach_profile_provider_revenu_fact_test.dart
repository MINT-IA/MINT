import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/mint_next_revenu_fact.dart';
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
    SecureWizardStore.debugCanonicalRevenuWriteOverride = null;
  });

  MintNextRevenuFact monthly({DateTime? at, int amountCents = 650000}) =>
      MintNextRevenuFact(
        amountCents: amountCents,
        period: MintNextRevenuPeriod.monthly,
        assertedAt: at ?? DateTime.utc(2026, 8, 11, 12),
        source: MintNextRevenuFact.userDeclarationSource,
        schemaVersion: 1,
        needsConfirmation: false,
      );

  test('confirm persists the sealed bundle atomically with legacy projection',
      () async {
    await ReportPersistenceService.saveAnswers({'q_birth_year': 1988});
    final provider = CoachProfileProvider();

    await provider.saveRevenuFact(monthly());
    expect(provider.revenuFact, monthly());

    final canonical = await SecureWizardStore.readCanonicalRevenu();
    expect(canonical.status, CanonicalHousingStatus.present,
        reason: 'the sealed canonical record is the sole authority');
    expect(canonical.fact, monthly());
    final persisted = await ReportPersistenceService.loadAnswers();
    expect(persisted['q_revenu_fact_amount_cents'], 650000);
    expect(persisted['q_net_income_period_chf'], 6500.0,
        reason: 'the legacy projection ships in the same commit');
    expect(persisted['q_pay_frequency'], 'monthly');
    expect(persisted['q_birth_year'], 1988);
  });

  test('revenu fact rehydrates from sealed storage after reload', () async {
    final provider = CoachProfileProvider();
    await provider.saveRevenuFact(monthly());

    final reloaded = CoachProfileProvider();
    await reloaded.loadFromWizard();
    expect(reloaded.revenuFact, monthly());
  });

  test('a bare legacy write never outlives the canonical fact', () async {
    final provider = CoachProfileProvider();
    await provider.saveRevenuFact(monthly());

    await provider.mergeAnswers(
      {'q_net_income_period_chf': 9999.0, 'q_pay_frequency': 'yearly'},
      syncToBackend: false,
    );

    final reloaded = CoachProfileProvider();
    await reloaded.loadFromWizard();
    expect(reloaded.revenuFact, monthly(),
        reason: 'the canonical record is untouched by legacy writers');
    final persisted = await ReportPersistenceService.loadAnswers();
    expect(persisted['q_net_income_period_chf'], 6500.0,
        reason: 'the projection dominates a bare legacy write on reload — '
            'a divergence never silently replaces a confirmed fact');
    expect(persisted['q_pay_frequency'], 'monthly');
  });

  test('delete tombstones the bundle AND the projection, preserves the rest',
      () async {
    final provider = CoachProfileProvider();
    await provider.mergeAnswers({'q_birth_year': 1988}, syncToBackend: false);
    await provider.saveRevenuFact(monthly());

    await provider.deleteRevenuFact();

    expect(provider.revenuFact, isNull);
    final canonical = await SecureWizardStore.readCanonicalRevenu();
    expect(canonical.status, CanonicalHousingStatus.deleted,
        reason: 'deletion is a value-free tombstone, not an absence');
    final persisted = await ReportPersistenceService.loadAnswers();
    expect(persisted.containsKey('q_revenu_fact_amount_cents'), isFalse);
    expect(persisted.containsKey('q_net_income_period_chf'), isFalse,
        reason: 'legacy consumers must not keep showing a deleted income');
    expect(persisted['q_birth_year'], 1988);

    final reloaded = CoachProfileProvider();
    await reloaded.loadFromWizard();
    expect(reloaded.revenuFact, isNull,
        reason: 'the tombstone survives a cold reload');
  });

  test('after deletion a legacy writer may live on without resurrecting '
      'the fact', () async {
    final provider = CoachProfileProvider();
    await provider.saveRevenuFact(monthly());
    await provider.deleteRevenuFact();

    await provider.mergeAnswers(
      {'q_net_income_period_chf': 4200.0, 'q_pay_frequency': 'monthly'},
      syncToBackend: false,
    );

    final reloaded = CoachProfileProvider();
    await reloaded.loadFromWizard();
    expect(reloaded.revenuFact, isNull,
        reason: 'shared legacy keys can never resurrect the owned fact');
    final persisted = await ReportPersistenceService.loadAnswers();
    expect(persisted['q_net_income_period_chf'], 4200.0,
        reason: 'the deleted branch purges owned keys only — legacy writers '
            'keep working after the fact is gone');
  });

  test('a failed canonical write leaves no half-written fact', () async {
    final provider = CoachProfileProvider();
    await provider.mergeAnswers({'q_birth_year': 1988}, syncToBackend: false);

    SecureWizardStore.debugCanonicalRevenuWriteOverride = () async => false;
    addTearDown(
        () => SecureWizardStore.debugCanonicalRevenuWriteOverride = null);

    await expectLater(
      provider.saveRevenuFact(monthly()),
      throwsA(isA<StateError>()),
    );

    SecureWizardStore.debugCanonicalRevenuWriteOverride = null;
    final persisted = await ReportPersistenceService.loadAnswers();
    expect(persisted.containsKey('q_revenu_fact_amount_cents'), isFalse,
        reason: 'no cache write may precede a failed canonical commit');
    expect(persisted.containsKey('q_net_income_period_chf'), isFalse,
        reason: 'no projection either');
    expect(persisted['q_birth_year'], 1988);
  });

  test(
      'switching period monthly to yearly and back never applies the factor '
      'twelve twice', () async {
    final provider = CoachProfileProvider();
    await provider.saveRevenuFact(monthly());
    expect(provider.revenuFact!.annualizedCents, 650000 * 12);

    await provider.saveRevenuFact(MintNextRevenuFact(
      amountCents: 7800000,
      period: MintNextRevenuPeriod.yearly,
      assertedAt: DateTime.utc(2026, 8, 11, 13),
      source: MintNextRevenuFact.userDeclarationSource,
      schemaVersion: 1,
      needsConfirmation: false,
    ));
    expect(provider.revenuFact!.amountCents, 7800000,
        reason: 'the stored amount is always the declared per-period amount');
    expect(provider.revenuFact!.annualizedCents, 7800000);

    await provider.saveRevenuFact(monthly(at: DateTime.utc(2026, 8, 11, 14)));
    final reloaded = CoachProfileProvider();
    await reloaded.loadFromWizard();
    expect(reloaded.revenuFact!.amountCents, 650000,
        reason: 'round-tripping periods never bakes the annualization in');
    expect(reloaded.revenuFact!.annualizedCents, 650000 * 12);
  });

  test('a corrected revenu changes the revision', () async {
    final provider = CoachProfileProvider();
    await provider.saveRevenuFact(monthly());
    final before = provider.revenuFact!.revision;

    await provider.saveRevenuFact(
        monthly(at: DateTime.utc(2026, 8, 11, 15), amountCents: 700000));

    expect(provider.revenuFact!.amountCents, 700000);
    expect(provider.revenuFact!.revision, isNot(before));
  });
}
