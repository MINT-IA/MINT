// Sentry SDK 9.x deprecated SentryEvent.extra in favour of structured
// `Contexts`. The scrubber must still defend against the legacy field
// because crash events captured by the SDK still populate it. Tests
// construct events via the deprecated `extra:` param to exercise the
// scrubber on the actual field it scrubs at runtime.
// ignore_for_file: deprecated_member_use
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/observability/sentry_scrub.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Contract tests for MINT's Sentry `beforeSend` scrubber.
///
/// These assertions are the deterministic ground truth behind the
/// Swiss-compliance panel's non-negotiable: no AVS, IBAN, email,
/// phone, or Claude payload may leave the device inside a Sentry
/// event. Each test names the regulation it grounds.

void main() {
  group('MintSentryScrub.beforeSend', () {
    SentryEvent eventWith({
      Map<String, dynamic>? extra,
      String? message,
      List<Breadcrumb>? breadcrumbs,
      SentryRequest? request,
    }) {
      return SentryEvent(
        message: message == null ? null : SentryMessage(message),
        extra: extra,
        breadcrumbs: breadcrumbs,
        request: request,
      );
    }

    test('AVS-13 is redacted (nLPD Art. 8 — special-category-adjacent)', () {
      final event = eventWith(
        message: 'patient AVS 756.1234.5678.97 received Pillar 3a refund',
      );
      final out = MintSentryScrub.beforeSend(event, Hint());
      expect(out!.message!.formatted, contains(MintSentryScrub.redacted));
      expect(out.message!.formatted, isNot(contains('756.1234.5678.97')));
    });

    test('Swiss IBAN is redacted', () {
      final event = eventWith(
        message: 'transfer to CH93 0076 2011 6238 5295 7 succeeded',
      );
      final out = MintSentryScrub.beforeSend(event, Hint());
      expect(out!.message!.formatted, isNot(contains('CH93 0076')));
      expect(out.message!.formatted, contains(MintSentryScrub.redacted));
    });

    test('email is redacted', () {
      final event = eventWith(
        message: 'lookup user lauren.doe@expat.example.com failed',
      );
      final out = MintSentryScrub.beforeSend(event, Hint());
      expect(out!.message!.formatted, isNot(contains('lauren.doe@')));
    });

    test('Swiss phone is redacted', () {
      final event = eventWith(message: 'call user +41 79 123 45 67');
      final out = MintSentryScrub.beforeSend(event, Hint());
      expect(out!.message!.formatted, isNot(contains('+41 79')));
    });

    test('forbidden key (prompt) drops VALUE wholesale (LSFin Art. 8)', () {
      final event = eventWith(extra: {
        'prompt':
            'tu garantis un rendement optimal pour la retraite à 65 ans',
        'safe_metric': 42,
      });
      final out = MintSentryScrub.beforeSend(event, Hint());
      expect(out!.extra!['prompt'], MintSentryScrub.redacted);
      expect(out.extra!['safe_metric'], 42); // untouched
    });

    test('forbidden key claude_* (wildcard) is dropped', () {
      final event = eventWith(extra: {
        'claude_response': 'this would be a banned-term-bearing answer',
        'claude_request_id': 'msg_01ABCDEF',
        'unrelated_field': 'kept',
      });
      final out = MintSentryScrub.beforeSend(event, Hint());
      expect(out!.extra!['claude_response'], MintSentryScrub.redacted);
      expect(out.extra!['claude_request_id'], MintSentryScrub.redacted);
      expect(out.extra!['unrelated_field'], 'kept');
    });

    test('partial-substring key match does NOT trigger drop', () {
      // « is_prompt_eligible » contains 'prompt' but is not exact match.
      final event = eventWith(extra: {
        'is_prompt_eligible': true,
        'completion_rate': 0.93,
      });
      final out = MintSentryScrub.beforeSend(event, Hint());
      expect(out!.extra!['is_prompt_eligible'], true);
      // Wait — `completion_rate` starts with `completion`, but is not
      // exact. Anchored regex must reject it.
      expect(out.extra!['completion_rate'], 0.93);
    });

    test('breadcrumb data + message are both scrubbed', () {
      final event = eventWith(breadcrumbs: [
        Breadcrumb(
          message: 'user 756.9876.5432.10 hit /api/profile',
          data: {
            'prompt': 'this should be dropped',
            'route': '/profile',
          },
        ),
      ]);
      final out = MintSentryScrub.beforeSend(event, Hint());
      final crumb = out!.breadcrumbs!.first;
      expect(crumb.message, isNot(contains('756.9876')));
      expect(crumb.data!['prompt'], MintSentryScrub.redacted);
      expect(crumb.data!['route'], '/profile');
    });

    test('request.data is dropped wholesale', () {
      final event = eventWith(
        request: SentryRequest(
          url: 'https://api.mint.app/v1/coach/chat',
          method: 'POST',
          data: {
            'messages': [
              {'role': 'user', 'content': 'salaire 120000 CHF, IBAN CH93 0076…'}
            ],
          },
        ),
      );
      final out = MintSentryScrub.beforeSend(event, Hint());
      expect(out!.request!.data, isNull);
      expect(out.request!.headers, isEmpty);
    });

    test('nested PII in nested maps is scrubbed', () {
      final event = eventWith(extra: {
        'context': {
          'archetype': 'expat_us',
          'note': 'AVS 756.1111.2222.33 — FATCA flagged',
        }
      });
      final out = MintSentryScrub.beforeSend(event, Hint());
      final nested = out!.extra!['context'] as Map<String, dynamic>;
      expect(nested['archetype'], 'expat_us'); // untouched, no PII
      expect(nested['note'], isNot(contains('756.1111')));
    });
  });
}
