import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mint_mobile/services/observability/mint_http_client.dart';

void main() {
  group('MintHttpClient', () {
    tearDown(() {
      MintHttpClient.configureRuntimeDebugEvidence(enabled: false);
    });

    test('stamps X-MINT-Req-Id as a uuid v4 on every request', () async {
      String? captured;
      final inner = MockClient((req) async {
        captured = req.headers[MintHttpClient.requestIdHeader];
        return http.Response('{"ok":true}', 200,
            headers: {'X-Trace-Id': 'srv-1'});
      });

      await MintHttpClient(inner).get(Uri.parse('https://example.test/health'));

      expect(captured, isNotNull);
      expect(
        captured,
        matches(RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-'
          r'[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        )),
        reason: 'must be a uuid v4 — verifying version + variant bits',
      );
    });

    test('generates a distinct req_id per call', () async {
      final ids = <String?>[];
      final inner = MockClient((req) async {
        ids.add(req.headers[MintHttpClient.requestIdHeader]);
        return http.Response('{}', 200);
      });
      final client = MintHttpClient(inner);

      await client.get(Uri.parse('https://example.test/a'));
      await client.get(Uri.parse('https://example.test/b'));
      await client.get(Uri.parse('https://example.test/c'));

      expect(ids.length, 3);
      expect(ids.toSet().length, 3,
          reason: 'each call must carry its own correlation id');
    });

    test('preserves status code and body across the buffer/re-emit', () async {
      final inner = MockClient((req) async {
        return http.Response(
          '{"messagesRemaining":0,"reply":"capped"}',
          200,
        );
      });

      final resp = await MintHttpClient(inner)
          .post(Uri.parse('https://example.test/chat'), body: '{}');

      expect(resp.statusCode, 200);
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      expect(body['messagesRemaining'], 0);
      expect(body['reply'], 'capped');
    });

    test('propagates non-2xx status codes', () async {
      final inner = MockClient((req) async {
        return http.Response('{"error":"rate_limited"}', 429);
      });

      final resp = await MintHttpClient(inner)
          .post(Uri.parse('https://example.test/chat'), body: '{}');

      expect(resp.statusCode, 429);
    });

    test('rethrows network errors with no body swallowing', () async {
      final inner = MockClient((req) async {
        throw const _NetDown();
      });

      expect(
        MintHttpClient(inner).get(Uri.parse('https://example.test/x')),
        throwsA(isA<_NetDown>()),
      );
    });

    test('runtime recorder stores only redacted aggregate fields', () async {
      MintHttpClient.configureRuntimeDebugEvidence(enabled: true);
      final inner = MockClient((req) async {
        return http.Response(
          '{"email":"person@example.test","q_net_income_period_chf":1234}',
          201,
        );
      });
      final client = MintHttpClient(inner);

      await client.post(
        Uri.parse(
          'https://api.example.test/api/v1/sync/claim-local-data'
          '?token=secret&email=person@example.test',
        ),
        headers: {'Authorization': 'Bearer raw-token'},
        body: '{"q_net_income_period_chf":1234}',
      );

      final summary = MintHttpClient.runtimeNetworkSummary();
      final entries =
          (summary['entries']! as List<Object?>).cast<Map<String, Object?>>();
      final encoded = jsonEncode(summary);

      expect(entries, hasLength(1));
      expect(entries.single, {
        'method': 'POST',
        'endpoint_path': '/api/v1/sync/claim-local-data',
        'status_class': '2xx',
        'count': 1,
        'forbidden_match': true,
      });
      expect(summary['forbiddenMatchCount'], 1);
      expect(encoded, isNot(contains('Authorization')));
      expect(encoded, isNot(contains('raw-token')));
      expect(encoded, isNot(contains('secret')));
      expect(encoded, isNot(contains('person@example.test')));
      expect(encoded, isNot(contains('q_net_income_period_chf')));
      expect(encoded, isNot(contains('1234')));
    });

    test('runtime evidence mode suppresses debug body logs', () async {
      final logs = <String>[];
      final oldDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        logs.add(message ?? '');
      };
      addTearDown(() {
        debugPrint = oldDebugPrint;
      });
      MintHttpClient.configureRuntimeDebugEvidence(enabled: true);
      final inner = MockClient((req) async {
        return http.Response('{"sensitive":"body"}', 200);
      });

      await MintHttpClient(inner).get(Uri.parse('https://example.test/body'));

      expect(logs.join('\n'), contains('[ch.mint.http] RES GET /body'));
      expect(logs.join('\n'), isNot(contains('BODY req_id=')));
      expect(logs.join('\n'), isNot(contains('sensitive')));
    });

    test('runtime recorder redacts dynamic endpoint path segments', () {
      MintHttpClient.configureRuntimeDebugEvidence(enabled: true);

      MintHttpClient.recordRuntimeNetworkEventForTesting(
        method: 'GET',
        endpointPath: '/api/v1/documents/550e8400-e29b-41d4-a716-446655440000',
        statusClass: '2xx',
      );
      MintHttpClient.recordRuntimeNetworkEventForTesting(
        method: 'PATCH',
        endpointPath: '/api/v1/household/member/raw_user_123456789abcdef',
        statusClass: '4xx',
      );

      final summary = MintHttpClient.runtimeNetworkSummary();
      final entries = summary['entries']! as List<Object?>;
      final encoded = jsonEncode(summary);

      expect(
        entries,
        anyElement(predicate<Object?>((entry) {
          final map = entry! as Map<String, Object?>;
          return map['method'] == 'GET' &&
              map['endpoint_path'] == '/api/v1/documents/:id' &&
              map['status_class'] == '2xx' &&
              map['count'] == 1 &&
              map['forbidden_match'] == false;
        })),
      );
      expect(
        entries,
        anyElement(predicate<Object?>((entry) {
          final map = entry! as Map<String, Object?>;
          return map['method'] == 'PATCH' &&
              map['endpoint_path'] == '/api/v1/household/member/:id' &&
              map['status_class'] == '4xx' &&
              map['count'] == 1 &&
              map['forbidden_match'] == false;
        })),
      );
      expect(encoded, isNot(contains('550e8400')));
      expect(encoded, isNot(contains('raw_user_123456789abcdef')));
    });
  });
}

class _NetDown implements Exception {
  const _NetDown();
  @override
  String toString() => 'NetDown';
}
