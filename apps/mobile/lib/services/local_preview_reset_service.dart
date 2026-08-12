import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/services/biography/biography_repository.dart';
import 'package:mint_mobile/services/cap_memory_store.dart';
import 'package:mint_mobile/services/coach/precomputed_insights_service.dart';
import 'package:mint_mobile/services/memory/coach_memory_service.dart';
import 'package:mint_mobile/services/mint_next_3a_task_store.dart';
import 'package:mint_mobile/services/partner_estimate_service.dart';
import 'package:mint_mobile/services/preview_shell_policy.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';

/// Bascule 2 — « repartir à zéro sur cet appareil », honnêtement.
///
/// Contrat : `product/mint_next/storyboard/local_reset.storyboard.json`.
/// Orchestrateur canonique UNIQUE, strictement préversion (appel direct hors
/// préversion = invariant violé, THROW sans rien purger). Réutilise les
/// primitives existantes — jamais de deleteAll global, jamais de purge par
/// préfixe : valeurs canoniques et marqueurs anti-remigration ont des
/// contrats opposés.
class LocalPreviewResetService {
  const LocalPreviewResetService._();

  /// Marqueur durable : un reset entamé qui échoue reste dû — retry au boot
  /// AVANT toute hydratation.
  static const String resetPendingKey = 'mint_preview_reset_pending_v1';

  /// Identité du compte visé par un reset dû : persistée avec le pending
  /// pour que le retry au boot pose la quarantaine du BON utilisateur —
  /// sinon un échec puis un retry réussi laisserait la porte ouverte à la
  /// réhydratation serveur.
  static const String resetPendingUserKey = 'mint_preview_reset_pending_user_v1';

  /// Quarantaine de synchronisation : tant que présent pour l'utilisateur
  /// connecté, aucune hydratation serveur automatique ne repeuple le profil
  /// — sinon « repartir à zéro » serait mensonger.
  static String quarantineKeyFor(String userId) =>
      'local_profile_reset_epoch_$userId';

  // ── Inventaires constants (partition fermée, testée) ──

  /// Valeurs canoniques scellées : PURGÉES.
  static const List<String> purgedCanonicalValues = [
    '_mint_canonical_housing_v1',
    '_mint_canonical_civil_status_v1',
    '_mint_canonical_revenu_v1',
    '_mint_canonical_lpp_affiliation_v1',
    '_mint_canonical_versements_3a_v1',
  ];

  /// Marqueurs anti-remigration : PRÉSERVÉS — ils empêchent la remigration
  /// de données supprimées, les effacer ressusciterait du legacy.
  static const List<String> preservedCanonicalMarkers = [
    '_mint_canonical_housing_initialized_v1',
    '_mint_canonical_civil_status_initialized_v1',
    '_mint_canonical_revenu_initialized_v1',
    '_mint_canonical_lpp_affiliation_initialized_v1',
    '_mint_canonical_versements_3a_initialized_v1',
  ];

  /// Quota anonyme : PURGÉ — uniquement parce que ce service est
  /// preview-only (jamais un contournement anti-abus public).
  static const List<String> purgedAnonymousKeys = [
    'anonymous_session_id',
    'anonymous_message_count',
  ];

  /// Le gros du métier est purgé par délégation aux primitives existantes
  /// (pas de double implémentation) — mêmes briques que la séquence de
  /// purge V6-4 du logout, SANS toucher session/consentements.
  static const List<String> purgeDelegations = [
    'ReportPersistenceService.clear (clearDiagnostic + clearCoachHistory + conversations + AnonymousSessionService.clearSession + BudgetLocalStore.clear + lettres)',
    'CoachMemoryService.clear (insights coach, namespaces compte + anonyme)',
    'CapMemoryStore.clear (mémoire CapEngine)', // lint-ignore — inventaire interne, jamais rendu
    'PrecomputedInsightsService.clear (insights précalculés)', // lint-ignore — inventaire interne, jamais rendu
    'PartnerEstimateService.clear (estimation partenaire scellée)', // lint-ignore — inventaire interne, jamais rendu
    'MintNext3aTaskStore.purgeOwnedTask (tâche 3a du jumeau)', // lint-ignore — inventaire interne, jamais rendu
    'BiographyRepository.clearEncryptionKey (crypto-shred de la biographie)', // lint-ignore — inventaire interne, jamais rendu
  ];

