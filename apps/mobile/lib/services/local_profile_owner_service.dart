import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Device-local profile owner id used before account-backed ownership exists.
///
/// The secure store is the source of truth. SharedPreferences is only a local
/// simulator/dev fallback when Keychain/Keystore is unavailable.
class LocalProfileOwnerService {
  LocalProfileOwnerService._();

  static const _ownerKey = 'mint_local_profile_owner_id';
  static const _fallbackKey = 'mintfb_$_ownerKey';
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static Future<String> getOrCreateOwnerId() async {
    final existing = await _read();
    if (existing != null && existing.isNotEmpty) return existing;

    final ownerId = 'local_demo_${const Uuid().v4()}';
    await _write(ownerId);
    return ownerId;
  }

  static Future<String?> _read() async {
    try {
      final secure = await _storage.read(key: _ownerKey);
      if (secure != null && secure.isNotEmpty) return secure;
    } catch (_) {
      // iOS simulator can lack keychain entitlements; use fallback below.
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_fallbackKey);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _write(String ownerId) async {
    try {
      await _storage.write(key: _ownerKey, value: ownerId);
    } catch (_) {
      // Keep the SharedPreferences fallback authoritative for local dev.
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_fallbackKey, ownerId);
    } catch (_) {
      // The caller will keep using the in-memory id for this session.
    }
  }
}
