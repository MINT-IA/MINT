import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:uuid/uuid.dart';

/// HTTP client that injects a per-call correlation ID and emits structured
/// logs so an LLM agent can grep the request lifecycle from `simctl log`.
///
/// Every outbound call gets `X-MINT-Req-Id: <uuidv4>`. The backend
/// `LoggingMiddleware` reuses that value as its `trace_id_var`, so a
/// single ID stitches client stdout to Railway backend logs (see
/// `tools/debug/mint-trace.sh`).
///
/// Surface the logs from a booted iOS simulator with:
///
///   xcrun simctl spawn booted log show --last 5m \
///     --predicate 'process == "Runner"' --style compact \
///     | grep '\[ch.mint.http\]'
///
/// Why `debugPrint` and not `dart:developer.log` — Flutter's `developer.log`
/// goes to the Dart VM service / stderr, but it does NOT bridge to iOS
/// `os_log` with a structured category. `debugPrint` (and `print`) DO
/// surface in OSLog as `(Flutter) flutter: …`, which is what
/// `simctl log show` can grep. Verified runtime 2026-05-13 on the
/// cassure #4 probe.
///
/// Debug builds include the response body (capped at [_bodyLogCap] chars)
/// to surface parsing / serialization mismatches. Release builds log
/// method, path, status, duration, and IDs only — PII-safe.
class MintHttpClient extends http.BaseClient {
  MintHttpClient([http.Client? inner]) : _inner = inner ?? http.Client();

  /// Process-wide singleton — every MINT service that performs HTTP
  /// outbound traffic should call through this so request IDs, body
  /// inspection, and the connection pool stay unified.
  static final MintHttpClient shared = MintHttpClient();

  final http.Client _inner;
  static const Uuid _uuid = Uuid();

  static const String logCategory = 'ch.mint.http';
  static const String requestIdHeader = 'X-MINT-Req-Id';
  static const int _bodyLogCap = 2000;
  static bool _runtimeDebugEvidenceEnabled =
      const bool.fromEnvironment('MINT_RUNTIME_DEBUG_EVIDENCE');
  static final _RuntimeNetworkRecorder _runtimeNetworkRecorder =
      _RuntimeNetworkRecorder();

  static void configureRuntimeDebugEvidence({required bool enabled}) {
    _runtimeDebugEvidenceEnabled = enabled;
    _runtimeNetworkRecorder.clear();
  }

  static Map<String, Object?> runtimeNetworkSummary() =>
      _runtimeNetworkRecorder.toRedactedJson(
        recording: _runtimeDebugEvidenceEnabled,
      );

