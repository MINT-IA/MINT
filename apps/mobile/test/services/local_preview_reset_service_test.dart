import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/models/mint_next_lpp_affiliation_fact.dart';
import 'package:mint_mobile/services/local_preview_reset_service.dart';
import 'package:mint_mobile/services/preview_shell_policy.dart';
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
    PreviewShellPolicy.debugOverride =
        const PreviewShellPolicy.forTest(isPreviewShell: true);
  });

  tearDown(() {
    PreviewShellPolicy.debugOverride = null;
    SecureWizardStore.resetSealFallbackForTest();
  });

  Future<void> seedFacts() async {
    final provider = CoachProfileProvider();
    await provider.mergeAnswers({'q_birth_year': 1988}, syncToBackend: false);
    await provider.saveLppAffiliationFact(MintNextLppAffiliationFact(
      affiliated: true,
      assertedAt: DateTime.utc(2026, 8, 12),
      source: 'user_declaration',
      schemaVersion: 1,
      needsConfirmation: false,
    ));
    const storage = FlutterSecureStorage();
    await storage.write(key: 'anonymous_session_id', value: 'anon-1');
    await storage.write(key: 'anonymous_message_count', value: '3');
  }

  test('the reset service exposes constant purged and preserved inventories',
      () {
    expect(LocalPreviewResetService.purgedCanonicalValues, hasLength(5));
    expect(LocalPreviewResetService.preservedCanonicalMarkers, hasLength(5));
    expect(LocalPreviewResetService.purgedAnonymousKeys, hasLength(2));
    expect(LocalPreviewResetService.purgeDelegations, isNotEmpty);
    expect(LocalPreviewResetService.purgedPrefsKeys, hasLength(5));
    expect(LocalPreviewResetService.preservedDomains, isNotEmpty);
  });

  test('every seeded purged key is absent after reset and every preserved '
      'key is unchanged', () async {
    await seedFacts();
    const storage = FlutterSecureStorage();
    // Sentinelles préservées : marqueur anti-remigration + domaine appareil.
    await storage.write(
        key: '_mint_canonical_housing_initialized_v1', value: '1');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_locale', 'fr');

    await LocalPreviewResetService.reset();

    for (final key in [
      ...LocalPreviewResetService.purgedCanonicalValues,
      ...LocalPreviewResetService.purgedAnonymousKeys,
    ]) {
      expect(await storage.read(key: key), isNull, reason: '$key doit purger');
    }
    expect(await storage.read(key: '_mint_canonical_housing_initialized_v1'),
        '1',
        reason: 'marqueur anti-remigration PRÉSERVÉ');
    expect(prefs.getString('app_locale'), 'fr',
        reason: 'préférence appareil PRÉSERVÉE');
  });

  test('the five canonical values are purged while the five initialized '
      'markers survive', () async {
    await seedFacts();
    const storage = FlutterSecureStorage();
    for (final m in LocalPreviewResetService.preservedCanonicalMarkers) {
      await storage.write(key: m, value: '1');
    }
    await LocalPreviewResetService.reset();
    for (final v in LocalPreviewResetService.purgedCanonicalValues) {
      expect(await storage.read(key: v), isNull);
    }
    for (final m in LocalPreviewResetService.preservedCanonicalMarkers) {
      expect(await storage.read(key: m), '1');
    }
  });

  test('no global keychain deleteAll is ever invoked', () {
    final source =
        File('lib/services/local_preview_reset_service.dart').readAsStringSync();
    expect(source.contains('deleteAll('), isFalse,
        reason: 'un deleteAll détruirait session et marqueurs — interdit');
  });

  test('no prefix-based purge nor deleteAll exists in the reset service '
      '(static scan)', () {
    final source =
        File('lib/services/local_preview_reset_service.dart').readAsStringSync();
    expect(source.contains('deleteAll('), isFalse);
    expect(RegExp(r"startsWith\('_mint").hasMatch(source), isFalse,
        reason: 'purge par préfixe interdite — les marqueurs partagent le '
            'préfixe des valeurs');
  });

  test('the purged and preserved partition is closed: every known sensitive '
      'key is classified and the sets are disjoint', () {
    // Univers mécanique : toutes les clés _mint_canonical_* du store scellé.
    final storeSource =
        File('lib/services/secure_wizard_store.dart').readAsStringSync();
    final universe = RegExp(r"'(_mint_canonical_[a-z_0-9]+)'")
        .allMatches(storeSource)
        .map((m) => m.group(1)!)
        .toSet();
    final purged = LocalPreviewResetService.purgedCanonicalValues.toSet();
    final preserved =
        LocalPreviewResetService.preservedCanonicalMarkers.toSet();
    expect(purged.intersection(preserved), isEmpty);
    for (final key in universe) {
      expect(purged.contains(key) || preserved.contains(key), isTrue,
          reason: '$key doit être classée purge OU preserve — clé non '
              'classée = dérive');
    }
  });

  test('a partial failure keeps reset_pending and retries at boot', () async {
    await seedFacts();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(LocalPreviewResetService.resetPendingKey, true);
    await LocalPreviewResetService.retryPendingAtBoot();
    expect(prefs.getBool(LocalPreviewResetService.resetPendingKey), isNull,
        reason: 'retry réussi = pending levé');
    expect((await ReportPersistenceService.loadAnswers()), isEmpty,
        reason: 'le retry a réellement purgé');
  });

  test('running the reset twice is idempotent', () async {
    await seedFacts();
    await LocalPreviewResetService.reset();
    await LocalPreviewResetService.reset();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(LocalPreviewResetService.resetPendingKey), isNull);
    expect((await ReportPersistenceService.loadAnswers()), isEmpty);
  });

  test('a sealed-layer delete failure is never reported green', () async {
    await seedFacts();
    final prefs = await SharedPreferences.getInstance();
    // Panne injectée : le pending de la couche scellée reste posé — la
    // vérification doit REFUSER de conclure au vert et garder reset_pending.
    await prefs.setBool(LocalPreviewResetService.resetPendingKey, true);
    await prefs.setBool(LocalPreviewResetService.sealedLayerPendingKey, true);
    await expectLater(LocalPreviewResetService.verifyNoResidue(),
        throwsA(isA<StateError>()));
    expect(prefs.getBool(LocalPreviewResetService.resetPendingKey), isTrue,
        reason: 'échec scellé ⇒ reset toujours dû, jamais annoncé réussi');
    await prefs.remove(LocalPreviewResetService.sealedLayerPendingKey);
  });

  test('a residue detected turns the reset red, never silent', () async {
    const storage = FlutterSecureStorage();
    await storage.write(
        key: '_mint_canonical_versements_3a_v1', value: 'sticky');
    await expectLater(LocalPreviewResetService.verifyNoResidue(),
        throwsA(isA<StateError>()));

    // Chemin complet : pending posé, purge OK ⇒ vert ; résidu ⇒ le retry au
    // boot avale le StateError et LAISSE pending (jamais un demi-état sain).
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(LocalPreviewResetService.resetPendingKey, true);
    SecureWizardStore.resetSealFallbackForTest();
    await LocalPreviewResetService.retryPendingAtBoot();
    expect(prefs.getBool(LocalPreviewResetService.resetPendingKey), isNull,
        reason: 'la purge du retry retire le résidu re-seedé — vert');
  });

  test('the quarantine marker is set per signed-in user after a verified '
      'purge', () async {
    await seedFacts();
    await LocalPreviewResetService.reset(signedInUserId: 'user-42');
    expect(await LocalPreviewResetService.isQuarantined('user-42'), isTrue);
    expect(await LocalPreviewResetService.isQuarantined('other'), isFalse);
  });

  test('calling reset outside the preview policy throws and purges nothing',
      () async {
    await seedFacts();
    PreviewShellPolicy.debugOverride =
        const PreviewShellPolicy.forTest(isPreviewShell: false);
    await expectLater(
        LocalPreviewResetService.reset(), throwsA(isA<StateError>()));
    const storage = FlutterSecureStorage();
    expect(await storage.read(key: '_mint_canonical_lpp_affiliation_v1'),
        isNotNull,
        reason: 'RIEN ne doit être purgé hors préversion');
  });
}
