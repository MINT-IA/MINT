import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/services/anonymous_session_service.dart';
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

  /// Le gros des SharedPreferences métier est purgé par délégation aux
  /// primitives canoniques existantes (pas de double implémentation).
  static const List<String> purgeDelegations = [
    'ReportPersistenceService.clearDiagnostic',
    'SecureWizardStore.deleteAllDuringCoordinatedReset (via clearDiagnostic)',
    'AnonymousSessionService.clearSession',
  ];

  /// Domaines PRÉSERVÉS — jamais touchés par ce service.
  static const List<String> preservedDomains = [
    'session/authentification (jetons du compte connecté)', // lint-ignore — inventaire interne, jamais rendu
    'consentements encore applicables',
    'langue, accessibilité et préférences appareil', // lint-ignore — inventaire interne, jamais rendu
    'disclosure TestFlight',
    "marqueurs d'installation/retry",
  ];

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
    await prefs.setBool(resetPendingKey, true);
    if (signedInUserId != null && signedInUserId.isNotEmpty) {
      await prefs.setString(quarantineKeyFor(signedInUserId),
          DateTime.now().toUtc().toIso8601String());
    }

    await ReportPersistenceService.clearDiagnostic();
    await AnonymousSessionService.clearSession();

    // Vérification zéro résidu — un résidu laisse reset_pending posé
    // (retry au boot) et remonte ROUGE, jamais silencieux.
    await verifyNoResidue();
    await prefs.remove(resetPendingKey);
  }

  /// Vérification zéro résidu — publique pour que le chemin ROUGE soit
  /// testable déterministiquement (un résidu ⇒ StateError, pending intact).
  static Future<void> verifyNoResidue() async {
    const storage = FlutterSecureStorage();
    for (final key in [...purgedCanonicalValues, ...purgedAnonymousKeys]) {
      final residue = await storage.read(key: key);
      if (residue != null) {
        throw StateError(
            'reset residue detected: $key — reset_pending kept, retried at '
            'next boot');
      }
    }
  }

  /// Retry d'un reset dû — appelé au boot AVANT toute hydratation de
  /// provider (l'ordre est prouvé par test sur main.dart).
  static Future<void> retryPendingAtBoot() async {
    if (!PreviewShellPolicy.instance.isPreviewShell) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(resetPendingKey) != true) return;
    try {
      await reset();
    } on StateError {
      // Toujours dû — reset_pending reste posé, l'app démarre quand même
      // (l'état affiché reste celui d'un reset en cours, pas un demi-état
      // présenté comme sain).
    }
  }

  /// Vrai si l'hydratation serveur du profil est en quarantaine pour ce
  /// compte (un reset local a eu lieu et rien ne doit ressusciter).
  static Future<bool> isQuarantined(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(quarantineKeyFor(userId)) != null;
  }
}
