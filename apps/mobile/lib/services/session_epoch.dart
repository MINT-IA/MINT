import 'dart:async';

/// Thrown when work captured by an older account session tries to cross a
/// persistence or publication boundary.
final class SessionEpochInvalidated implements Exception {
  const SessionEpochInvalidated();

  @override
  String toString() => 'Account session changed while the operation was active';
}

/// Immutable capability captured at the beginning of account-scoped work.
final class SessionEpochGuard {
  SessionEpochGuard._(this._owner, this._generation);

  final SessionEpoch _owner;
  final int _generation;

  void assertCurrent() => _owner._assertCurrent(_generation);
}

/// Global account-session generation and persistence serialization boundary.
///
/// Termination invalidates every existing guard synchronously. Persistence
/// already admitted before invalidation is drained before the purge starts;
/// persistence arriving later is rejected. This closes both possible orders:
/// old-write→purge and terminate→late-old-write.
final class SessionEpoch {
  int _generation = 0;
  bool _terminationBlocked = false;
  Future<void> _persistenceTail = Future<void>.value();

  bool get isTerminationBlocked => _terminationBlocked;

  /// Monotonic account-session revision for composition-root re-bootstrap.
  int get generation => _generation;

  SessionEpochGuard capture() {
    if (_terminationBlocked) throw const SessionEpochInvalidated();
    return SessionEpochGuard._(this, _generation);
  }

  void beginTermination() {
    if (_terminationBlocked) return;
    _generation++;
    _terminationBlocked = true;
  }

  void completeTermination() {
    if (!_terminationBlocked) {
      throw StateError('Session termination was not active');
    }
    _terminationBlocked = false;
  }

  void _assertCurrent(int generation) {
    if (_terminationBlocked || generation != _generation) {
      throw const SessionEpochInvalidated();
    }
  }

  Future<T> runGuardedPersistence<T>(
    SessionEpochGuard guard,
    Future<T> Function() operation,
  ) async {
    final previous = _persistenceTail;
    final completion = Completer<void>();
    _persistenceTail = completion.future;
    await previous;
    try {
      guard.assertCurrent();
      final result = await operation();
      return result;
    } finally {
      completion.complete();
    }
  }

  Future<void> drainPersistence() async {
    final admitted = _persistenceTail;
    await admitted;
  }
}
