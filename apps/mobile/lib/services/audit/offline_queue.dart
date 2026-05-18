// Phase mint-data-architecture-v1-02 Plan 02-02 W1 continuation-4 P3 —
// D-30 offline queue for Mobile L1 audit replay.
//
// Wraps an `AuditBufferDb` with exponential-backoff retry logic.
// Backoff schedule : 1s / 2s / 4s / 8s / 16s, capped at 5 minutes
// (per RESEARCH § D-30 Pitfall 6).
//
// The queue does NOT itself perform HTTP — it surfaces an iterable of
// `BufferedAuditRow` ready-to-send rows and an `onSuccess(id) /
// onFailure(id, error)` callback contract. The HTTP layer
// (`MobileL1AuditService`) wires these into the actual POST.

import 'dart:async';

import 'audit_buffer_db.dart';

/// Exponential-backoff schedule per RFC 9562 § D-30 Pitfall 6 :
/// [1s, 2s, 4s, 8s, 16s] capped at 5 minutes.
const _backoffSeconds = [1, 2, 4, 8, 16, 32, 60, 120, 300];

/// Cap (5 minutes per Pitfall 6).
const _backoffCapSeconds = 300;

/// Returns the next-retry duration for a given retry count (0-based).
Duration backoffFor(int retryCount) {
  if (retryCount < 0) retryCount = 0;
  final idx = retryCount.clamp(0, _backoffSeconds.length - 1);
  final secs = _backoffSeconds[idx];
  return Duration(seconds: secs.clamp(1, _backoffCapSeconds));
}

/// Result of one queue-drain attempt.
class DrainOutcome {
  DrainOutcome({this.succeeded = 0, this.failed = 0, this.purged = 0});
  final int succeeded;
  final int failed;
  final int purged;
}

/// Offline-replay queue : drains pending rows from the buffer via a
/// caller-supplied `sender(row) -> Future<bool>` callback.
class OfflineAuditQueue {
  OfflineAuditQueue({
    required this.buffer,
    this.ttl = const Duration(days: 30),
  });

  final AuditBufferDb buffer;
  final Duration ttl;

  /// Drain up to `limit` rows. The `sender` callback returns `true` on
  /// successful upload (row is deleted), `false` on failure (row's
  /// retry_count++ and next_retry_at scheduled per `backoffFor`).
  ///
  /// Returns a [DrainOutcome] summarising the pass.
  Future<DrainOutcome> drain({
    required Future<bool> Function(BufferedAuditRow row) sender,
    int limit = 50,
  }) async {
    final purged = await buffer.purgeOlderThan(ttl);
    final rows = await buffer.fetchPending(limit: limit);
    int ok = 0;
    int fail = 0;
    for (final row in rows) {
      bool delivered = false;
      try {
        delivered = await sender(row);
      } catch (_) {
        delivered = false;
      }
      if (delivered) {
        await buffer.delete(row.id);
        ok += 1;
      } else {
        row.retryCount += 1;
        row.nextRetryAt = DateTime.now().toUtc().add(backoffFor(row.retryCount));
        // Re-insert via the buffer interface (in-memory impl re-applies
        // dedup ; a real impl would UPDATE).
        await buffer.insert(row);
        fail += 1;
      }
    }
    return DrainOutcome(succeeded: ok, failed: fail, purged: purged);
  }
}
