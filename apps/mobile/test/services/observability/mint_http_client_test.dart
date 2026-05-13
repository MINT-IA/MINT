import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mint_mobile/services/observability/mint_http_client.dart';

void main() {
  group('MintHttpClient', () {
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
  });
}

class _NetDown implements Exception {
  const _NetDown();
  @override
  String toString() => 'NetDown';
}
