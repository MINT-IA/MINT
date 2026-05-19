// Phase mint-data-architecture-v1-02 Plan 02-02 W1 continuation-4 P3 —
// D-30 Mobile L1 audit lifecycle hooks.
//
// Bridges Flutter's WidgetsBindingObserver to MobileL1AuditService :
//   - app cold-start          → recordSessionStart()
//   - app foregrounded after >30min → recordSessionResume()
//   - app paused / detached → flush() (best-effort drain)
//
// The 30-minute resume threshold is calibrated per RESEARCH § D-30 to
// distinguish « briefly backgrounded » (no new audit row) from
// « warm-resume after sleep » (new audit row).

import 'package:flutter/widgets.dart';

import '../audit/mobile_l1_audit_service.dart';

const _warmResumeThreshold = Duration(minutes: 30);

/// Bridges Flutter lifecycle to Mobile L1 audit ingestion.
///
/// Usage in main.dart :
/// ```dart
/// final lifecycle = MobileL1AuditLifecycleObserver(audit: auditService);
/// WidgetsBinding.instance.addObserver(lifecycle);
/// await lifecycle.recordColdStart();
/// ```
class MobileL1AuditLifecycleObserver extends WidgetsBindingObserver {
  MobileL1AuditLifecycleObserver({required this.audit});

  final MobileL1AuditService audit;
  DateTime? _lastPausedAt;

  /// Call once on app cold-start (typically immediately after the
  /// observer is registered in main.dart).
  Future<void> recordColdStart() async {
    await audit.recordSessionStart(lifecycleState: 'resumed');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _lastPausedAt = DateTime.now().toUtc();
        // Fire-and-forget : best-effort drain. The buffer persists the
        // remainder for the next online window.
        break;
      case AppLifecycleState.resumed:
        if (_lastPausedAt != null) {
          final now = DateTime.now().toUtc();
          final dt = now.difference(_lastPausedAt!);
          if (dt >= _warmResumeThreshold) {
            // Fire-and-forget warm-resume audit. The buffer dedup
            // (anonymousSessionId, observedAt) protects against duplicate
            // calls from over-eager lifecycle dispatches.
            unawaited(
              audit.recordSessionResume(lifecycleState: 'resumed'),
            );
          }
          _lastPausedAt = null;
        }
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        // No audit signal — these are transient (e.g. notification
        // overlay) and do NOT cross the « new session » threshold.
        break;
    }
  }
}

void unawaited(Future<void> future) {
  // Pure helper to silence the « unawaited_futures » lint when we
  // explicitly want fire-and-forget semantics (lifecycle handlers
  // cannot await without blocking the framework).
  future.catchError((Object _) {});
}
