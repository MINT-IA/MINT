import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/debug/debug_registry.dart';
import 'package:mint_mobile/debug/debug_server.dart';
import 'package:mint_mobile/services/observability/mint_http_client.dart';

void main() {
  late DebugServer server;
  late GoRouter router;
  late int port;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Flutter tests install a `HttpOverrides.global` that stubs every
    // outbound HTTP to a 400. Disable it so our localhost calls reach
    // the in-isolate `HttpServer` we just bound.
    HttpOverrides.global = null;
    router = GoRouter(routes: [
      GoRoute(
        path: '/',
        name: 'root',
        builder: (_, __) => const SizedBox.shrink(),
      ),
    ]);

    // Bind on port 0 to let the OS allocate (no race with a probe close).
    final s = await DebugServer.start(router: router, port: 0);
    server = s!;
    port = server.server.port;
    addTearDown(() async {
      await server.stop();
      DebugRegistry.reset();
      MintHttpClient.eventBuffer = null;
    });
  });

  group('DebugServer HTTP surface', () {
    test('/debug/health is reachable without bearer', () async {
      final client = HttpClient();
      final req =
          await client.getUrl(Uri.parse('http://127.0.0.1:$port/debug/health'));
      final res = await req.close();
      expect(res.statusCode, 200);
      final body = await res.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      expect(json['ok'], true);
      expect(json['schema'], 'v1');
      expect(json['uptimeMs'], isA<int>());
      client.close();
    });

    test('/debug/state without bearer returns 401', () async {
      final client = HttpClient();
      final req =
          await client.getUrl(Uri.parse('http://127.0.0.1:$port/debug/state'));
      final res = await req.close();
      expect(res.statusCode, 401);
      client.close();
    });

    test('/debug/state with bearer returns full snapshot', () async {
      final client = HttpClient();
      final req =
          await client.getUrl(Uri.parse('http://127.0.0.1:$port/debug/state'));
      req.headers.add('Authorization', 'Bearer ${server.bearerToken}');
      final res = await req.close();
      expect(res.statusCode, 200);
      final body = await res.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      expect(json['_meta'], isA<Map>());
      expect(json['_meta']['schema'], 'v1');
      expect(json['_meta']['surfaces'], isA<List>());
      // The three built-in surfaces (logs surface removed in code review C1 —
      // shipped dormant + filter doc mismatched implementation, PII trap risk).
      expect(
        (json['_meta']['surfaces'] as List).toSet(),
        equals({'router', 'http', 'prefs'}),
      );
      client.close();
    });

    test('/debug/state with wrong bearer returns 401 (constant time)',
        () async {
      final client = HttpClient();
      final req =
          await client.getUrl(Uri.parse('http://127.0.0.1:$port/debug/state'));
      req.headers.add('Authorization', 'Bearer wrong-token');
      final res = await req.close();
      expect(res.statusCode, 401);
      client.close();
    });

    test('/debug/state/<unknown> returns 404', () async {
      final client = HttpClient();
      final req = await client
          .getUrl(Uri.parse('http://127.0.0.1:$port/debug/state/nonexistent'));
      req.headers.add('Authorization', 'Bearer ${server.bearerToken}');
      final res = await req.close();
      expect(res.statusCode, 404);
      client.close();
    });

    test('/debug/state/router returns just the router surface', () async {
      final client = HttpClient();
      final req = await client
          .getUrl(Uri.parse('http://127.0.0.1:$port/debug/state/router'));
      req.headers.add('Authorization', 'Bearer ${server.bearerToken}');
      final res = await req.close();
      expect(res.statusCode, 200);
      final body = await res.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      expect(json['_meta'], isA<Map>());
      expect(json['router'], isA<Map>());
      expect(json['router']['stack'], isA<List>());
      client.close();
    });

    test('bound to loopback only, NOT all interfaces', () async {
      // The address bound is `loopbackIPv4`. Verify by inspecting the
      // server's bound address.
      expect(
        server.server.address.host,
        anyOf('127.0.0.1', 'localhost'),
      );
    });

    test('bearer token is 43 chars (32 bytes base64url, no padding)', () {
      expect(server.bearerToken.length, 43);
      expect(server.bearerToken, matches(RegExp(r'^[A-Za-z0-9_-]+$')));
    });

    test('idempotent start returns the existing instance', () async {
      final again = await DebugServer.start(router: router, port: port);
      expect(again, same(server));
    });

    test('http surface exposes inflightCount=0 after init', () async {
      final client = HttpClient();
      final req = await client
          .getUrl(Uri.parse('http://127.0.0.1:$port/debug/state/http'));
      req.headers.add('Authorization', 'Bearer ${server.bearerToken}');
      final res = await req.close();
      expect(res.statusCode, 200);
      final body = await res.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final http = json['http'] as Map<String, dynamic>;
      expect(http['inflightCount'], 0);
      expect(http['count'], 0);
      expect(http['events'], isEmpty);
      client.close();
    });

    test('MintHttpClient.eventBuffer wired by start()', () {
      expect(MintHttpClient.eventBuffer, isNotNull);
    });

    test('token file at <systemTemp>/mint_debug.token matches server.bearerToken',
        () async {
      // C2 fix contract: `_writeTokenFile` writes the resolved absolute
      // path on POSIX hosts and returns it. Maestro's primary recovery
      // path (when stdout grep is unavailable) is reading this file.
      // Regression guard: if the writer silently fails or stops writing
      // the token contents, this test catches it before TestFlight.
      if (Platform.isWindows) return; // chmod 600 skipped on Windows
      final tokenFile = File(
          '${Directory.systemTemp.path}/mint_debug.token');
      expect(tokenFile.existsSync(), isTrue,
          reason: 'token file must exist at <systemTemp>/mint_debug.token');
      final contents = (await tokenFile.readAsString()).trim();
      expect(contents, equals(server.bearerToken),
          reason: 'token file contents must match server.bearerToken');
    });
  });
}
