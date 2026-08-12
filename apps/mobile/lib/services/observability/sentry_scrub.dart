import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:mint_mobile/services/observability/private_route_telemetry.dart';

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
  ///
  /// Negative-lookahead on `claude_request_id` / `claude_model` /
  /// `claude_token_usage` — these are non-PII triage identifiers the
  /// operator needs in Sentry to correlate a crash with Anthropic's
  /// server-side log (`msg_01ABCDEF`). Per code-review feedback I3,
  /// the prior wildcard `claude_.*` was over-greedy.
  static final RegExp forbiddenKeyPattern = RegExp(
    r'^(prompt|completion|messages|response|coach_text|coach_response|'
    r'claude_(?!request_id$|model$|token_usage$).*'
    r'|user_message|user_input|free_text|chat_history|private_route_name|'
    r'task_id|task_identity|task_status|tax_year|answers|profile_facts|'
    r'financial_context)$',
    caseSensitive: false,
  );

  /// PII regex set — Swiss-specific. Each match is replaced with the
  /// [redacted] sentinel before the event is shipped.
  ///
  /// Separator classes include dot, space, dash, NBSP. Per code-review
  /// feedback C1+C2, the original « dot only » AVS pattern and « space
  /// only » IBAN pattern missed realistic real-world inputs (Postfinance
  /// UI emits dashed IBAN ; PDFs paste with NBSP ; chat-style messages
  /// use spaces or dashes). Aligns with the prior-art recognizer at
  /// `services/backend/app/services/privacy/recognizers_ch.py` which
  /// already accepts the wider separator class.
  static final List<RegExp> piiPatterns = <RegExp>[
    // Swiss AVS-13 (canonical with separators + no-separator variant).
    // Separators: dot, space, dash, NBSP — any of them, optional.
    RegExp(r'\b756[.\s\- ]?\d{4}[.\s\- ]?\d{4}[.\s\- ]?\d{2}\b'),
    RegExp(r'\b756\d{10}\b'),
    // Swiss IBAN (CH + 2 check + 4×4 + 1). Accepts space, dash, NBSP.
    RegExp(r'\bCH\d{2}[\s\- ]?(?:\d{4}[\s\- ]?){4}\d{1}\b'),
    // Generic IBAN narrowed to MINT's 6-locale plus close-neighbour set
    // (per code-review M2 — avoid false-positive on stack-frame hex blobs).
    RegExp(
      r'\b(?:FR|DE|IT|ES|PT|BE|NL|LU|AT|LI)\d{2}[\s\- ]?'
      r'[A-Z0-9]{11,30}\b',
    ),
    // Email.
    RegExp(r'[\w.+-]+@[\w-]+\.[\w.-]+'),
    // Swiss / international phone (+41 …, 0041 …, 0 …).
    RegExp(r'(\+41|0041|0)\s?[1-9]\d(?:[\s.\-]?\d{2,3}){3}'),
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
    final privateFinancialEvent = _isPrivateFinancialEvent(event);
    // 1. Strip extras whose key matches the forbidden-key pattern.
    final extraScrubbed = privateFinancialEvent
        ? const <String, dynamic>{}
        : _scrubMap(_legacyExtra(event));

    // 2. Sweep breadcrumbs — drop forbidden keys from `data`, scrub
    //    `message` content for PII regex.
    final crumbs = privateFinancialEvent
        ? const <Breadcrumb>[]
        : event.breadcrumbs?.map(_scrubBreadcrumb).toList();

    // 3. Scrub the top-level `message` field if present.
    final scrubbedMessage = event.message == null
        ? null
        : SentryMessage(
            privateFinancialEvent
                ? redacted
                : _scrubString(event.message!.formatted),
            template: event.message!.template == null
                ? null
                : privateFinancialEvent
                    ? redacted
                    : _scrubString(event.message!.template!),
            params: privateFinancialEvent
                ? event.message!.params
                    ?.map((_) => redacted)
                    .toList(growable: false)
                : _scrubAny(event.message!.params),
          );

    final scrubbedContexts = Contexts.fromJson(
      privateFinancialEvent
          ? const <String, dynamic>{}
          : _scrubMap(event.contexts.toJson()) ?? const <String, dynamic>{},
    );
    final scrubbedTransaction = privateFinancialEvent
        ? 'private_financial_flow'
        : event.transaction == null
            ? null
            : _scrubString(event.transaction!);

    // 4. Drop request body wholesale — we can't trust contents.
    // `copyWith(data: null)` is a no-op in sentry_flutter 9.x (null means
    // « no change », not « clear »). Constructing a fresh SentryRequest
    // with only the safe fields preserved is the only way to actually
    // drop body, cookies, and headers.
    final request = event.request == null
        ? null
        : privateFinancialEvent
            ? SentryRequest(
                url: redacted,
                method: event.request!.method,
                queryString: null,
                headers: const <String, String>{},
                cookies: null,
                data: null,
              )
            : SentryRequest(
                url: event.request!.url,
                method: event.request!.method,
                queryString: null, // strip — may carry free-text
                headers: const <String, String>{},
                cookies: null,
                data: null,
              );

    // 5. Scrub stack-frame local variables (per code-review I5). The
    // Flutter SDK includes local var values on Dart exceptions; an
    // uncaught throw inside a function with `var iban = "CH93..."` would
    // ship the raw value otherwise. File / function / lineNo untouched
    // (non-PII per Sentry's own classification).
    final exceptions = event.exceptions
        ?.map((exception) =>
            _scrubException(exception, redactValue: privateFinancialEvent))
        .toList(growable: false);

    // 6. Scrub tag VALUES — tags are typically system identifiers but
    // a future caller setting a free-text value would bypass the rest
    // of the scrubber. Keys preserved (Sentry UI lookup must stay
    // stable); values pass through the PII regex set. Per M6.
    final tags = privateFinancialEvent
        ? const <String, String>{'surface': 'private_financial_flow'}
        : <String, String>{
            ...?event.tags?.map<String, String>(
              (k, v) => MapEntry(
                k,
                forbiddenKeyPattern.hasMatch(k) ? redacted : _scrubString(v),
              ),
            ),
          };

    // ignore: deprecated_member_use
    return event.copyWith(
      // ignore: deprecated_member_use
      extra: extraScrubbed,
      breadcrumbs: crumbs,
      message: scrubbedMessage,
      transaction: scrubbedTransaction,
      contexts: scrubbedContexts,
      request: request,
      exceptions: exceptions,
      tags: tags,
    );
  }

  static bool _isPrivateFinancialEvent(SentryEvent event) {
    bool contains(dynamic value) {
      if (value is String) {
        return _privateMarkerPattern.hasMatch(value);
      }
      if (value is Map) {
        return value.entries.any((entry) {
          final key = entry.key.toString();
          return _privateFieldKeyPattern.hasMatch(key) ||
              contains(entry.value) ||
              contains('$key=${entry.value}');
        });
      }
      if (value is Iterable) return value.any(contains);
      return false;
    }

    return MintPrivateFinancialTelemetryScope.isActive ||
        contains(_legacyExtra(event)) ||
        contains(event.tags) ||
        contains(event.transaction) ||
        contains(event.contexts.toJson()) ||
        contains(event.message?.formatted) ||
        contains(event.message?.template) ||
        contains(event.message?.params) ||
        contains(event.request?.url) ||
        contains(event.exceptions?.map((exception) => exception.value)) ||
        contains(event.exceptions?.expand(
          (exception) =>
              exception.stackTrace?.frames.map((frame) => frame.vars) ??
              const <Map<String, String>>[],
        )) ||
        contains(event.breadcrumbs
            ?.map((crumb) => [crumb.category, crumb.message, crumb.data]));
  }

  static Map<String, dynamic>? _legacyExtra(SentryEvent event) {
    // ignore: deprecated_member_use
    return event.extra;
  }

  static final RegExp _privateMarkerPattern = RegExp(
    r'(/mint-next/3a|3a\.verify_annual_credited_total|annual_total|'
    r'latest_payment_only|pay_max_without_checking|tax_year\s*[:=]\s*\d{4})',
    caseSensitive: false,
  );

  static final RegExp _privateFieldKeyPattern = RegExp(
    r'^(task_id|task_identity|task_status|tax_year|answers?|profile_facts|'
    r'financial_context|balance|contribution|tax_delta|tax_range)$',
    caseSensitive: false,
  );

  static SentryException _scrubException(
    SentryException exc, {
    bool redactValue = false,
  }) {
    final scrubbedValue = exc.value == null
        ? null
        : redactValue
            ? redacted
            : _scrubString(exc.value!);
    final scrubbedTrace = exc.stackTrace == null
        ? null
        : _scrubStackTrace(exc.stackTrace!, clearVars: redactValue);
    // ignore: deprecated_member_use
    return exc.copyWith(value: scrubbedValue, stackTrace: scrubbedTrace);
  }

  static SentryStackTrace _scrubStackTrace(
    SentryStackTrace trace, {
    bool clearVars = false,
  }) {
    final frames = trace.frames
        .map((frame) => _scrubFrame(frame, clearVars: clearVars))
        .toList(growable: false);
    // ignore: deprecated_member_use
    return trace.copyWith(frames: frames);
  }

  /// Sentry's stack-frame `vars` is `Map<String, String>?` (already
  /// string-ified by the SDK at capture time — Dart values are
  /// repr'd into strings). We scrub each value via [_scrubString];
  /// keys are preserved for the Sentry UI's variable-name display.
  static SentryStackFrame _scrubFrame(
    SentryStackFrame f, {
    bool clearVars = false,
  }) {
    final v = f.vars;
    if (v.isEmpty) return f;
    if (clearVars) {
      // ignore: deprecated_member_use
      return f.copyWith(vars: const <String, String>{});
    }
    final scrubbed = v.map<String, String>(
      (key, value) => MapEntry(key, _scrubString(value)),
    );
    // ignore: deprecated_member_use
    return f.copyWith(vars: scrubbed);
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
    var out = input.replaceAll(RegExp(r'/mint-next/3a(?:\?[^\s]*)?'), redacted);
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
