import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class PendingAuthIdentityPersistence {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

final class SecurePendingAuthIdentityPersistence
    implements PendingAuthIdentityPersistence {
  const SecurePendingAuthIdentityPersistence({
    FlutterSecureStorage storage = const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    ),
  }) : _storage = storage;

  final FlutterSecureStorage _storage;

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
}

/// Minimized encrypted guard for identity facts written before authentication.
///
/// The email is represented by an installation-local, domain-separated HMAC.
/// Neither the normalized email nor a globally correlatable plain SHA digest is
/// persisted. The optional backend user id tightens the match after a tokenless
/// registration has resolved its exact identity.
final class PendingAuthIdentity {
  const PendingAuthIdentity({
    required this.emailFingerprint,
    this.userIdFingerprint,
  });

  final String emailFingerprint;
  final String? userIdFingerprint;
}

final class PendingAuthIdentityStore {
  const PendingAuthIdentityStore({
    PendingAuthIdentityPersistence persistence =
        const SecurePendingAuthIdentityPersistence(),
  }) : _persistence = persistence;

  static const markerKey = 'pending_auth_identity_v1';
  static const secretKey = 'pending_auth_identity_hmac_secret_v1';
  static const _version = 1;
  static const _emailHmacDomain = 'mint.pending-auth-email.v1\u0000';
  static const _userIdHmacDomain = 'mint.pending-auth-user-id.v1\u0000';
  static Future<void>? _mutationTail;
  final PendingAuthIdentityPersistence _persistence;

  Future<PendingAuthIdentity?> load() => _serialize(_loadUnlocked);

  Future<bool> matches(
    PendingAuthIdentity identity, {
    required String email,
    String? userId,
  }) =>
      _serialize(() async {
        final secret = await _readSecretRequired();
        final candidateUserId = _normalizedUserId(userId);
        if (identity.userIdFingerprint != null &&
            candidateUserId != null &&
            identity.userIdFingerprint !=
                _fingerprintUserId(secret, candidateUserId)) {
          return false;
        }
        return identity.emailFingerprint == _fingerprintEmail(secret, email);
      });

  Future<PendingAuthIdentity> bind({
    required String email,
    String? userId,
  }) =>
      _serialize(() async {
        final current = await _loadUnlocked();
        final secret = current == null
            ? await _readOrCreateSecret()
            : await _readSecretRequired();
        final fingerprint = _fingerprintEmail(secret, email);
        final normalizedUserId = _normalizedUserId(userId);
        final userIdFingerprint = normalizedUserId == null
            ? null
            : _fingerprintUserId(secret, normalizedUserId);
        if (current != null &&
            (current.emailFingerprint != fingerprint ||
                (current.userIdFingerprint != null &&
                    userIdFingerprint != null &&
                    current.userIdFingerprint != userIdFingerprint))) {
          throw StateError('Pending authentication identity mismatch');
        }
        final next = PendingAuthIdentity(
          emailFingerprint: fingerprint,
          userIdFingerprint: current?.userIdFingerprint ?? userIdFingerprint,
        );
        final encoded = jsonEncode(<String, dynamic>{
          'version': _version,
          'emailFingerprint': next.emailFingerprint,
          'userIdFingerprint': next.userIdFingerprint,
        });
        await _persistence.write(markerKey, encoded);
        if (await _persistence.read(markerKey) != encoded) {
          throw StateError('Pending authentication identity write failed');
        }
        return next;
      });

  Future<void> clearMatching({
    required String email,
    String? userId,
  }) =>
      _serialize(() async {
        final current = await _loadUnlocked();
        if (current == null) return;
        final secret = await _readSecretRequired();
        final normalizedUserId = _normalizedUserId(userId);
        if (current.emailFingerprint != _fingerprintEmail(secret, email) ||
            (current.userIdFingerprint != null &&
                (normalizedUserId == null ||
                    current.userIdFingerprint !=
                        _fingerprintUserId(secret, normalizedUserId)))) {
          throw StateError('Pending authentication identity clear mismatch');
        }
        await _deleteVerified(markerKey);
      });

