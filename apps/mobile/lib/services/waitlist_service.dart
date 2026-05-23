import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'anonymous_session_service.dart';
import 'api_service.dart';
import 'observability/mint_http_client.dart';

/// Allowed archetype slugs accepted by POST /api/v1/waitlist (Pydantic
/// Literal mirror of services/backend/app/schemas/waitlist.py). Anything
/// outside this set is coerced to 'other' before the POST is fired.
const _allowedWaitlistArchetypes = <String>{
  'expat_us',
  'expat_eu',
  'cross_border',
  'independent_no_lpp',
  'couple_one_works',
  'senior_post_64',
  'other',
};

/// Discriminated outcome of a waitlist submission. Used by
/// [WaitlistProvider] to map errors onto i18n keys.
enum WaitlistApiError { badEmail, badRequest, unauthorized, server, network }

@immutable
class WaitlistResult {
  const WaitlistResult({required this.success, this.error});
  final bool success;
  final WaitlistApiError? error;

  static const WaitlistResult ok = WaitlistResult(success: true);
}

/// Single-purpose service for POST /api/v1/waitlist. Wraps
/// [MintHttpClient] (which already stamps X-MINT-Req-Id + Sentry tags)
/// and adds the X-Anonymous-Session header sourced from
/// [AnonymousSessionService.getOrCreateSessionId].
///
/// Threat-model notes (PLAN.md §threat_model T-01.5-23 / T-01.5-24 /
/// T-01.5-25):
/// - The email is NEVER passed to Sentry: error mapping uses status codes
///   only, never the response body.
/// - A `consentGiven == false` call short-circuits with an [ArgumentError]
///   before any network I/O — UCA opt-in defense-in-depth (the screen
///   also disables the CTA when the checkbox is unchecked).
class WaitlistService {
  WaitlistService();

  /// Test constructor — subclasses override [resolveSessionId],
  /// [httpClient], and [baseUrlOverride] to inject stubs.
  @visibleForTesting
  WaitlistService.test();

  /// Returns the X-Anonymous-Session UUID. Override in tests to bypass
  /// the SecureStorage / SharedPreferences chain.
  @visibleForTesting
  Future<String> resolveSessionId() =>
      AnonymousSessionService.getOrCreateSessionId();

  /// HTTP client used for the POST. Defaults to the process-wide
  /// MintHttpClient singleton (Sentry tags + correlation IDs). Override
  /// in tests with a `package:http/testing` MockClient.
  @visibleForTesting
  http.Client get httpClient => MintHttpClient.shared;

  /// Base URL for the POST. Defaults to ApiService.baseUrl (which honors
  /// staging-vs-prod selection at runtime). Override in tests.
  @visibleForTesting
  String get baseUrlOverride => ApiService.baseUrl;

  Future<WaitlistResult> submit({
    required String email,
    required String archetype,
    required String locale,
    required String source,
    required bool consentGiven,
  }) async {
    if (!consentGiven) {
      throw ArgumentError(
        'consentGiven must be true before calling submit (UCA opt-in).',
      );
    }
    final normalizedArchetype =
        _allowedWaitlistArchetypes.contains(archetype) ? archetype : 'other';

    final String sessionId;
    try {
      sessionId = await resolveSessionId();
    } catch (_) {
      return const WaitlistResult(
        success: false,
        error: WaitlistApiError.network,
      );
    }

    final uri = Uri.parse('$baseUrlOverride/waitlist');
    final body = jsonEncode({
      'email': email,
      'archetype': normalizedArchetype,
      'locale': locale,
      'source': source,
      'consentGiven': consentGiven,
    });

    try {
      final response = await httpClient
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'X-Anonymous-Session': sessionId,
            },
            body: body,
          )
          .timeout(const Duration(seconds: 15));

      final code = response.statusCode;
      if (code == 201 || code == 409) {
        // 409 = already-enrolled, idempotent UX per UI-SPEC §10.
        return WaitlistResult.ok;
      }
      if (code == 400) {
        return const WaitlistResult(
          success: false,
          error: WaitlistApiError.badEmail,
        );
      }
      if (code == 401) {
        return const WaitlistResult(
          success: false,
          error: WaitlistApiError.unauthorized,
        );
      }
      return const WaitlistResult(
        success: false,
        error: WaitlistApiError.server,
      );
    } on TimeoutException {
      return const WaitlistResult(
        success: false,
        error: WaitlistApiError.network,
      );
    } catch (_) {
      // Any other exception (SocketException, ClientException, etc.) is
      // surfaced as a network error — the email is never logged.
      return const WaitlistResult(
        success: false,
        error: WaitlistApiError.network,
      );
    }
  }
}
