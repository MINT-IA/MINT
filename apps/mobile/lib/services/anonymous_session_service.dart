import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

/// Manages the anonymous session: device-scoped UUID and message counter.
///
/// The session ID persists across app kills (SecureStorage = Keychain/Keystore).
/// Message count is synced from backend responses (single source of truth).
/// After account creation, [clearSession] wipes both keys.
class AnonymousSessionService {
  static const _sessionKey = 'anonymous_session_id';
  static const _messageCountKey = 'anonymous_message_count';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  /// Returns existing session ID or creates a new UUID v4.
  ///
  /// The ID is device-scoped and survives app kills.
  static Future<String> getOrCreateSessionId() async {
    final existing = await _storage.read(key: _sessionKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final newId = const Uuid().v4();
    await _storage.write(key: _sessionKey, value: newId);
    return newId;
  }

  /// Returns current message count (0 if never set).
  static Future<int> getMessageCount() async {
    final raw = await _storage.read(key: _messageCountKey);
    if (raw == null) return 0;
    return int.tryParse(raw) ?? 0;
  }

  /// Updates local message count from backend's messagesRemaining.
  ///
  /// Backend returns messagesRemaining (0-2). Count = 3 - remaining.
  static Future<void> updateFromResponse(int messagesRemaining) async {
    final count = 3 - messagesRemaining.clamp(0, 3);
    await _storage.write(key: _messageCountKey, value: count.toString());
  }

  /// Whether the user can still send a message (count < 3).
  static Future<bool> canSendMessage() async {
    final count = await getMessageCount();
    return count < 3;
  }

  /// Clears session ID and message count (call after account creation).
  static Future<void> clearSession() async {
    await _storage.delete(key: _sessionKey);
    await _storage.delete(key: _messageCountKey);
  }
}
