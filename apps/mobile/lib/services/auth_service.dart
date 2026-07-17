import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service for managing one complete authenticated session.
///
/// The current authority is a single versioned secure-storage envelope. The
/// five historical keys remain read-once migration inputs and purge targets;
/// they are never written by current code.
class AuthService {
  static const _sessionEnvelopeKey = 'auth_session_v1';
  static const recoveryRequiredKey = 'auth_session_recovery_required_v1';
  static const _sessionEnvelopeVersion = 1;

  static const _tokenKey = 'jwt_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _userIdKey = 'user_id';
  static const _userEmailKey = 'user_email';
  static const _displayNameKey = 'display_name';

  static const _legacyCredentialKeys = <String>{
    _tokenKey,
    _refreshTokenKey,
    _userIdKey,
    _userEmailKey,
    _displayNameKey,
  };

  static const _sessionCredentialKeys = <String>{
    _sessionEnvelopeKey,
    recoveryRequiredKey,
    ..._legacyCredentialKeys,
  };

  static const _purgeableCredentialKeys = <String>{
    _sessionEnvelopeKey,
    ..._legacyCredentialKeys,
  };

  /// Allows the termination coordinator to clear every other secure value
  /// while keeping credentials intact until the purge transaction succeeds.
  static bool isSessionCredentialKey(String key) =>
      _sessionCredentialKeys.contains(key);

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static Future<AuthSessionEnvelope?>? _inFlightSessionRead;
  static Future<void>? _sessionMutationTail;

  /// Replaces the complete session in one secure-storage write.
  ///
  /// Validation happens before the write, so a rejected or failed replacement
  /// leaves the exact prior envelope authoritative.
  static Future<void> saveToken(
    String token,
    String userId,
    String email, {
    String? displayName,
    String? refreshToken,
  }) {
    final session = AuthSessionEnvelope(
      accessToken: token,
      refreshToken: refreshToken,
      userId: userId,
      email: email,
      displayName: displayName,
    );
    session.validate();
    return _serializeSessionMutation(() async {
      final current = await _readCompleteSession();
      if (current != null && !current.hasSameIdentity(session)) {
        throw StateError(
          'Active authentication identity must be terminated before replacement',
        );
      }
      await _storage.write(
        key: _sessionEnvelopeKey,
        value: jsonEncode(session.toJson()),
      );
    });
  }

  /// Get stored access token (null if no complete session exists).
  static Future<String?> getToken() async =>
      (await readSessionEnvelope())?.accessToken;

  /// Get stored refresh token.
  static Future<String?> getRefreshToken() async =>
      (await readSessionEnvelope())?.refreshToken;

  /// Get stored user ID.
  static Future<String?> getUserId() async =>
      (await readSessionEnvelope())?.userId;

  /// Get stored email.
  static Future<String?> getUserEmail() async =>
      (await readSessionEnvelope())?.email;

  /// Get stored display name.
  static Future<String?> getDisplayName() async =>
      (await readSessionEnvelope())?.displayName;

  /// Logged-in means a fully validated identity, never merely a token.
  static Future<bool> isLoggedIn() async => await readSessionEnvelope() != null;

  /// Reads one atomic, validated authority envelope for an auth transaction.
  ///
  /// Transport refresh must capture identity and credentials together. Reading
  /// the historical scalar getters independently would permit a token from one
  /// envelope to be combined with the identity from another rotation.
  static Future<AuthSessionEnvelope?> readSessionEnvelope() =>
      _readCompleteSession();

  /// Low-level credential clear used only by the termination coordinator.
  ///
  /// Both the current envelope and every legacy migration input are removed
  /// and verified absent. A partial platform purge throws and leaves the
  /// coordinator's termination tombstone blocking account re-entry.
  static Future<void> clearTokensForSessionTermination() =>
      _serializeSessionMutation(() async {
        await _deleteKeys(_purgeableCredentialKeys);
        final residual = await Future.wait<String?>([
          for (final key in _purgeableCredentialKeys) _storage.read(key: key),
        ]);
        if (residual.any((value) => value != null)) {
          throw StateError('Authentication credential purge failed');
        }
      });

  /// Final recovery step owned by the session termination coordinator.
  ///
  /// The marker deliberately survives credential/data purge failures. It is
  /// removed only after every earlier terminal-session step has succeeded.
  static Future<void> clearRecoveryRequiredForSessionTermination() =>
      _serializeSessionMutation(() async {
        await _storage.delete(key: recoveryRequiredKey);
        if (await _storage.read(key: recoveryRequiredKey) != null) {
          throw StateError('Authentication recovery marker purge failed');
        }
      });

  static Future<T> _serializeSessionMutation<T>(
    Future<T> Function() operation,
  ) async {
    final previous = _sessionMutationTail;
    final completion = Completer<void>();
    final current = completion.future;
    _sessionMutationTail = current;
    if (previous != null) await previous;
    try {
      return await operation();
    } finally {
      completion.complete();
      if (identical(_sessionMutationTail, current)) {
        _sessionMutationTail = null;
      }
    }
  }

