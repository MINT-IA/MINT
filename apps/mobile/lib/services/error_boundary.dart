/// Global error boundary — single allowed source of Sentry.captureException
/// in apps/mobile/lib/. Enforced by tools/checks/sentry_capture_single_source.py.
///
/// Phase 31 OBS-02 (Wave 1, Plan 31-01).
///
/// Contract:
///   - PlatformDispatcher.onError is set FIRST (Flutter 3.3+ ordering —
///     catches async / MethodChannel / uncaught futures before the
///     framework has boxed them).
///   - FlutterError.onError is set SECOND (captures build/layout/paint).
///   - Isolate.current.addErrorListener is attached THIRD (captures
///     spawned isolates — compute(), async generators).
///   - Each prong routes its error through the PRIVATE `_capture()` helper
///     exactly once (single-capture invariant — OBS-02 b / A3 PITFALLS.md).
///   - NO `runZonedGuarded` (rejected per D-A3 + Panel A; deprecated in
///     sentry_flutter 8+).
///
/// `installGlobalErrorBoundary()` MUST be called from `main()` AFTER
/// `WidgetsFlutterBinding.ensureInitialized()` and BEFORE
/// `SentryFlutter.init(...)` so that the Sentry SDK attaches to handlers
/// that are already live.
///
/// `captureSwallowedException` is the ONE allowed escape hatch for
/// fallback widgets (e.g. MintErrorScreen) that render a "something
/// broke" surface to the user. Events are tagged `swallowed:true` so
/// ops can audit them in Sentry.
library;

import 'dart:async';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Internal reentrancy guard — prevents double-capture when a thrown
/// error transits multiple prongs (e.g. a framework error surfacing
/// via both FlutterError.onError and PlatformDispatcher.onError). Keyed
/// on identity so distinct but equal errors still report.
final Set<int> _inflight = <int>{};

/// Install the 3-prong global error boundary.
///
/// Idempotent — subsequent calls re-install (tests may call this several
/// times). Previous handlers are replaced; the Flutter framework has no
/// documented handler-chaining contract, so we take full ownership.
void installGlobalErrorBoundary() {
  // 1. PlatformDispatcher.onError — async platform errors (must be FIRST).
  //    Return true = handled, framework continues running.
  PlatformDispatcher.instance.onError = (error, stack) {
    _capture(error, stack, origin: 'platform_dispatcher');
    return true;
  };

  // 2. FlutterError.onError — framework errors (build / layout / paint).
  //    FlutterError.presentError(details) keeps the red screen in debug.
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    _capture(
      details.exception,
      details.stack ?? StackTrace.current,
      origin: 'flutter_error',
    );
  };

  // 3. Isolate errors — spawned isolates (compute(), async generators).
  //    The receive port lives for the process lifetime; do not close.
  Isolate.current.addErrorListener(
    RawReceivePort((dynamic pair) {
      final list = pair as List<dynamic>;
      final error = list.first as Object;
      final stackRepr = list.last;
      final stack = stackRepr is String
          ? StackTrace.fromString(stackRepr)
          : (stackRepr is StackTrace ? stackRepr : StackTrace.current);
      _capture(error, stack, origin: 'isolate');
    }).sendPort,
  );
}

/// Single entry-point for every prong — guarantees exactly-once capture
/// per thrown error identity (OBS-02 b single-capture invariant).
Future<void> _capture(
  Object error,
  StackTrace stack, {
  required String origin,
}) async {
  final key = identityHashCode(error);
  if (_inflight.contains(key)) {
    return; // reentrant — some other prong already dispatched this error.
  }
  _inflight.add(key);
  try {
    await Sentry.captureException(
      error,
      stackTrace: stack,
      withScope: (scope) {
        scope.setTag('error_origin', origin);
      },
    );
  } finally {
    // Drop guard on next microtask so legitimate re-throws do not coalesce.
    scheduleMicrotask(() => _inflight.remove(key));
  }
}

/// Single allowed swallow path — used by fallback widgets (MintErrorScreen
/// etc.) that render a degraded UI surface rather than crashing.
/// Events are tagged `swallowed:true` so ops can audit the swallow set
/// in Sentry UI.
Future<void> captureSwallowedException(
  Object error,
  StackTrace stack, {
  String? surface,
}) {
  return Sentry.captureException(
    error,
    stackTrace: stack,
    withScope: (scope) {
      scope.setTag('swallowed', 'true');
      if (surface != null) {
        scope.setTag('surface', surface);
      }
    },
  );
}
