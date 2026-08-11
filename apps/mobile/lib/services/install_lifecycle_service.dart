import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/services/mint_next_3a_task_store.dart';
import 'package:mint_mobile/services/auth_service.dart';
import 'package:mint_mobile/services/secure_wizard_store.dart';

/// Guards Mint against iOS Keychain items surviving app uninstall.
///
/// The marker intentionally lives in SharedPreferences, not Keychain. When the
/// app starts with an empty prefs store but old MINT Keychain values, we treat
/// it as a fresh local install and purge the known MINT secure-storage keys
/// before auth has a chance to restore a stale session.
class InstallLifecycleService {
  @visibleForTesting
  static Future<bool> Function(bool purged, SharedPreferences prefs)?
      debugRecordOwnedSecurePurgeResultOverride;
  static const installMarkerKey = 'mint_install_marker_v1';
  static const securePurgePendingKey = 'mint_install_secure_purge_pending_v1';
  static const ownedSecurePurgePendingKey =
      'mint_owned_secure_purge_pending_v1';

  static const _directSecureKeys = {
    'byok_provider',
    'byok_api_key',
    'mint_partner_estimate',
    'anonymous_session_id',
    'anonymous_message_count',
    'mint_biography_key',
    // PR B 2026-08-10 : purge directe de la clé du store 3a (le store
    // lui-même atterrit en PR C) — la complétude de purge ne dépend
    // d'aucun composant absent.
    'mint_next_3a_task_v1',
  };

  static const _freshInstallNeutralPrefs = {
    'regulatory_cache',
  };

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device),
  );

  /// Returns whether AuthService may read stored credentials this launch.
  static Future<bool> prepareForAuthRestore() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(ownedSecurePurgePendingKey) == true) {
      await _retryOwnedSecurePurge(prefs);
    }

    if (prefs.getBool(installMarkerKey) == true) return true;

    if (prefs.getBool(securePurgePendingKey) == true) {
      await _retryInstallPurge(prefs);
      return false;
    }

    final hasExistingPrefs = prefs.getKeys().any(
          (key) =>
              key != installMarkerKey &&
              key != securePurgePendingKey &&
              key != ownedSecurePurgePendingKey &&
              !_freshInstallNeutralPrefs.contains(key),
        );
    if (hasExistingPrefs) {
      await prefs.setBool(installMarkerKey, true);
      return true;
    }

    await _retryInstallPurge(prefs);
    return false;
  }

  static Future<void> _retryInstallPurge(SharedPreferences prefs) async {
    final purged = await purgeMintSecureStorage();
    if (purged) {
      await prefs.remove(securePurgePendingKey);
      await prefs.setBool(installMarkerKey, true);
    } else {
      await prefs.setBool(securePurgePendingKey, true);
    }
  }

  static Future<void> _retryOwnedSecurePurge(SharedPreferences prefs) async {
    final purged = await purgeMintSecureStorage(includeAuthSession: false);
    await recordOwnedSecurePurgeResult(purged, prefs: prefs);
  }

  static Future<bool> recordOwnedSecurePurgeResult(
    bool purged, {
    SharedPreferences? prefs,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final override = debugRecordOwnedSecurePurgeResultOverride;
    if (override != null) return override(purged, store);
    if (purged) {
      return store.remove(ownedSecurePurgePendingKey);
    }
    return store.setBool(ownedSecurePurgePendingKey, true);
  }

  static Future<bool> purgeMintSecureStorage({
    bool includeAuthSession = true,
  }) async {
    var purged =
        includeAuthSession ? await AuthService.purgeStoredSession() : true;
    purged = await SecureWizardStore.deleteAll() && purged;
    purged = await SecureWizardStore.deleteHeldSensitiveValues() && purged;
    purged = await MintNext3aTaskStore.purgeOwnedTask() && purged;

    for (final key in _directSecureKeys) {
      try {
        await _storage.delete(key: key);
      } on Exception catch (e) {
        if (SecureWizardStore.isTolerableE2eKeychainAbsence(e)) continue;
        purged = false;
        if (kDebugMode) {
          debugPrint('[InstallLifecycle] owned secure purge failed');
        }
      }
    }

    return purged;
  }
}
