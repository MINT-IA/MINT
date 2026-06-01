// Phase mint-data-architecture-v1-02 Plan 02-02 W1 continuation-4 P3 —
// Unit tests for mobile_l1_audit_service.dart.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/audit/anonymous_session_id.dart';
import 'package:mint_mobile/services/audit/mobile_l1_audit_service.dart';

void main() {
  group('MobileL1AuditService.inMemory factory', () {
    test('produces a valid UUID v7 anonymous_session_id', () {
      final svc = MobileL1AuditService.inMemory(
        appVersion: '2.12.3+test',
        constantsVersionHash: 'h1',
      );
      expect(isUuidV7(svc.anonymousSessionId), isTrue);
    });
  });

  group('recordSessionStart + recordSessionResume', () {
    test('start enqueues a row with source=mobile_session_start', () async {
      final svc = MobileL1AuditService.inMemory(
        appVersion: '2.12.3+test',
        constantsVersionHash: 'h1',
      );
      await svc.recordSessionStart(lifecycleState: 'resumed');
      final pending = await svc.buffer.fetchPending();
      expect(pending.length, 1);
      expect(pending.first.source, 'mobile_session_start');
      expect(pending.first.appLifecycleState, 'resumed');
      final decoded =
          jsonDecode(pending.first.payloadJson) as Map<String, dynamic>;
      expect(decoded['source'], 'mobile_session_start');
      expect(decoded['anonymous_session_id'], svc.anonymousSessionId);
    });

    test('resume enqueues a row with source=mobile_session_warm_resume',
        () async {
      final svc = MobileL1AuditService.inMemory(
        appVersion: '2.12.3+test',
        constantsVersionHash: 'h1',
      );
      await svc.recordSessionResume();
      final pending = await svc.buffer.fetchPending();
      expect(pending.length, 1);
      expect(pending.first.source, 'mobile_session_warm_resume');
    });
  });

  group('flush', () {
    test('drains pending rows through httpPost callback (success path)',
        () async {
      final svc = MobileL1AuditService.inMemory(
        appVersion: '2.12.3+test',
        constantsVersionHash: 'h1',
      );
      await svc.recordSessionStart();

      var calls = 0;
      Uri? lastUri;
      Map<String, dynamic>? lastBody;
      Future<int> httpPost(Uri uri, Map<String, dynamic> body) async {
        calls += 1;
        lastUri = uri;
        lastBody = body;
        return 200;
      }

      final outcome = await svc.flush(
        httpPost: httpPost,
        baseUri: Uri.parse('https://mint-staging.up.railway.app'),
      );
      expect(outcome.succeeded, 1);
      expect(outcome.failed, 0);
      expect(calls, 1);
      expect(lastUri!.path, '/api/v1/audit/mobile-session-events');
      expect(lastBody!['items'], hasLength(1));
      // After successful drain : buffer empty.
      expect(await svc.buffer.pendingCount, 0);
    });

    test('non-200 response leaves row in buffer with retryCount=1', () async {
      final svc = MobileL1AuditService.inMemory(
        appVersion: '2.12.3+test',
        constantsVersionHash: 'h1',
      );
      await svc.recordSessionStart();

      Future<int> httpPost(Uri uri, Map<String, dynamic> body) async => 503;

      final outcome = await svc.flush(
        httpPost: httpPost,
        baseUri: Uri.parse('https://mint-staging.up.railway.app'),
      );
      expect(outcome.succeeded, 0);
      expect(outcome.failed, 1);
      // pendingCount counts ALL rows in buffer ; fetchPending filters
      // by nextRetryAt <= now, so the just-failed row (next_retry_at
      // = now + 1s backoff) is excluded until the backoff elapses.
      expect(await svc.buffer.pendingCount, 1);
    });
  });
}
