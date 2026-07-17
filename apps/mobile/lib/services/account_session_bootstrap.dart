import 'package:flutter/foundation.dart';
import 'package:mint_mobile/services/session_epoch.dart';

typedef AccountSessionInitialization = Future<void> Function(
  SessionEpochGuard guard,
);

/// One named account-scoped initialization edge in the composition root.
final class AccountSessionInitializer {
  const AccountSessionInitializer(
    this.name,
    this.initialize, {
    this.stage = 0,
    this.requiresAuthentication = false,
  }) : assert(stage >= 0);

  final String name;
  final AccountSessionInitialization initialize;
  final int stage;
  final bool requiresAuthentication;
}

/// Global cold-start barrier between auth/session recovery and providers.
///
/// Provider constructors remain pure. In particular, no local hydration,
/// secure-storage read, or network request starts until the auth provider has
/// resumed a pending session-termination tombstone and published its decision.
final class AccountSessionBootstrap {
  AccountSessionBootstrap({
    required SessionEpoch sessionEpoch,
    required Future<void> Function() resolveInitialAuth,
    required bool Function() isAuthReady,
    required bool Function() isAuthenticated,
    required List<AccountSessionInitializer> initializers,
  })  : _sessionEpoch = sessionEpoch,
        _resolveInitialAuth = resolveInitialAuth,
        _isAuthReady = isAuthReady,
        _isAuthenticated = isAuthenticated,
        _initializers = List.unmodifiable(initializers);

  final SessionEpoch _sessionEpoch;
  final Future<void> Function() _resolveInitialAuth;
  final bool Function() _isAuthReady;
  final bool Function() _isAuthenticated;
  final List<AccountSessionInitializer> _initializers;

  Future<void>? _inFlight;
  Future<void>? _queuedAfterInFlight;
  int? _resolvedAuthGeneration;
  int? _initializedLocalGeneration;
  int? _initializedAuthenticatedGeneration;
  Listenable? _authListenable;

  void bindAuth(Listenable auth) {
    if (identical(_authListenable, auth)) return;
    _authListenable?.removeListener(retryAfterAuthChange);
    _authListenable = auth;
    auth.addListener(retryAfterAuthChange);
  }

  Future<void> start() {
    if (_isInitializedForCurrentAuthority()) {
      return Future.value();
    }
    final existing = _inFlight;
    if (existing != null) {
      final queued = _queuedAfterInFlight;
      if (queued != null) return queued;
      late final Future<void> retry;
      retry = existing.then((_) => start()).whenComplete(() {
        if (identical(_queuedAfterInFlight, retry)) {
          _queuedAfterInFlight = null;
        }
      });
      _queuedAfterInFlight = retry;
      return retry;
    }
    late final Future<void> operation;
    // Defer execution until `_inFlight` is published. Auth resolution may
    // notify listeners synchronously before its first suspension point; a
    // reentrant listener must join this operation rather than launch another.
    operation = Future<void>.microtask(_start).whenComplete(() {
      if (identical(_inFlight, operation)) _inFlight = null;
    });
    _inFlight = operation;
    return operation;
  }

  /// Auth listener edge used when a blocked cold recovery is retried.
  void retryAfterAuthChange() {
    if (_isAuthReady()) start().ignore();
  }

  void dispose() {
    _authListenable?.removeListener(retryAfterAuthChange);
    _authListenable = null;
  }

  Future<void> _start() async {
    final generationBeforeAuth = _sessionEpoch.generation;
    if (_resolvedAuthGeneration != generationBeforeAuth || !_isAuthReady()) {
      await _resolveInitialAuth();
    }
    if (!_isAuthReady()) return;

    final guard = _sessionEpoch.capture();
    final generation = _sessionEpoch.generation;
    try {
      guard.assertCurrent();
      _resolvedAuthGeneration = generation;
      final authenticated = _isAuthenticated();
      final initializeLocal = _initializedLocalGeneration != generation;
      final initializeAuthenticated =
          authenticated && _initializedAuthenticatedGeneration != generation;
      final eligible = _initializers.where((initializer) {
        return initializer.requiresAuthentication
            ? initializeAuthenticated
            : initializeLocal;
      }).toList(growable: false);
      final orderedStages = eligible
          .map((initializer) => initializer.stage)
          .toSet()
          .toList()
        ..sort();
      for (final stage in orderedStages) {
        guard.assertCurrent();
        await Future.wait(
          _initializers
              .where(eligible.contains)
              .where((initializer) => initializer.stage == stage)
              .map((initializer) => _initialize(initializer, guard)),
        );
        guard.assertCurrent();
      }
      if (initializeLocal) _initializedLocalGeneration = generation;
      if (initializeAuthenticated) {
        _initializedAuthenticatedGeneration = generation;
      }
    } on SessionEpochInvalidated {
      // Session termination owns the next bootstrap attempt.
    }
  }

  bool _isInitializedForCurrentAuthority() {
    final generation = _sessionEpoch.generation;
    if (_initializedLocalGeneration != generation) return false;
    return !_isAuthenticated() ||
        _initializedAuthenticatedGeneration == generation;
  }

  Future<void> _initialize(
    AccountSessionInitializer initializer,
    SessionEpochGuard guard,
  ) async {
    guard.assertCurrent();
    try {
      await initializer.initialize(guard);
      guard.assertCurrent();
    } on SessionEpochInvalidated {
      rethrow;
    } on Object {
      // Account providers keep their own typed recovery state. One
      // unavailable local store or endpoint must not starve unrelated
      // providers after the global session barrier has opened.
    }
  }
}
