import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

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
///     --predicate 'category == "ch.mint.http"' --style compact
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

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final requestId = _uuid.v4();
    request.headers[requestIdHeader] = requestId;
    final start = DateTime.now();

    // S98 Phase 2 — promote the X-MINT-Req-Id to a Sentry-searchable
    // tag on the current scope. A crash thrown anywhere during this
    // request now ships to Sentry with `mint_request_id=<uuid>`, which
    // is the join key into Railway backend logs (echoed as X-Trace-Id).
    // No-op when Sentry SDK is not initialised (tests, debug builds
    // without SENTRY_DSN dart-define).
    Sentry.configureScope((scope) {
      scope.setTag('mint_request_id', requestId);
    });

    _log(
      'REQ ${request.method} ${request.url.path} '
      'req_id=$requestId host=${request.url.host}',
    );

    http.StreamedResponse upstream;
    try {
      upstream = await _inner.send(request);
    } catch (e, s) {
      _log(
        'ERR ${request.method} ${request.url.path} '
        'req_id=$requestId error=$e',
        error: e,
        stackTrace: s,
      );
      rethrow;
    }

    final duration = DateTime.now().difference(start).inMilliseconds;
    final traceId = upstream.headers['x-trace-id'] ?? '-';

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
    final keys = _extractTopLevelKeys(raw);

    _log(
      'RES ${request.method} ${request.url.path} '
      'req_id=$requestId trace=$traceId '
      'status=${upstream.statusCode} ms=$duration '
      'bytes=${bytes.length} keys=$keys',
    );
    _log('BODY req_id=$requestId body=$preview');

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
    developer.log(
      message,
      name: logCategory,
      error: error,
      stackTrace: stackTrace,
    );
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
}
