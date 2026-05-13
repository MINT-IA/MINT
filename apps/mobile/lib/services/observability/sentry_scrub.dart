import 'package:sentry_flutter/sentry_flutter.dart';

/// MINT Sentry `beforeSend` PII scrubber.
///
/// Swiss-compliance panel non-negotiable for nLPD + LSFin: every Sentry
/// event leaves the device with structured PII scrubbed AND Claude
/// prompt/response payloads dropped entirely. This is the second line
/// of defence behind `options.sendDefaultPii = false` (which already
/// blocks the SDK's built-in PII population).
///
/// Rationale:
///   - Free-text user input on MINT often contains financial figures
///     inline (« je veux acheter une maison à 800'000 CHF, AVS 756.… »).
///     The SDK can't know which strings to trust, so we strip every
///     known PII shape from `event.extra`, breadcrumb data, and message
///     bodies at the Dart level before serialization.
///   - Claude prompt / response strings are a forbidden payload class
///     (LSFin Art. 8 — a leaked banned term inside a Sentry event is
///     evidence of a bypassable sanitizer). We hard-strip any key whose
///     name matches a Claude-payload pattern.
///   - `request.data` is stripped wholesale because we control no
///     guarantee it doesn't include user-supplied financial values.
///
/// What this does NOT scrub:
///   - Stack frames (file paths, function names — non-PII by Sentry's
///     own definition).
///   - Top-level metadata fields the SDK populates (release, env,
///     timestamps).
///   - HTTP transaction tags (`mint_request_id`, `mint_trace_id` —
///     deliberately surfaced for triage).
///
/// Tested in `test/services/observability/sentry_scrub_test.dart`.
class MintSentryScrub {
  MintSentryScrub._();

  /// Replacement sentinel for redacted PII matches.
  static const String redacted = '<<REDACTED>>';

  /// Key names whose entire VALUE is dropped on sight (Claude payloads
  /// + free-text user inputs that may contain financial values inline).
  /// Anchored at start/end so a partial substring match (e.g. a key
  /// `is_prompt_eligible`) does not trigger the strip.
  static final RegExp forbiddenKeyPattern = RegExp(
    r'^(prompt|completion|messages|response|coach_text|coach_response|'
    r'claude_.*|user_message|user_input|free_text|chat_history)$',
    caseSensitive: false,
  );

  /// PII regex set — Swiss-specific. Each match is replaced with the
  /// [redacted] sentinel before the event is shipped.
  static final List<RegExp> piiPatterns = <RegExp>[
    // Swiss AVS-13 (canonical + no-dots variants).
    RegExp(r'\b756\.\d{4}\.\d{4}\.\d{2}\b'),
    RegExp(r'\b756\d{10}\b'),
    // Swiss IBAN (CH XX XXXX XXXX XXXX XXXX X).
    RegExp(r'\bCH\d{2}[ ]?(?:\d{4}[ ]?){4}\d{1}\b'),
    // Generic IBAN (FR, DE, IT, ES, PT — MINT's 6 locales).
    RegExp(r'\b[A-Z]{2}\d{2}[A-Z0-9]{11,30}\b'),
    // Email.
    RegExp(r'[\w.+-]+@[\w-]+\.[\w.-]+'),
    // Swiss / international phone (+41 …, 0041 …, 0 …).
    RegExp(r'(\+41|0041|0)\s?[1-9]\d(?:[\s.-]?\d{2,3}){3}'),
  ];

  /// `beforeSend` hook entry point. Returns `null` to drop the event
  /// entirely, or the (possibly mutated) event to forward to Sentry.
  ///
  /// Implementation note: sentry_flutter 9.x deprecated `SentryEvent.extra`
  /// (in favour of structured `Contexts`) and `SentryEvent.copyWith`
  /// (in favour of direct field assignment). The defensive `beforeSend`
  /// path must still scrub `extra` because legacy callers + auto-captured
  /// crash events still populate it. Suppression on each deprecated use
  /// is scoped to this call site — see TODO(S98-OBS-MIGRATE) for the
  /// follow-up migration to `Contexts` after Phase 2 ships.
  static SentryEvent? beforeSend(SentryEvent event, Hint hint) {
    // 1. Strip extras whose key matches the forbidden-key pattern.
    // ignore: deprecated_member_use
    final extraScrubbed = _scrubMap(event.extra);

    // 2. Sweep breadcrumbs — drop forbidden keys from `data`, scrub
    //    `message` content for PII regex.
    final crumbs = event.breadcrumbs?.map(_scrubBreadcrumb).toList();

    // 3. Scrub the top-level `message` field if present.
    final scrubbedMessage = event.message == null
        ? null
        : SentryMessage(
            _scrubString(event.message!.formatted),
            template: event.message!.template,
            params: event.message!.params,
          );

    // 4. Drop request body wholesale — we can't trust contents.
    // `copyWith(data: null)` is a no-op in sentry_flutter 9.x (null means
    // « no change », not « clear »). Constructing a fresh SentryRequest
    // with only the safe fields preserved is the only way to actually
    // drop body, cookies, and headers.
    final request = event.request == null
        ? null
        : SentryRequest(
            url: event.request!.url,
            method: event.request!.method,
            queryString: null, // strip — may carry free-text
            headers: const <String, String>{},
            cookies: null,
            data: null,
          );

    // ignore: deprecated_member_use
    return event.copyWith(
      // ignore: deprecated_member_use
      extra: extraScrubbed,
      breadcrumbs: crumbs,
      message: scrubbedMessage,
      request: request,
    );
  }

  static Map<String, dynamic>? _scrubMap(Map<String, dynamic>? input) {
    if (input == null) return null;
    final out = <String, dynamic>{};
    input.forEach((key, value) {
      if (forbiddenKeyPattern.hasMatch(key)) {
        out[key] = redacted;
        return;
      }
      out[key] = _scrubAny(value);
    });
    return out;
  }

  static dynamic _scrubAny(dynamic v) {
    if (v is String) return _scrubString(v);
    if (v is Map<String, dynamic>) return _scrubMap(v);
    if (v is List) return v.map(_scrubAny).toList();
    return v;
  }

  static String _scrubString(String input) {
    var out = input;
    for (final r in piiPatterns) {
      out = out.replaceAll(r, redacted);
    }
    return out;
  }

  static Breadcrumb _scrubBreadcrumb(Breadcrumb b) {
    // ignore: deprecated_member_use
    return b.copyWith(
      message: b.message == null ? null : _scrubString(b.message!),
      data: _scrubMap(b.data),
    );
  }
}
