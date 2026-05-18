// Phase mint-data-architecture-v1-02 Plan 02-02 W1 continuation-4 P3 —
// Unit tests for offline_queue.dart.

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/audit/anonymous_session_id.dart';
import 'package:mint_mobile/services/audit/audit_buffer_db.dart';
import 'package:mint_mobile/services/audit/offline_queue.dart';

BufferedAuditRow _row(String id) => BufferedAuditRow(
      id: id,
      anonymousSessionId: generateUuidV7(),
      observedAt: DateTime.now().toUtc().add(Duration(microseconds: id.codeUnitAt(0))),
      appVersion: '2.12.3+test',
      constantsVersionHash: 'h1',
      source: 'mobile_session_start',
      payloadJson: '{}',
    );

void main() {
  group('backoffFor', () {
    test('schedule is 1/2/4/8/16/... seconds capped at 5min', () {
      expect(backoffFor(0), const Duration(seconds: 1));
      expect(backoffFor(1), const Duration(seconds: 2));
      expect(backoffFor(2), const Duration(seconds: 4));
      expect(backoffFor(3), const Duration(seconds: 8));
      expect(backoffFor(4), const Duration(seconds: 16));
      // Past the explicit schedule, cap at 5min.
      expect(backoffFor(20), const Duration(seconds: 300));
    });

    test('negative input clamps to zero', () {
      expect(backoffFor(-5), const Duration(seconds: 1));
    });
  });

  group('OfflineAuditQueue.drain', () {
    test('all succeed → all deleted from buffer', () async {
      final buffer = InMemoryAuditBufferDb();
      await buffer.insert(_row('a'));
      await buffer.insert(_row('b'));
      final queue = OfflineAuditQueue(buffer: buffer);
      final outcome = await queue.drain(sender: (_) async => true);
      expect(outcome.succeeded, 2);
      expect(outcome.failed, 0);
      expect(await buffer.pendingCount, 0);
    });

    test('all fail → retryCount bumped + nextRetryAt set', () async {
      final buffer = InMemoryAuditBufferDb();
      await buffer.insert(_row('a'));
      final queue = OfflineAuditQueue(buffer: buffer);
      final outcome = await queue.drain(sender: (_) async => false);
      expect(outcome.succeeded, 0);
      expect(outcome.failed, 1);
      // pendingCount counts ALL rows in buffer (including those with
      // future nextRetryAt). fetchPending FILTERS by nextRetryAt
      // <= now, so the failed row (next_retry_at = now + 2s) is
      // excluded from fetchPending but still present in pendingCount.
      expect(await buffer.pendingCount, 1);
      // Fetch ALL rows (with a high limit + ignore the backoff filter
      // by waiting for the backoff to elapse would slow the test).
      // Instead inspect via fetchPending with no timing-sensitive
      // assertion : just confirm the row is still there.
      // To verify retryCount + nextRetryAt without waiting, we re-fetch
      // with a long enough wait that the 2s backoff elapses :
      await Future<void>.delayed(const Duration(milliseconds: 2100));
      final pending = await buffer.fetchPending();
      expect(pending.length, 1);
      expect(pending.first.retryCount, 1);
      expect(pending.first.nextRetryAt, isNotNull);
    });

    test('sender exception treated as failure', () async {
      final buffer = InMemoryAuditBufferDb();
      await buffer.insert(_row('a'));
      final queue = OfflineAuditQueue(buffer: buffer);
      final outcome = await queue.drain(sender: (_) async {
        throw Exception('network down');
      });
      expect(outcome.failed, 1);
      expect(await buffer.pendingCount, 1);
    });

    test('TTL purge fires before drain', () async {
      final buffer = InMemoryAuditBufferDb();
      final stale = BufferedAuditRow(
        id: 'stale',
        anonymousSessionId: generateUuidV7(),
        observedAt: DateTime.now().toUtc().subtract(const Duration(days: 35)),
        appVersion: 'v',
        constantsVersionHash: 'h',
        source: 'mobile_session_start',
        payloadJson: '{}',
      );
      await buffer.insert(stale);
      await buffer.insert(_row('a'));
      final queue = OfflineAuditQueue(buffer: buffer);
      final outcome = await queue.drain(sender: (_) async => true);
      expect(outcome.purged, 1);
      expect(outcome.succeeded, 1);  // only the fresh row drained
      expect(await buffer.pendingCount, 0);
    });
  });
}