  /// Terminal-session purge. The secret is installation-local and contains no
  /// identity, but deleting it with the marker makes an uncertain residual
  /// marker permanently unreadable rather than matchable by a later account.
  Future<void> clear() => _serialize(() async {
        await _deleteVerified(secretKey);
        await _deleteVerified(markerKey);
      });

  static Future<T> _serialize<T>(Future<T> Function() operation) async {
    final previous = _mutationTail;
    final completion = Completer<void>();
    final current = completion.future;
    _mutationTail = current;
    if (previous != null) await previous;
    try {
      return await operation();
    } finally {
      completion.complete();
      if (identical(_mutationTail, current)) _mutationTail = null;
    }
  }

  Future<PendingAuthIdentity?> _loadUnlocked() async {
    final raw = await _persistence.read(markerKey);
    if (raw == null) return null;
    try {
      // A marker without its installation secret is corrupt and must fail
      // closed; it can never be treated as a virgin anonymous install.
      await _readSecretRequired();
      final decoded = jsonDecode(raw);
      if (decoded is! Map) throw const FormatException('invalid marker');
      final marker = Map<String, dynamic>.from(decoded);
      final fingerprint = marker['emailFingerprint'];
      final userIdFingerprint = marker['userIdFingerprint'];
      if (marker.length != 3 ||
          marker['version'] != _version ||
          fingerprint is! String ||
          !RegExp(r'^[0-9a-f]{64}$').hasMatch(fingerprint) ||
          (userIdFingerprint != null &&
              (userIdFingerprint is! String ||
                  !RegExp(r'^[0-9a-f]{64}$').hasMatch(userIdFingerprint)))) {
        throw const FormatException('invalid marker');
      }
      return PendingAuthIdentity(
        emailFingerprint: fingerprint,
        userIdFingerprint: userIdFingerprint as String?,
      );
    } on Object {
      throw StateError('Pending authentication identity is unreadable');
    }
  }

  Future<List<int>> _readOrCreateSecret() async {
    final raw = await _persistence.read(secretKey);
    if (raw != null) return _decodeSecret(raw);
    final random = Random.secure();
    final secret = List<int>.generate(32, (_) => random.nextInt(256));
    final encoded = base64UrlEncode(secret);
    await _persistence.write(secretKey, encoded);
    if (await _persistence.read(secretKey) != encoded) {
      throw StateError('Pending authentication secret write failed');
    }
    return secret;
  }

  Future<List<int>> _readSecretRequired() async {
    final raw = await _persistence.read(secretKey);
    if (raw == null) {
      throw StateError('Pending authentication secret is missing');
    }
    return _decodeSecret(raw);
  }

  static List<int> _decodeSecret(String raw) {
    try {
      final decoded = base64Url.decode(raw);
      if (decoded.length != 32) throw const FormatException('invalid secret');
      return decoded;
    } on Object {
      throw StateError('Pending authentication secret is unreadable');
    }
  }

  static String _fingerprintEmail(List<int> secret, String email) {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty || !normalized.contains('@')) {
      throw ArgumentError.value(email, 'email', 'valid email required');
    }
    final hmac = Hmac(sha256, secret);
    return hmac.convert(utf8.encode('$_emailHmacDomain$normalized')).toString();
  }

  static String _fingerprintUserId(List<int> secret, String userId) {
    final hmac = Hmac(sha256, secret);
    return hmac.convert(utf8.encode('$_userIdHmacDomain$userId')).toString();
  }

  Future<void> _deleteVerified(String key) async {
    if (await _persistence.read(key) == null) return;
    await _persistence.delete(key);
    if (await _persistence.read(key) != null) {
      throw StateError('Pending authentication identity clear failed');
    }
  }

  static String? _normalizedUserId(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