  /// Clés scellées possédées par les stores délégués : vérifiées absentes
  /// après purge (résidu = ROUGE).
  static const List<String> purgedSecureStoreKeys = [
    'mint_partner_estimate',
    'mint_next_3a_task_v1',
    'mint_biography_key',
  ];

  /// Clés prefs métier vérifiées absentes après purge (résidu = ROUGE).
  static const List<String> purgedPrefsKeys = [
    'wizard_answers_v2',
    'wizard_completed',
    'anonymous_wizard_answers_held_v1',
    'anonymous_wizard_completed_held_v1',
    'anonymous_mini_onboarding_completed_held_v1',
  ];

  /// Pending de la couche scellée — s'il reste posé après la purge, la
  /// suppression sécurisée a ÉCHOUÉ : jamais un reset annoncé vert.
  static const String sealedLayerPendingKey = 'secure_delete_pending_v1';

  /// Domaines PRÉSERVÉS — jamais touchés par ce service.
  static const List<String> preservedDomains = [
    'session/authentification (jetons du compte connecté)', // lint-ignore — inventaire interne, jamais rendu
    'consentements encore applicables',
    'langue, accessibilité et préférences appareil', // lint-ignore — inventaire interne, jamais rendu
    'disclosure TestFlight',
    "marqueurs d'installation/retry",
  ];

  /// Panne injectée par les tests entre la pose du pending et la purge.
  @visibleForTesting
  static Future<void> Function()? debugPurgeFailureForTest;

  /// Clés prefs dont l'écriture est forcée en échec (retour false) par les
  /// tests — simule une panne plateforme du stockage.
  @visibleForTesting
  static Set<String> debugFailingPrefWritesForTest = {};

  /// Écriture prefs OBLIGATOIREMENT réussie : SharedPreferences retourne
  /// false en cas d'échec plateforme — l'ignorer permettrait une purge
  /// « terminée » sans quarantaine durable ou un pending fantôme.
  static Future<void> _requireWrite(
      String key, Future<bool> Function() op) async {
    final ok =
        debugFailingPrefWritesForTest.contains(key) ? false : await op();
    if (!ok) {
      throw StateError(
          'prefs write failed for $key — reset remains due, retried at '
          'next boot');
    }
  }

  /// Purge locale complète — transactionnelle et idempotente.
  ///
  /// [signedInUserId] : pose la quarantaine de sync pour ce compte.
  static Future<void> reset({String? signedInUserId}) async {
    if (!PreviewShellPolicy.instance.isPreviewShell) {
      throw StateError(
          'LocalPreviewResetService is preview-only — direct call outside '
          'the preview shell is forbidden, nothing was purged'); // lint-ignore — message développeur
    }
    final prefs = await SharedPreferences.getInstance();
    // Une identité déjà enregistrée avec un reset dû SURVIT jusqu'à purge
    // vérifiée : même redéclenché déconnecté, le compte visé sera bien
    // quarantiné.
    final effectiveUserId =
        (signedInUserId != null && signedInUserId.isNotEmpty)
            ? signedInUserId
            : prefs.getString(resetPendingUserKey);
    // Identité AVANT pending : une panne entre les deux laisse une identité
    // orpheline SANS pending (no-op au boot, rien de purgé, rien de menti).
    // L'ordre inverse laisserait un pending sans identité — purge au boot
    // puis levée SANS quarantaine : mensonge de réhydratation.
    if (effectiveUserId != null && effectiveUserId.isNotEmpty) {
      await _requireWrite(resetPendingUserKey,
          () => prefs.setString(resetPendingUserKey, effectiveUserId));
    }
    await _requireWrite(
        resetPendingKey, () => prefs.setBool(resetPendingKey, true));
    // Panne injectable (même précédent que debugEarlyLocalPurgeFailure
    // d'AuthProvider) : prouve que pending + identité survivent à un échec
    // survenu APRÈS leur pose et AVANT toute purge.
    await debugPurgeFailureForTest?.call();

    // Purge complète par délégation (diagnostic + coach + conversations +
    // session anonyme + budget + lettres).
    await ReportPersistenceService.clear(conversationUserId: effectiveUserId);
    // Mémoires dérivées et stores scellés annexes — mêmes primitives que la
    // purge V6-4 du logout, session et consentements exclus.
    await CoachMemoryService.clear(prefs: prefs);
    await CapMemoryStore.clear();
    await PrecomputedInsightsService.clear(prefs);
    await PartnerEstimateService.clear();
    final taskPurged = await MintNext3aTaskStore.purgeOwnedTask();
    if (!taskPurged) {
      throw StateError(
          '3a task store purge failed — reset_pending kept, retried at '
          'next boot');
    }
    await BiographyRepository.clearEncryptionKey();

    // Vérification zéro résidu — un résidu ou un échec de la couche scellée
    // laisse reset_pending posé (retry au boot) et remonte ROUGE.
    await verifyNoResidue();

    // Quarantaine posée APRÈS purge vérifiée (ordre du contrat) : aucune
    // hydratation serveur automatique ne repeuplera ce compte.
    if (effectiveUserId != null && effectiveUserId.isNotEmpty) {
      final quarantineKey = quarantineKeyFor(effectiveUserId);
      await _requireWrite(
          quarantineKey,
          () => prefs.setString(
              quarantineKey, DateTime.now().toUtc().toIso8601String()));
    }
    // Les levées aussi : un remove retournant false laisserait un pending
    // fantôme — mieux vaut le dire (retry au boot) que prétendre au propre.
    // Pending AVANT identité : l'identité SURVIT tant que le pending
    // subsiste — jamais un pending orphelin qu'un retry terminerait sans
    // quarantiner le compte visé.
    await _requireWrite(
        'remove:$resetPendingKey', () => prefs.remove(resetPendingKey));
    await _requireWrite('remove:$resetPendingUserKey',
        () => prefs.remove(resetPendingUserKey));
  }

