import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mint_mobile/providers/waitlist_provider.dart';
import 'package:mint_mobile/services/waitlist_service.dart';

/// Test wrapper around `WaitlistService` letting tests inject a
/// `MockClient` (http package) for the HTTP layer and a stub session-id
/// resolver. Mirrors the production service signature 1:1.
class _TestableWaitlistService extends WaitlistService {
  _TestableWaitlistService({required this.mockClient}) : super.test();

  final http.Client mockClient;

  @override
  Future<String> resolveSessionId() async => 'test-session-uuid';

  @override
  http.Client get httpClient => mockClient;

  @override
  String get baseUrlOverride => 'https://example.test';
}

class _ApiV1BaseWaitlistService extends _TestableWaitlistService {
  _ApiV1BaseWaitlistService({required super.mockClient});

  @override
  String get baseUrlOverride => 'https://example.test/api/v1';
}

void main() {
  group('WaitlistProvider initial state', () {
    test('status is initial and errorKey null on construction', () {
      final svc = _TestableWaitlistService(
        mockClient: MockClient((req) async => http.Response('{}', 201)),
      );
      final provider = WaitlistProvider(service: svc);

      expect(provider.status, WaitlistStatus.initial);
      expect(provider.errorKey, isNull);
    });
  });

  group('WaitlistProvider submit transitions', () {
    test('posts to /waitlist when ApiService.baseUrl already includes /api/v1',
        () async {
      Uri? capturedUrl;
      final svc = _ApiV1BaseWaitlistService(
        mockClient: MockClient((req) async {
          capturedUrl = req.url;
          return http.Response(
            jsonEncode({'id': 'abc-123', 'createdAt': '2026-05-22T00:00:00Z'}),
            201,
          );
        }),
      );
      final provider = WaitlistProvider(service: svc);

      await provider.submit(
        email: 'test@example.ch',
        archetype: 'expat_us',
        locale: 'fr',
        source: 'onboarding_hard_gate',
        consentGiven: true,
      );

      expect(capturedUrl, Uri.parse('https://example.test/api/v1/waitlist'));
      expect(provider.status, WaitlistStatus.success);
    });

    test('201 → initial → submitting → success', () async {
      final statuses = <WaitlistStatus>[];
      final svc = _TestableWaitlistService(
        mockClient: MockClient((req) async {
          // Backend returns 201 with id+createdAt.
          return http.Response(
            jsonEncode({'id': 'abc-123', 'createdAt': '2026-05-22T00:00:00Z'}),
            201,
          );
        }),
      );
      final provider = WaitlistProvider(service: svc);
      provider.addListener(() => statuses.add(provider.status));

      await provider.submit(
        email: 'test@example.ch',
        archetype: 'expat_us',
        locale: 'fr',
        source: 'onboarding_hard_gate',
        consentGiven: true,
      );

      expect(statuses, contains(WaitlistStatus.submitting));
      expect(provider.status, WaitlistStatus.success);
      expect(provider.errorKey, isNull);
    });

    test('400 → error with waitlistErrorBadEmail key', () async {
      final svc = _TestableWaitlistService(
        mockClient: MockClient((req) async {
          return http.Response(
            jsonEncode({'detail': 'Email invalide'}),
            400,
          );
        }),
      );
      final provider = WaitlistProvider(service: svc);

      await provider.submit(
        email: 'bad',
        archetype: 'expat_us',
        locale: 'fr',
        source: 'onboarding_hard_gate',
        consentGiven: true,
      );

      expect(provider.status, WaitlistStatus.error);
      expect(provider.errorKey, 'waitlistErrorBadEmail');
    });

    test('500 → error with waitlistErrorNetwork key', () async {
      final svc = _TestableWaitlistService(
        mockClient: MockClient((req) async {
          return http.Response('Server boom', 500);
        }),
      );
      final provider = WaitlistProvider(service: svc);

      await provider.submit(
        email: 'test@example.ch',
        archetype: 'expat_us',
        locale: 'fr',
        source: 'onboarding_hard_gate',
        consentGiven: true,
      );

      expect(provider.status, WaitlistStatus.error);
      expect(provider.errorKey, 'waitlistErrorNetwork');
    });

    test('409 (already enrolled) → treated as success (idempotent UX)',
        () async {
      final svc = _TestableWaitlistService(
        mockClient: MockClient((req) async {
          return http.Response(
            jsonEncode({'detail': 'Email déjà inscrit'}),
            409,
          );
        }),
      );
      final provider = WaitlistProvider(service: svc);

      await provider.submit(
        email: 'test@example.ch',
        archetype: 'expat_us',
        locale: 'fr',
        source: 'onboarding_hard_gate',
        consentGiven: true,
      );

      expect(provider.status, WaitlistStatus.success);
      expect(provider.errorKey, isNull);
    });

    test('network / socket exception → error with waitlistErrorNetwork',
        () async {
      final svc = _TestableWaitlistService(
        mockClient: MockClient((req) async {
          throw const SocketExceptionShim('No internet');
        }),
      );
      final provider = WaitlistProvider(service: svc);

      await provider.submit(
        email: 'test@example.ch',
        archetype: 'expat_us',
        locale: 'fr',
        source: 'onboarding_hard_gate',
        consentGiven: true,
      );

      expect(provider.status, WaitlistStatus.error);
      expect(provider.errorKey, 'waitlistErrorNetwork');
    });

    test('resetError() from error → returns to initial', () async {
      final svc = _TestableWaitlistService(
        mockClient: MockClient((req) async => http.Response('boom', 500)),
      );
      final provider = WaitlistProvider(service: svc);

      await provider.submit(
        email: 'test@example.ch',
        archetype: 'expat_us',
        locale: 'fr',
        source: 'onboarding_hard_gate',
        consentGiven: true,
      );
      expect(provider.status, WaitlistStatus.error);

      provider.resetError();
      expect(provider.status, WaitlistStatus.initial);
      expect(provider.errorKey, isNull);
    });
  });

  group('WaitlistProvider archetype normalization', () {
    test('unknown archetype slug coerced to "other" before POST', () async {
      String? capturedArchetype;
      final svc = _TestableWaitlistService(
        mockClient: MockClient((req) async {
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          capturedArchetype = body['archetype'] as String?;
          return http.Response('{"id":"x","createdAt":"now"}', 201);
        }),
      );
      final provider = WaitlistProvider(service: svc);

      await provider.submit(
        email: 'test@example.ch',
        archetype: 'unknown', // not in allowed set
        locale: 'fr',
        source: 'onboarding_hard_gate',
        consentGiven: true,
      );

      expect(capturedArchetype, 'other');
      expect(provider.status, WaitlistStatus.success);
    });

    test('null-equivalent (passed via WaitlistProvider helper) → "other"',
        () async {
      // The provider's submit() requires non-null archetype string — the
      // screen layer is responsible for passing 'other' when args.archetype
      // is null. This test pins the contract: passing 'other' directly is
      // accepted (no further coercion needed at the service layer).
      String? capturedArchetype;
      final svc = _TestableWaitlistService(
        mockClient: MockClient((req) async {
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          capturedArchetype = body['archetype'] as String?;
          return http.Response('{"id":"x","createdAt":"now"}', 201);
        }),
      );
      final provider = WaitlistProvider(service: svc);

      await provider.submit(
        email: 'test@example.ch',
        archetype: 'other',
        locale: 'fr',
        source: 'onboarding_hard_gate',
        consentGiven: true,
      );

      expect(capturedArchetype, 'other');
    });
  });

  group('WaitlistProvider consent guard', () {
    test('consentGiven=false → ArgumentError, no POST fired', () async {
      var fired = false;
      final svc = _TestableWaitlistService(
        mockClient: MockClient((req) async {
          fired = true;
          return http.Response('{}', 201);
        }),
      );
      final provider = WaitlistProvider(service: svc);

      expect(
        () => provider.submit(
          email: 'test@example.ch',
          archetype: 'expat_us',
          locale: 'fr',
          source: 'onboarding_hard_gate',
          consentGiven: false,
        ),
        throwsArgumentError,
      );
      expect(fired, isFalse);
      expect(provider.status, WaitlistStatus.initial);
    });
  });
}

/// Re-export of dart:io SocketException-like sentinel for tests that
/// don't want to drag dart:io into a pure-Dart test. The provider catches
/// any Exception subtype and maps it to a network error.
class SocketExceptionShim implements Exception {
  const SocketExceptionShim(this.message);
  final String message;

  @override
  String toString() => 'SocketException: $message';
}