  static void recordRuntimeNetworkEventForTesting({
    required String method,
    required String endpointPath,
    required String statusClass,
  }) {
    _runtimeNetworkRecorder.record(
      method: method,
      endpointPath: endpointPath,
      statusClass: statusClass,
    );
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final requestId = _uuid.v4();
    request.headers[requestIdHeader] = requestId;
    final start = DateTime.now();

    // S98 Phase 2 — promote the X-MINT-Req-Id to a Sentry-searchable
    // tag on the current scope. A crash thrown anywhere during this
    // request ships to Sentry with `mint_request_id=<uuid>`, which is
    // the join key into Railway backend logs (echoed as X-Trace-Id).
    // No-op when Sentry SDK is not initialised (tests, debug builds
    // without SENTRY_DSN dart-define).
    //
    // KNOWN LIMITATION (code-review I1, TODO S98-OBS-SCOPE-RACE):
    // `configureScope` mutates the top of the current Hub's scope stack
    // — it's process-wide, NOT per-request. Two concurrent `send()`
    // calls race: the second overwrites the first's tag. In practice
    // MINT today fires serial requests (each service awaits its call)
    // but `Future.wait` in main.dart triggers parallel data loads on
    // startup. If one of THOSE crashes the wrong tag attributes the
    // event. Mitigation tracked as follow-up: wrap `send()` body in a
    // forked Hub or use `captureException(withScope: ...)` per-catch.
    // For now we also set the tag at the catch site so the LAST tag
    // value when the exception actually fires is correct in serial use.
    Sentry.configureScope((scope) {
      scope.setTag('mint_request_id', requestId);
    });

    _log(
      'REQ ${request.method} ${request.url.path} '
      'req_id=$requestId host=${request.url.host}',
    );

    // Debug builds journal the OUTBOUND body too — the zero-transmission
    // runtime proof greps this boundary; a request type whose body cannot
    // be read here is marked unobserved rather than silently skipped.
    if (kDebugMode && !_runtimeDebugEvidenceEnabled) {
      if (request is http.Request) {
        if (request.body.isNotEmpty) {
          _log(
            'REQBODY req_id=$requestId bytes=${request.bodyBytes.length} '
            'body=${_truncate(request.body, _bodyLogCap)}',
          );
        }
      } else {
        _log('REQBODY req_id=$requestId unobserved type=${request.runtimeType}');
      }
    }

    http.StreamedResponse upstream;
    try {
      upstream = await _inner.send(request);
    } catch (e, s) {
      // Re-tag the scope right before rethrow — the global error
      // boundary captures the exception from THIS catch unwinding,
      // and the most-recent scope mutation wins. Defends partially
      // against the I1 concurrent-scope race (see send() preamble):
      // even if another in-flight request overwrote our tag, the
      // re-tag here restores the value for the actual failing call.
      Sentry.configureScope((scope) {
        scope.setTag('mint_request_id', requestId);
      });
      _log(
        'ERR ${request.method} ${request.url.path} '
        'req_id=$requestId error=$e',
        error: e,
        stackTrace: s,
      );
      _runtimeNetworkRecorder.record(
        method: request.method,
        endpointPath: request.url.path,
        statusClass: 'error',
      );
      rethrow;
    }

    final duration = DateTime.now().difference(start).inMilliseconds;
    final traceId = upstream.headers['x-trace-id'] ?? '-';
    _runtimeNetworkRecorder.record(
      method: request.method,
      endpointPath: request.url.path,
      statusClass: _statusClass(upstream.statusCode),
    );

    if (!kDebugMode) {
      _log(
        'RES ${request.method} ${request.url.path} '
        'req_id=$requestId trace=$traceId '
        'status=${upstream.statusCode} ms=$duration',
      );
      return upstream;
    }

    // Buffer the stream so we can both log the body AND hand a fresh
    // stream back to the caller — `http.BaseClient` consumers expect to
    // read `.body` themselves.
    final bytes = await upstream.stream.toBytes();
    final raw = utf8.decode(bytes, allowMalformed: true);
    final preview = _truncate(raw, _bodyLogCap);
    final keys =
        _runtimeDebugEvidenceEnabled ? '[]' : _extractTopLevelKeys(raw);

    _log(
      'RES ${request.method} ${request.url.path} '
      'req_id=$requestId trace=$traceId '
      'status=${upstream.statusCode} ms=$duration '
      'bytes=${bytes.length} keys=$keys',
    );
    if (!_runtimeDebugEvidenceEnabled) {
      _log('BODY req_id=$requestId body=$preview');
    }

    return http.StreamedResponse(
      Stream.value(bytes),
      upstream.statusCode,
      contentLength: bytes.length,
      request: upstream.request,
      headers: upstream.headers,
      isRedirect: upstream.isRedirect,
      persistentConnection: upstream.persistentConnection,
      reasonPhrase: upstream.reasonPhrase,
    );
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }

  void _log(String message, {Object? error, StackTrace? stackTrace}) {
    // `debugPrint` is `print` in debug + profile mode and a no-op in
    // release. Flutter wraps stdout into OSLog as `(Flutter) flutter:` on
    // iOS, so `simctl log show` can grep the `[ch.mint.http]` tag.
    debugPrint('[$logCategory] $message');
    if (error != null) {
      debugPrint('[$logCategory] error=$error');
    }
    if (stackTrace != null) {
      debugPrint('[$logCategory] stack=$stackTrace');
    }
  }

  String _truncate(String s, int max) =>
      s.length <= max ? s : '${s.substring(0, max)}…[+${s.length - max}]';

