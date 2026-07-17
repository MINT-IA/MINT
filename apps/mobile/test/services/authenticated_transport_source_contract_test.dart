import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all production sources delegate bearer ownership to ApiService', () {
    final dartSources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    for (final file in dartSources) {
      final path = file.path;
      if (path == 'lib/services/api_service.dart') continue;
      final source = file.readAsStringSync();

      expect(
        source,
        isNot(matches(
            RegExp(r'AuthService\s*\.\s*(getToken|readSessionEnvelope)\s*\('))),
        reason:
            '$path must delegate credential reads to AuthenticatedTransport',
      );
      expect(
        source,
        isNot(contains('AuthService.refreshAccessToken')),
        reason: '$path must not own refresh/retry',
      );
      expect(
        source,
        isNot(matches(RegExp(r'''["']Authorization["']\s*:'''))),
        reason: '$path must not construct an authorization header',
      );
      expect(
        source,
        isNot(matches(RegExp(r'''Bearer\s+\$'''))),
        reason: '$path must not interpolate a bearer token',
      );
    }
  });

  test('all API-backed raw HTTP calls are rejected except anonymous chat', () {
    final rawHttp = RegExp(r'\bhttp\s*\.\s*(get|post|put|patch|delete)\s*\(');
    final anonymousChat = RegExp(
      r'''Uri\.parse\(\s*["']\$\{ApiService\.baseUrl\}/anonymous/chat["']\s*\)''',
    );
    final dartSources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    for (final file in dartSources) {
      final path = file.path;
      if (path == 'lib/services/api_service.dart') continue;
      final source = file.readAsStringSync();
      final rawCalls = rawHttp.allMatches(source).length;
      if (rawCalls == 0) continue;

      final pointsAtMintApi = source.contains('ApiService.baseUrl') ||
          source.contains('/api/v1') ||
          source.contains('/rag/') ||
          source.contains('/coach/') ||
          source.contains('/auth/');
      if (!pointsAtMintApi) continue;

      // The one deliberately public backend surface is matched by its exact
      // anonymous path, never by a consumer-file allowlist.
      final approvedAnonymousCalls = anonymousChat.hasMatch(source) ? 1 : 0;
      expect(
        rawCalls,
        approvedAnonymousCalls,
        reason:
            '$path has a raw MINT API call; authenticated routes must use AuthenticatedTransport',
      );
    }
  });

  test('AuthService cannot refresh or perform HTTP outside an epoch guard', () {
    final source = File('lib/services/auth_service.dart').readAsStringSync();

    expect(source, isNot(contains('refreshAccessToken')));
    expect(source, isNot(contains("package:http/http.dart")));
    expect(source, isNot(contains('ApiService.baseUrl')));
    expect(source, isNot(contains('http.post')));
  });

  test('one approved primitive owns authenticated request refresh and 401', () {
    final source = File('lib/services/api_service.dart').readAsStringSync();

    expect(source, contains('AuthenticatedTransport'));
    expect(source, contains('SessionEpochGuard'));
    expect(source, contains('runGuardedPersistence'));
    expect(source, contains('await _terminateExpiredSession();'));
  });

  test('authenticated consumers use operation leases, never boolean preflight',
      () {
    final interfaceSource = File('lib/services/authenticated_transport.dart')
        .readAsStringSync();
    expect(interfaceSource, contains('AuthenticatedOperation'));
    expect(interfaceSource, contains('beginOperation()'));
    expect(interfaceSource, isNot(contains('hasAccessToken')));

    final consumers = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where((file) => file.path != 'lib/services/api_service.dart')
        .where(
          (file) => file.readAsStringSync().contains('AuthenticatedTransport'),
        );

    for (final file in consumers) {
      if (file.path == 'lib/services/authenticated_transport.dart') continue;
      final source = file.readAsStringSync();
      expect(
        source,
        contains('beginOperation()'),
        reason: '${file.path} must capture one immutable authenticated lease',
      );
      expect(
        source,
        isNot(contains('hasAccessToken')),
        reason: '${file.path} must not split preflight from authenticated send',
      );
      expect(
        source,
        isNot(matches(RegExp(
          r'\b(?:_transport|transport|client|authenticatedTransport)\s*\.\s*send\s*\(',
        ))),
        reason: '${file.path} must send through its captured operation lease',
      );
    }
  });
}
