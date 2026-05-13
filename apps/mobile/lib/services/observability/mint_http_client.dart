import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:mint_mobile/debug/ring_buffer.dart';
import 'package:uuid/uuid.dart';

/// One captured outbound HTTP call. Header / body content is NOT held —
/// see [MintHttpClient.eventBuffer] for the opt-in capture point and
/// `lib/debug/state_surfaces.dart` for PII redaction at read time.
class MintHttpEvent {
  MintHttpEvent({
    required this.ts,
    required this.method,
    required this.urlHost,
    required this.urlPath,
    required this.requestId,
    required this.traceId,
    required this.statusCode,
    required this.durationMs,
    required this.responseKeys,
    required this.responseBytes,
  });

  final DateTime ts;
  final String method;
  final String urlHost;
  final String urlPath;
  final String requestId;
  final String traceId;
  final int statusCode;
  final int durationMs;
  final List<String> responseKeys;
  final int responseBytes;

  Map<String, dynamic> toDebugJson() => {
        'ts': ts.toIso8601String(),
        'method': method,
        'host': urlHost,
        'path': urlPath,
        'reqId': requestId,
        'trace': traceId,
        'status': statusCode,
        'ms': durationMs,
        'keys': responseKeys,
        'bytes': responseBytes,
      };
}

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

  /// Opt-in ring buffer of recent outbound calls. Null by default; set
  /// by `DebugServer.start()` in debug builds so the Tier 2 state
  /// endpoint can surface the last N HTTP events without coupling
  /// `MintHttpClient` to the debug subsystem.
  static RingBuffer<MintHttpEvent>? eventBuffer;

  /// Count of in-flight outbound calls. Used by the network-quiescence
  /// assertion pattern in Maestro flows (see
  /// `lib/debug/state_surfaces.dart`).
  static int inflightCount = 0;

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
    inflightCount += 1;

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
      // Inflight counter must decrement on error path too — line 154
      // post-try only fires on success ; without this the gauge leaks
      // across exceptional HTTP failures.
      inflightCount = (inflightCount - 1).clamp(0, 1 << 30);
      _log(
        'ERR ${request.method} ${request.url.path} '
        'req_id=$requestId error=$e',
        error: e,
        stackTrace: s,
      );
      rethrow;
    }
    inflightCount = (inflightCount - 1).clamp(0, 1 << 30);

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

    eventBuffer?.add(MintHttpEvent(
      ts: DateTime.now(),
      method: request.method,
      urlHost: request.url.host,
      urlPath: request.url.path,
      requestId: requestId,
      traceId: traceId,
      statusCode: upstream.statusCode,
      durationMs: duration,
      responseKeys: _extractTopLevelKeyList(raw),
      responseBytes: bytes.length,
    ));

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

  /// Like [_extractTopLevelKeys] but returns a `List<String>` for
  /// structured consumption (debug-state JSON).
  List<String> _extractTopLevelKeyList(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final keys = decoded.keys.toList()..sort();
        return keys;
      }
    } catch (_) {/* non-JSON */}
    return const <String>[];
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