  String _extractTopLevelKeys(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final keys = decoded.keys.toList()..sort();
        return '[${keys.join(',')}]';
      }
      if (decoded is List) return '[<list:${decoded.length}>]';
    } catch (_) {
      // Non-JSON body — fine, just skip the keys hint.
    }
    return '[]';
  }

  static String _statusClass(int statusCode) {
    if (statusCode < 100 || statusCode > 599) return 'unknown';
    return '${statusCode ~/ 100}xx';
  }
}

class _RuntimeNetworkRecorder {
  final Map<_RuntimeNetworkKey, int> _counts = {};

  void clear() {
    _counts.clear();
  }

  void record({
    required String method,
    required String endpointPath,
    required String statusClass,
  }) {
    final normalizedMethod = method.toUpperCase();
    final rawPath = endpointPath.isEmpty ? '/' : endpointPath;
    final normalizedPath = _redactEndpointPath(rawPath);
    final key = _RuntimeNetworkKey(
      method: normalizedMethod,
      endpointPath: normalizedPath,
      statusClass: statusClass,
      forbiddenMatch: _hasForbiddenMatch(normalizedMethod, rawPath),
    );
    _counts[key] = (_counts[key] ?? 0) + 1;
  }

  Map<String, Object?> toRedactedJson({required bool recording}) {
    final entries = _counts.entries.map((entry) {
      final key = entry.key;
      return <String, Object?>{
        'method': key.method,
        'endpoint_path': key.endpointPath,
        'status_class': key.statusClass,
        'count': entry.value,
        'forbidden_match': key.forbiddenMatch,
      };
    }).toList(growable: false);

    return {
      'status': recording ? 'recording' : 'not_recording',
      'forbiddenMatchCount':
          entries.where((entry) => entry['forbidden_match'] == true).length,
      'entries': entries,
    };
  }

  static bool _hasForbiddenMatch(String method, String endpointPath) {
    final lower = endpointPath.toLowerCase();
    if (lower.contains('/sync/claim-local-data')) return true;
    if (lower.contains('claimlocaldata')) return true;
    if (lower.contains('/snapshot')) return true;
    if (method != 'GET' && lower.contains('/profiles')) return true;
    if (method != 'GET' && lower.contains('/profile')) return true;
    if (method != 'GET' && lower.contains('/coach')) return true;
    return false;
  }

  static String _redactEndpointPath(String endpointPath) {
    final parts = endpointPath.split('/');
    final redacted = parts.map((segment) {
      if (segment.isEmpty) return segment;
      return _isDynamicSegment(segment) ? ':id' : segment;
    });
    final normalized = redacted.join('/');
    return normalized.isEmpty ? '/' : normalized;
  }

  static bool _isDynamicSegment(String segment) {
    final decoded = Uri.decodeComponent(segment);
    final value = decoded.isEmpty ? segment : decoded;
    if (value.contains('@')) return true;
    if (RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    ).hasMatch(value)) {
      return true;
    }
    if (RegExp(r'^\d+$').hasMatch(value)) return true;
    if (RegExp(r'^[0-9a-f]{8,}$', caseSensitive: false).hasMatch(value)) {
      return true;
    }
    if (RegExp(r'^[A-Za-z0-9_]{16,}$').hasMatch(value) &&
        RegExp(r'[\d_]').hasMatch(value)) {
      return true;
    }
    return false;
  }
}

class _RuntimeNetworkKey {
  final String method;
  final String endpointPath;
  final String statusClass;
  final bool forbiddenMatch;

  const _RuntimeNetworkKey({
    required this.method,
    required this.endpointPath,
    required this.statusClass,
    required this.forbiddenMatch,
  });

  @override
  bool operator ==(Object other) {
    return other is _RuntimeNetworkKey &&
        method == other.method &&
        endpointPath == other.endpointPath &&
        statusClass == other.statusClass &&
        forbiddenMatch == other.forbiddenMatch;
  }

  @override
  int get hashCode => Object.hash(
        method,
        endpointPath,
        statusClass,
        forbiddenMatch,
      );
}
