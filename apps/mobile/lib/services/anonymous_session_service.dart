import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Manages the anonymous session: device-scoped UUID and message counter.
///
/// The session ID persists across app kills (SecureStorage = Keychain/Keystore).
/// Message count is synced from backend responses (single source of truth).
/// After account creation, [clearSession] wipes both keys.
///
/// Fallback 2026-04-18 (Wave 5 QA) : keychain fails on iOS simulator with
/// `PlatformException -34018` ("L'un des droits requis n'est pas présent")
/// because the sim process isn't signed with a keychain-sharing entitlement.
/// When SecureStorage throws, we fall back to SharedPreferences so the
/// anonymous chat tier keeps working locally — the session UUID is only
/// mildly sensitive (it's a rate-limit key, not a secret).
class AnonymousSessionService {
  static const _sessionKey = 'anonymous_session_id';
  static const _messageCountKey = 'anonymous_message_count';

  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  /// Read from secure storage, fall back to SharedPreferences on keychain
  /// error (sim build). Returns null if neither store has the value.
  static Future<String?> _read(String key) async {
    try {
      final v = await _secureStorage.read(key: key);
      if (v != null && v.isNotEmpty) return v;
    } catch (_) {
      // keychain failure on sim — fall through
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('anonfb_$key');
    } catch (_) {
      return null;
    }
  }

  /// Write to BOTH stores. Secure is attempted first; SharedPreferences is
  /// always written so a secure failure doesn't drop the value.
  static Future<void> _write(String key, String value) async {
    try {
      await _secureStorage.write(key: key, value: value);
    } catch (_) {
      // sim keychain failure — SharedPreferences is our fallback
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('anonfb_$key', value);
    } catch (_) {
      // both failed — value lost, caller will treat as missing
    }
  }

  static Future<void> _delete(String key) async {
    try {
      await _secureStorage.delete(key: key);
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('anonfb_$key');
    } catch (_) {}
  }

  /// Returns existing session ID or creates a new UUID v4.
  ///
  /// The ID is device-scoped and survives app kills.
  static Future<String> getOrCreateSessionId() async {
    final existing = await _read(_sessionKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final newId = const Uuid().v4();
    await _write(_sessionKey, newId);
    return newId;
  }

  /// Returns current message count (0 if never set).
  static Future<int> getMessageCount() async {
    final raw = await _read(_messageCountKey);
    if (raw == null) return 0;
    return int.tryParse(raw) ?? 0;
  }

  /// Updates local message count from backend's messagesRemaining.
  ///
  /// Backend returns messagesRemaining (0-2). Count = 3 - remaining.
  static Future<void> updateFromResponse(int messagesRemaining) async {
    final count = 3 - messagesRemaining.clamp(0, 3);
    await _write(_messageCountKey, count.toString());
  }

  /// Whether the user can still send a message (count < 3).
  static Future<bool> canSendMessage() async {
    final count = await getMessageCount();
    return count < 3;
  }

  /// Clears session ID and message count (call after account creation).
  static Future<void> clearSession() async {
    await _delete(_sessionKey);
    await _delete(_messageCountKey);
  }
}
