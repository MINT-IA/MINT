import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/mint_next_domicile_fact.dart';
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
  });

  tearDown(SecureWizardStore.resetSealFallbackForTest);

  MintNextDomicileFact lausanne({bool needsConfirmation = false}) =>
      MintNextDomicileFact(
        canton: 'VD',
        communeName: 'Lausanne',
        communeBfs: 5586,
        assertedAt: DateTime.utc(2026, 8, 11, 7, 30),
        source: MintNextDomicileFact.userDeclarationSource,
        schemaVersion: 1,
        needsConfirmation: needsConfirmation,
      );

  test('confirm persists the domicile bundle atomically through mergeAnswers',
      () async {
    await ReportPersistenceService.saveAnswers({'q_birth_year': 1988});
    final provider = CoachProfileProvider();

    await provider.saveDomicileFact(lausanne());
    expect(provider.domicileFact, lausanne());

    final persisted = await ReportPersistenceService.loadAnswers();
    expect(persisted['q_canton'], 'VD');
    expect(persisted[MintNextDomicileFact.communeNameKey], 'Lausanne');
    expect(persisted[MintNextDomicileFact.communeBfsKey], 5586);
    expect(persisted['q_birth_year'], 1988,
        reason: 'unrelated answers must survive the domicile save');
  });

  test('domicile fact rehydrates from persisted answers after provider reload',
      () async {
    final provider = CoachProfileProvider();
    await provider.saveDomicileFact(lausanne());

    final reloaded = CoachProfileProvider();
    await reloaded.loadFromWizard();
    expect(reloaded.domicileFact, lausanne());
  });

  test(
      'delete removes owned domicile keys and preserves unrelated answers '
      'including legacy q_canton', () async {
    final provider = CoachProfileProvider();
    await provider.mergeAnswers({'q_birth_year': 1988}, syncToBackend: false);
    await provider.saveDomicileFact(lausanne());

    await provider.deleteDomicileFact();

    expect(provider.domicileFact, isNull,
        reason: 'without metadata there is no confirmed domicile fact');
    final persisted = await ReportPersistenceService.loadAnswers();
    expect(persisted['q_canton'], 'VD',
        reason: 'the shared legacy canton belongs to the wider profile');
    expect(persisted.containsKey(MintNextDomicileFact.communeNameKey), isFalse);
    expect(
        persisted.containsKey(MintNextDomicileFact.assertedAtKey), isFalse);
    expect(persisted['q_birth_year'], 1988);
  });

  test('a corrected domicile changes the revision fingerprint', () async {
    final provider = CoachProfileProvider();
    await provider.saveDomicileFact(lausanne());
    final before = provider.domicileFact!.revision;

    await provider.saveDomicileFact(MintNextDomicileFact(
      canton: 'VD',
      communeName: 'Pully',
      assertedAt: DateTime.utc(2026, 8, 11, 8, 0),
      source: MintNextDomicileFact.userDeclarationSource,
      schemaVersion: 1,
      needsConfirmation: false,
    ));

    expect(provider.domicileFact!.communeName, 'Pully');
    expect(provider.domicileFact!.communeBfs, isNull,
        reason: 'the stale BFS of the previous commune must not survive');
    expect(provider.domicileFact!.revision, isNot(before));
  });
}