  /// Vérification zéro résidu — publique pour que le chemin ROUGE soit
  /// testable déterministiquement (un résidu ⇒ StateError, pending intact).
  static Future<void> verifyNoResidue() async {
    final prefs = await SharedPreferences.getInstance();
    // Échec de la couche scellée jamais vert : son pending propre trahit
    // une suppression sécurisée incomplète même si les mocks lisent null.
    if (prefs.getBool(sealedLayerPendingKey) == true) {
      throw StateError(
          'sealed-layer delete failed (pending flag set) — reset_pending '
          'kept, retried at next boot');
    }
    const storage = FlutterSecureStorage();
    for (final key in [
      ...purgedCanonicalValues,
      ...purgedAnonymousKeys,
      ...purgedSecureStoreKeys,
    ]) {
      final residue = await storage.read(key: key);
      if (residue != null) {
        throw StateError(
            'reset residue detected: $key — reset_pending kept, retried at '
            'next boot');
      }
    }
    for (final key in purgedPrefsKeys) {
      if (prefs.get(key) != null) {
        throw StateError(
            'reset residue detected in prefs: $key — reset_pending kept');
      }
    }
  }

  /// Retry d'un reset dû — appelé au boot AVANT toute hydratation de
  /// provider (l'ordre est prouvé par test sur main.dart).
  static Future<void> retryPendingAtBoot() async {
    // Le try englobe TOUTE la séquence — acquisition et lecture des prefs
    // comprises : aucune erreur de stockage ne doit empêcher le démarrage.
    try {
      if (!PreviewShellPolicy.instance.isPreviewShell) return;
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(resetPendingKey) != true) return;
      // L'identité persistée avec le pending garantit que la quarantaine
      // du BON compte est posée même quand le succès n'arrive qu'au retry.
      await reset(signedInUserId: prefs.getString(resetPendingUserKey));
    } catch (_) {
      // TOUTE erreur (acquisition prefs, lecture, StateError,
      // PlatformException, I/O…) est absorbée : reset_pending reste posé si
      // déjà écrit, l'app démarre quand même (l'état affiché reste celui
      // d'un reset en cours, pas un demi-état présenté comme sain).
    }
  }

  /// Vrai si l'hydratation serveur du profil est en quarantaine pour ce
  /// compte (un reset local a eu lieu et rien ne doit ressusciter).
  static Future<bool> isQuarantined(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(quarantineKeyFor(userId)) != null;
  }
}
