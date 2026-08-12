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
    LocalPreviewResetService.debugPurgeFailureForTest = null;
    LocalPreviewResetService.debugFailingPrefWritesForTest = {};
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
    expect(LocalPreviewResetService.purgeDelegations, hasLength(7));
    expect(LocalPreviewResetService.purgedSecureStoreKeys, hasLength(3));
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

  test('a failed reset retried at boot still quarantines the signed-in user',
      () async {
    await seedFacts();
    final prefs = await SharedPreferences.getInstance();
    // Panne injectée APRÈS la pose du pending, AVANT toute purge.
    LocalPreviewResetService.debugPurgeFailureForTest =
        () async => throw StateError('injected purge failure');
    await expectLater(
        LocalPreviewResetService.reset(signedInUserId: 'user-42'),
        throwsA(isA<StateError>()));
    expect(prefs.getBool(LocalPreviewResetService.resetPendingKey), isTrue);
    expect(prefs.getString(LocalPreviewResetService.resetPendingUserKey),
        'user-42',
        reason: "l'identité visée survit à l'échec avec le pending");
    expect(await LocalPreviewResetService.isQuarantined('user-42'), isFalse,
        reason: 'pas de quarantaine tant que la purge n\'est pas vérifiée');

    // La panne disparaît ; le retry au boot doit poser la quarantaine du
    // BON compte — sinon la réhydratation serveur mentirait.
    LocalPreviewResetService.debugPurgeFailureForTest = null;
    await LocalPreviewResetService.retryPendingAtBoot();
    expect(prefs.getBool(LocalPreviewResetService.resetPendingKey), isNull);
    expect(prefs.getString(LocalPreviewResetService.resetPendingUserKey),
        isNull);
    expect(await LocalPreviewResetService.isQuarantined('user-42'), isTrue,
        reason: 'le retry réussi pose la quarantaine du compte visé');
  });

  test('a crash between the identity write and the pending write is a '
      'harmless no-op at boot', () async {
    // L'ordre identité→pending garantit que la frontière défaillante laisse
    // une identité orpheline SANS pending : le boot ne purge rien, ne lève
    // rien, ne quarantine rien — aucun demi-état menteur.
    final source =
        File('lib/services/local_preview_reset_service.dart')
            .readAsStringSync();
    expect(source.indexOf('setString(resetPendingUserKey'),
        lessThan(source.indexOf('setBool(resetPendingKey')),
        reason: "l'identité s'écrit AVANT le pending — l'ordre inverse "
            'permettrait une purge au boot levée sans quarantaine');

    await seedFacts();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        LocalPreviewResetService.resetPendingUserKey, 'user-42');
    await LocalPreviewResetService.retryPendingAtBoot();
    expect((await ReportPersistenceService.loadAnswers()), isNotEmpty,
        reason: 'identité orpheline sans pending = RIEN ne se purge');
    expect(await LocalPreviewResetService.isQuarantined('user-42'), isFalse);
  });

  test('a reset retriggered while signed out still quarantines the account '
      'recorded with the due reset', () async {
    await seedFacts();
    LocalPreviewResetService.debugPurgeFailureForTest =
        () async => throw StateError('injected purge failure');
    await expectLater(
        LocalPreviewResetService.reset(signedInUserId: 'user-42'),
        throwsA(isA<StateError>()));
    LocalPreviewResetService.debugPurgeFailureForTest = null;

    // Redéclenché DÉCONNECTÉ : l'identité enregistrée avec le reset dû
    // survit et le compte visé est bien quarantiné à l'aboutissement.
    await LocalPreviewResetService.reset();
    expect(await LocalPreviewResetService.isQuarantined('user-42'), isTrue,
        reason: "l'identité d'un reset dû n'est jamais déchirée par un "
            'redéclenchement anonyme');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(LocalPreviewResetService.resetPendingKey), isNull);
    expect(prefs.getString(LocalPreviewResetService.resetPendingUserKey),
        isNull);
  });

  test('a quarantine write reported failed by the platform never lifts the '
      'pending', () async {
    await seedFacts();
    final prefs = await SharedPreferences.getInstance();
    // Panne plateforme injectée : l'écriture de quarantaine retourne false.
    LocalPreviewResetService.debugFailingPrefWritesForTest = {
      LocalPreviewResetService.quarantineKeyFor('user-42'),
    };
    await expectLater(
        LocalPreviewResetService.reset(signedInUserId: 'user-42'),
        throwsA(isA<StateError>()));
    expect(prefs.getBool(LocalPreviewResetService.resetPendingKey), isTrue,
        reason: 'quarantaine non durable = reset JAMAIS annoncé terminé');
    expect(prefs.getString(LocalPreviewResetService.resetPendingUserKey),
        'user-42');

    // La plateforme se rétablit : le retry aboutit ET quarantine.
    LocalPreviewResetService.debugFailingPrefWritesForTest = {};
    await LocalPreviewResetService.retryPendingAtBoot();
    expect(await LocalPreviewResetService.isQuarantined('user-42'), isTrue);
    expect(prefs.getBool(LocalPreviewResetService.resetPendingKey), isNull);
  });

  test('an identity write reported failed by the platform aborts before any '
      'pending or purge', () async {
    await seedFacts();
    LocalPreviewResetService.debugFailingPrefWritesForTest = {
      LocalPreviewResetService.resetPendingUserKey,
    };
    await expectLater(
        LocalPreviewResetService.reset(signedInUserId: 'user-42'),
        throwsA(isA<StateError>()));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(LocalPreviewResetService.resetPendingKey), isNull,
        reason: 'identité non écrite = pending jamais posé, rien ne démarre');
    expect((await ReportPersistenceService.loadAnswers()), isNotEmpty,
        reason: 'rien purgé — aucun demi-état');
  });

  test('a pending lift reported failed by the platform keeps the identity '
      'so the retry still quarantines the right account', () async {
    // Ordre des levées : pending PUIS identité — l'identité survit tant que
    // le pending subsiste (assertion statique + panne séquencée).
    final source = File('lib/services/local_preview_reset_service.dart')
        .readAsStringSync();
    expect(source.indexOf("'remove:\$resetPendingKey'"),
        lessThan(source.indexOf("'remove:\$resetPendingUserKey'")),
        reason: 'lever le pending AVANT de supprimer l\'identité');

    await seedFacts();
    final prefs = await SharedPreferences.getInstance();
    LocalPreviewResetService.debugFailingPrefWritesForTest = {
      'remove:${LocalPreviewResetService.resetPendingKey}',
    };
    await expectLater(
        LocalPreviewResetService.reset(signedInUserId: 'user-42'),
        throwsA(isA<StateError>()));
    expect(prefs.getString(LocalPreviewResetService.resetPendingUserKey),
        'user-42',
        reason: "l'identité SURVIT tant que le pending subsiste");
    expect(prefs.getBool(LocalPreviewResetService.resetPendingKey), isTrue);

    LocalPreviewResetService.debugFailingPrefWritesForTest = {};
    await LocalPreviewResetService.retryPendingAtBoot();
    expect(await LocalPreviewResetService.isQuarantined('user-42'), isTrue,
        reason: 'le retry termine ET quarantine le compte visé');
    expect(prefs.getBool(LocalPreviewResetService.resetPendingKey), isNull);
    expect(prefs.getString(LocalPreviewResetService.resetPendingUserKey),
        isNull);
  });

  test('a stale identity with no pending never influences a later reset',
      () async {
    await seedFacts();
    final prefs = await SharedPreferences.getInstance();
    // Orpheline d'une tentative passée : identité SANS pending.
    await prefs.setString(
        LocalPreviewResetService.resetPendingUserKey, 'user-99');
    await LocalPreviewResetService.reset();
    expect(await LocalPreviewResetService.isQuarantined('user-99'), isFalse,
        reason: 'une orpheline sans reset dû ne quarantine JAMAIS — le '
            'fallback est gaté sur le pending');
    expect(prefs.getString(LocalPreviewResetService.resetPendingUserKey),
        isNull, reason: "l'orpheline inerte est purgée au passage");
  });

  test('an identity lift failure after the pending lift never turns a '
      'complete reset into a false failure', () async {
    await seedFacts();
    final prefs = await SharedPreferences.getInstance();
    LocalPreviewResetService.debugFailingPrefWritesForTest = {
      'remove:${LocalPreviewResetService.resetPendingUserKey}',
    };
    // Reset COMPLET (purgé, vérifié, quarantiné) : la clé morte restante ne
    // le transforme pas en faux échec.
    await LocalPreviewResetService.reset(signedInUserId: 'user-42');
    expect(await LocalPreviewResetService.isQuarantined('user-42'), isTrue);
    expect(prefs.getBool(LocalPreviewResetService.resetPendingKey), isNull);
    expect(prefs.getString(LocalPreviewResetService.resetPendingUserKey),
        'user-42',
        reason: 'clé morte restante — inerte car le pending est levé');

    // Passe suivante : l'orpheline inerte est purgée, jamais réutilisée.
    LocalPreviewResetService.debugFailingPrefWritesForTest = {};
    await LocalPreviewResetService.reset();
    expect(prefs.getString(LocalPreviewResetService.resetPendingUserKey),
        isNull);
  });

  test('the boot retry encloses prefs acquisition and reads in its '
      'error barrier (static scan)', () {
    final source = File('lib/services/local_preview_reset_service.dart')
        .readAsStringSync();
    final body = source.substring(source.indexOf('retryPendingAtBoot()'));
    final tryIdx = body.indexOf('try {');
    expect(tryIdx, greaterThan(-1));
    expect(tryIdx, lessThan(body.indexOf('SharedPreferences.getInstance')),
        reason: "l'acquisition des prefs est DANS la barrière d'erreur");
    expect(tryIdx, lessThan(body.indexOf('getBool(resetPendingKey)')),
        reason: 'la lecture du pending est DANS la barrière d\'erreur');
  });

  test('the boot retry absorbs any purge error and keeps the reset due',
      () async {
    await seedFacts();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(LocalPreviewResetService.resetPendingKey, true);
    // Erreur NON-StateError (I/O, PlatformException…) : le boot doit
    // l'absorber — l'app démarre, le reset reste dû.
    LocalPreviewResetService.debugPurgeFailureForTest =
        () async => throw Exception('injected io failure');
    await LocalPreviewResetService.retryPendingAtBoot();
    expect(prefs.getBool(LocalPreviewResetService.resetPendingKey), isTrue,
        reason: 'toute erreur absorbée, reset toujours dû — jamais un '
            'démarrage bloqué');
  });

  test('every secure-storage consumer file is classified purge-covered or '
      'preserved (closed file registry)', () {
    // Registre FERMÉ au niveau fichiers : tout nouveau consommateur de
    // storage scellé doit être classé ici AVANT merge — purge-covered
    // (ses clés tombent sous une délégation du reset) ou preserved (hors
    // périmètre du reset, avec raison). Fichier non classé = FAIL.
    const purgeCovered = {
      'lib/services/secure_wizard_store.dart', // valeurs canoniques + PII
      'lib/services/anonymous_session_service.dart', // quota anonyme
      'lib/services/partner_estimate_service.dart', // estimation partenaire
      'lib/services/mint_next_3a_task_store.dart', // tâche 3a du jumeau
      'lib/services/biography/biography_repository.dart', // crypto-shred clé
    };
    const preserved = {
      'lib/services/auth_service.dart', // session — jamais déconnecté
      'lib/services/consent/consent_service.dart', // consentements
      'lib/services/install_lifecycle_service.dart', // marqueurs install
      'lib/providers/byok_provider.dart', // credential utilisateur
      'lib/screens/byok_settings_screen.dart', // credential utilisateur
      'lib/services/audit/audit_buffer_db.dart', // intégrité d\'audit
      'lib/services/local_preview_reset_service.dart', // orchestrateur
    };
    final consumers = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) =>
            f.readAsStringSync().contains('flutter_secure_storage'))
        .map((f) => f.path)
        .toSet();
    expect(consumers.length, greaterThan(8),
        reason: 'balayage vide = test théâtre');
    expect(purgeCovered.intersection(preserved), isEmpty);
    for (final path in consumers) {
      expect(purgeCovered.contains(path) || preserved.contains(path), isTrue,
          reason: '$path consomme le storage scellé sans être classé '
              'purge-covered OU preserved = dérive');
    }
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

  test('after reset no automatic server hydration repopulates the profile '
      'while the quarantine marker exists', () async {
    await seedFacts();
    await LocalPreviewResetService.reset(signedInUserId: 'user-42');
    // Utilisateur connecté simulé : jeton + id présents dans le storage.
    const storage = FlutterSecureStorage();
    await storage.write(key: 'jwt_token', value: 'tok');
    await storage.write(key: 'user_id', value: 'user-42');
    final provider = CoachProfileProvider();
    CoachProfileProvider.debugLastSyncSkippedByQuarantine = false;
    await provider.syncFromBackend();
    expect(CoachProfileProvider.debugLastSyncSkippedByQuarantine, isTrue,
        reason: "l'hydratation serveur est REFUSÉE tant que la quarantaine "
            'existe — rien ne ressuscite en silence');
    expect(provider.profile, isNull);
  });

  test('the boot retry of reset_pending runs before any provider hydration '
      'or mutation', () {
    final mainSource = File('lib/main.dart').readAsStringSync();
    final retryIdx = mainSource.indexOf('retryPendingAtBoot');
    final runAppIdx = mainSource.indexOf('runApp(');
    expect(retryIdx, greaterThan(-1));
    expect(retryIdx, lessThan(runAppIdx),
        reason: 'le retry précède le montage de l\'app — aucune hydratation '
            'de provider ne peut le devancer');
  });

  test('the sealed PII universe (sensitive keys and manifest entries) is '
      'fully purged by reset', () async {
    // Univers mécanique : tous les littéraux PII (q_* / _coach_*) déclarés
    // dans la source du store scellé — toute clé ajoutée est couverte
    // d'office, aucune liste à maintenir à la main.
    final storeSource =
        File('lib/services/secure_wizard_store.dart').readAsStringSync();
    // Les littéraux finissant par `_` sont des PRÉFIXES de routage
    // (startsWith), pas des clés — les clés dynamiques ainsi routées passent
    // par le manifeste, couvert plus bas.
    final candidates = RegExp(r"""['"]((?:q_|_coach_)[a-z_0-9]*[a-z0-9])['"]""")
        .allMatches(storeSource)
        .map((m) => m.group(1)!)
        .toSet();
    // Toute clé extraite DOIT être classée par le store (anti-dérive) ; les
    // scellées forment l'univers purgé ici, les non-scellées vivent dans le
    // JSON wizard_answers_v2 (purgé côté prefs, cf. purgedPrefsKeys).
    for (final key in candidates) {
      expect(SecureWizardStore.classificationForKey(key),
          isNot(WizardStorageClassification.unknown),
          reason: '$key extraite mais non classée par le store = dérive');
    }
    final universe =
        candidates.where(SecureWizardStore.isSensitive).toSet();
    expect(universe.length, greaterThan(80),
        reason: 'extraction vide = test théâtre');
    const storage = FlutterSecureStorage();
    for (final key in universe) {
      await storage.write(key: key, value: 'pii');
    }
    // Clé scellée DYNAMIQUE enregistrée au manifeste : purgée aussi.
    await storage.write(
        key: '_mint_wizard_secure_keys_v1',
        value: '["dynamic_pii_key_x"]');
    await storage.write(key: 'dynamic_pii_key_x', value: 'pii');

    await LocalPreviewResetService.reset();

    for (final key in universe) {
      expect(await storage.read(key: key), isNull,
          reason: '$key (PII scellée) doit être purgée');
    }
    expect(await storage.read(key: 'dynamic_pii_key_x'), isNull,
        reason: 'les clés du manifeste dynamique sont purgées aussi');
  });

  test('the prefs key universe declared by the persistence service is fully '
      'purged by reset', () async {
    // Univers mécanique : tous les littéraux `static const String *Key`
    // de report_persistence_service — une clé métier ajoutée sans purge
    // dans clear() fait échouer ce test (guard anti-dérive exécutable).
    final source = File('lib/services/report_persistence_service.dart')
        .readAsStringSync();
    final universe =
        RegExp(r"""static const String _\w*[Kk]ey\w*\s*=\s*['"]([^'"]+)['"]""")
            .allMatches(source)
            .map((m) => m.group(1)!)
            .toSet();
    expect(universe.length, greaterThan(15),
        reason: 'extraction vide = test théâtre');
    final prefs = await SharedPreferences.getInstance();
    const boolKeys = {
      'secure_delete_pending_v1',
      'wizard_completed',
      'mini_onboarding_completed',
      'anonymous_wizard_completed_held_v1',
      'anonymous_mini_onboarding_completed_held_v1',
    };
    for (final key in universe) {
      if (boolKeys.contains(key)) {
        await prefs.setBool(key, true);
      } else {
        await prefs.setString(key, 'seeded');
      }
    }
    await seedFacts();

    await LocalPreviewResetService.reset();

    for (final key in universe) {
      expect(prefs.get(key), isNull,
          reason: '$key doit être purgée — clé du service de persistance '
              'non couverte par le reset = dérive');
    }
  });

  test('the signed-in session keys are never part of any purged universe '
      'and survive reset', () async {
    final storeSource =
        File('lib/services/secure_wizard_store.dart').readAsStringSync();
    for (final sessionKey in ['jwt_token', 'user_id']) {
      expect(storeSource.contains("'$sessionKey'"), isFalse,
          reason: '$sessionKey ne doit JAMAIS entrer dans un univers purgé');
    }
    const storage = FlutterSecureStorage();
    await storage.write(key: 'jwt_token', value: 'tok');
    await storage.write(key: 'user_id', value: 'user-42');
    await seedFacts();

    await LocalPreviewResetService.reset(signedInUserId: 'user-42');

    expect(await storage.read(key: 'jwt_token'), 'tok',
        reason: 'le reset ne déconnecte JAMAIS — session préservée');
    expect(await storage.read(key: 'user_id'), 'user-42');
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
