import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class LocalDataClaimAttemptPersistence {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

final class SecureLocalDataClaimAttemptPersistence
    implements LocalDataClaimAttemptPersistence {
  const SecureLocalDataClaimAttemptPersistence({
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

final class LocalDataClaimAttempt {
  const LocalDataClaimAttempt({
    required this.payloadFingerprint,
    required this.deviceId,
    required this.updatedAt,
  });

  final String payloadFingerprint;
  final String deviceId;
  final DateTime updatedAt;
}

/// Encrypted idempotency envelope for one semantic local-data claim.
///
/// A retry of identical financial facts reuses the exact device/timestamp.
/// Changed facts get a new timestamp so backend last-write-wins ordering still
/// represents the data revision rather than the transport retry time.
final class LocalDataClaimAttemptStore {
  const LocalDataClaimAttemptStore({
    LocalDataClaimAttemptPersistence persistence =
        const SecureLocalDataClaimAttemptPersistence(),
    DateTime Function() now = DateTime.now,
  })  : _persistence = persistence,
        _now = now;

  static const markerKey = 'local_data_claim_attempt_v1';
  static const secretKey = 'local_data_claim_attempt_hmac_secret_v1';
  static const _version = 1;
  static const _domain = 'mint.local-data-claim-payload.v1\u0000';
  static Future<void>? _mutationTail;

  final LocalDataClaimAttemptPersistence _persistence;
  final DateTime Function() _now;

  Future<LocalDataClaimAttempt> resolve({
    required String deviceId,
    required Map<String, dynamic> payload,
  }) =>
      _serialize(() async {
        final current = await _loadUnlocked();
        final secret = current == null
            ? await _readOrCreateSecret()
            : await _readSecretRequired();
        final fingerprint = _fingerprint(secret, payload);
        if (current != null &&
            current.deviceId == deviceId &&
            current.payloadFingerprint == fingerprint) {
          return current;
        }
        final now = _now().toUtc();
        final updatedAt = current == null || now.isAfter(current.updatedAt)
            ? now
            : current.updatedAt.add(const Duration(microseconds: 1));
        final next = LocalDataClaimAttempt(
          payloadFingerprint: fingerprint,
          deviceId: deviceId,
          updatedAt: updatedAt,
        );
        final encoded = jsonEncode({
          'version': _version,
          'payloadFingerprint': next.payloadFingerprint,
          'deviceId': next.deviceId,
          'updatedAt': next.updatedAt.toIso8601String(),
        });
        await _persistence.write(markerKey, encoded);
        if (await _persistence.read(markerKey) != encoded) {
          throw StateError('Claim attempt write failed');
        }
        return next;
      });

  Future<void> clearMatching(LocalDataClaimAttempt attempt) =>
      _serialize(() async {
        final current = await _loadUnlocked();
        if (current == null) return;
        if (current.deviceId != attempt.deviceId ||
            current.payloadFingerprint != attempt.payloadFingerprint ||
            current.updatedAt != attempt.updatedAt) {
          throw StateError('Claim attempt clear mismatch');
        }
        await _persistence.delete(markerKey);
        if (await _persistence.read(markerKey) != null) {
          throw StateError('Claim attempt clear failed');
        }
      });

  /// Terminal-session purge. Delete the secret first so a partial failure
  /// leaves any residual marker unreadable and therefore fail-closed.
  Future<void> clear() => _serialize(() async {
        await _deleteVerified(secretKey);
        await _deleteVerified(markerKey);
      });

  Future<LocalDataClaimAttempt?> _loadUnlocked() async {
    final raw = await _persistence.read(markerKey);
    if (raw == null) return null;
    try {
      await _readSecretRequired();
      final decoded = jsonDecode(raw);
      if (decoded is! Map) throw const FormatException('invalid attempt');
      final map = Map<String, dynamic>.from(decoded);
      final fingerprint = map['payloadFingerprint'];
      final deviceId = map['deviceId'];
      final updatedAt = DateTime.tryParse(map['updatedAt']?.toString() ?? '');
      if (map.length != 4 ||
          map['version'] != _version ||
          fingerprint is! String ||
          !RegExp(r'^[0-9a-f]{64}$').hasMatch(fingerprint) ||
          deviceId is! String ||
          deviceId.isEmpty ||
          updatedAt == null) {
        throw const FormatException('invalid attempt');
      }
      return LocalDataClaimAttempt(
        payloadFingerprint: fingerprint,
        deviceId: deviceId,
        updatedAt: updatedAt.toUtc(),
      );
    } on Object {
      throw StateError('Claim attempt is unreadable');
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
      throw StateError('Claim attempt secret write failed');
    }
    return secret;
  }

  Future<void> _deleteVerified(String key) async {
    if (await _persistence.read(key) == null) return;
    await _persistence.delete(key);
    if (await _persistence.read(key) != null) {
      throw StateError('Claim attempt clear failed');
    }
  }

  Future<List<int>> _readSecretRequired() async {
    final raw = await _persistence.read(secretKey);
    if (raw == null) throw StateError('Claim attempt secret is missing');
    return _decodeSecret(raw);
  }

  static List<int> _decodeSecret(String raw) {
    try {
      final decoded = base64Url.decode(raw);
      if (decoded.length != 32) throw const FormatException('invalid secret');
      return decoded;
    } on Object {
      throw StateError('Claim attempt secret is unreadable');
    }
  }

  static String _fingerprint(
    List<int> secret,
    Map<String, dynamic> payload,
  ) {
    final canonical = jsonEncode(_canonicalize(payload));
    return Hmac(sha256, secret)
        .convert(utf8.encode('$_domain$canonical'))
        .toString();
  }

  static dynamic _canonicalize(dynamic value) {
    if (value is Map) {
      final keys = value.keys.map((key) => key.toString()).toList()..sort();
      return <String, dynamic>{
        for (final key in keys) key: _canonicalize(value[key]),
      };
    }
    if (value is List) return value.map(_canonicalize).toList();
    return value;
  }

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
}