  static Future<AuthSessionEnvelope?> _readCompleteSession() {
    final existing = _inFlightSessionRead;
    if (existing != null) return existing;
    late final Future<AuthSessionEnvelope?> operation;
    operation = _readCompleteSessionInternal().whenComplete(() {
      if (identical(_inFlightSessionRead, operation)) {
        _inFlightSessionRead = null;
      }
    });
    _inFlightSessionRead = operation;
    return operation;
  }

  static Future<AuthSessionEnvelope?> _readCompleteSessionInternal() async {
    if (await _storage.read(key: recoveryRequiredKey) != null) {
      throw const AuthSessionRecoveryRequired();
    }
    final envelope = await _storage.read(key: _sessionEnvelopeKey);
    if (envelope != null) {
      try {
        final decoded = jsonDecode(envelope);
        if (decoded is! Map) throw const FormatException('invalid envelope');
        final session = AuthSessionEnvelope.fromJson(
          Map<String, dynamic>.from(decoded),
        );
        session.validate();
        return session;
      } catch (_) {
        await _markRecoveryRequired();
        throw const AuthSessionRecoveryRequired();
      }
    }

    final values = await Future.wait<String?>([
      _storage.read(key: _tokenKey),
      _storage.read(key: _refreshTokenKey),
      _storage.read(key: _userIdKey),
      _storage.read(key: _userEmailKey),
      _storage.read(key: _displayNameKey),
    ]);
    if (values.every((value) => value == null)) return null;

    final legacy = AuthSessionEnvelope(
      accessToken: values[0] ?? '',
      refreshToken: values[1],
      userId: values[2] ?? '',
      email: values[3] ?? '',
      displayName: values[4],
    );
    try {
      legacy.validate();
    } catch (_) {
      await _markRecoveryRequired();
      throw const AuthSessionRecoveryRequired();
    }

    // One new-key write first: if it fails, the exact complete legacy session
    // remains available for a later migration attempt.
    await _storage.write(
      key: _sessionEnvelopeKey,
      value: jsonEncode(legacy.toJson()),
    );
    for (final key in _legacyCredentialKeys) {
      await _storage.delete(key: key);
    }
    return legacy;
  }

  static Future<void> _markRecoveryRequired() async {
    await _storage.write(key: recoveryRequiredKey, value: '1');
    if (await _storage.read(key: recoveryRequiredKey) != '1') {
      throw StateError('Authentication recovery marker write failed');
    }
  }

  static Future<void> _deleteKeys(Set<String> keys) async {
    for (final key in keys) {
      await _storage.delete(key: key);
    }
  }
}

/// A durable fail-closed state: credentials existed but could not be trusted.
///
/// Callers must run the terminal-session coordinator. Treating this as an
/// ordinary anonymous install could expose the prior account's local ledger to
/// a later identity.
final class AuthSessionRecoveryRequired implements Exception {
  const AuthSessionRecoveryRequired();

  @override
  String toString() => 'AuthSessionRecoveryRequired';
}

/// Complete authenticated authority stored in one secure envelope.
///
/// The type is immutable so refresh code can compare the server response with
/// the exact pre-refresh identity before any token rotation is persisted.
final class AuthSessionEnvelope {
  const AuthSessionEnvelope({
    required this.accessToken,
    required this.userId,
    required this.email,
    this.refreshToken,
    this.displayName,
  });

  final String accessToken;
  final String? refreshToken;
  final String userId;
  final String email;
  final String? displayName;

  bool hasSameIdentity(AuthSessionEnvelope other) =>
      userId == other.userId && email == other.email;

  factory AuthSessionEnvelope.fromJson(Map<String, dynamic> json) {
    if (json['version'] != AuthService._sessionEnvelopeVersion) {
      throw const FormatException('unsupported auth session version');
    }
    return AuthSessionEnvelope(
      accessToken: json['accessToken'] as String? ?? '',
      refreshToken: json['refreshToken'] as String?,
      userId: json['userId'] as String? ?? '',
      email: json['email'] as String? ?? '',
      displayName: json['displayName'] as String?,
    );
  }

  void validate() {
    if (accessToken.trim().isEmpty) {
      throw ArgumentError.value(accessToken, 'token', 'must be non-empty');
    }
    if (userId.trim().isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'must be non-empty');
    }
    if (email.trim().isEmpty) {
      throw ArgumentError.value(email, 'email', 'must be non-empty');
    }
    if (refreshToken != null && refreshToken!.trim().isEmpty) {
      throw ArgumentError.value(
        refreshToken,
        'refreshToken',
        'must be null or non-empty',
      );
    }
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'version': AuthService._sessionEnvelopeVersion,
        'accessToken': accessToken,
        if (refreshToken != null) 'refreshToken': refreshToken,
        'userId': userId,
        'email': email,
        if (displayName != null) 'displayName': displayName,
      };
}
