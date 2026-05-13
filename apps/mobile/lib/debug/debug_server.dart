import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/debug/debug_registry.dart';
import 'package:mint_mobile/debug/state_surfaces.dart';

/// In-app HTTP server that exposes [DebugRegistry] surfaces for an LLM
/// agent driving Maestro flows. **Debug builds only.** Triple-gated by:
///
///   1. `kDebugMode` — false in release, code is dead-code-eliminated.
///   2. `--dart-define=MINT_DEBUG_ENDPOINT=true` — opt-in per build.
///   3. Random per-launch bearer token — defends against intra-device
///      loopback scans on a debug-ipa that escaped to TestFlight.
///
/// See `lib/debug/debug_facade.dart` for the public entry point and the
/// release-build stub.
///
/// ## Token retrieval (Maestro / runScript host-side)
///
/// `_writeTokenFile` writes to `Directory.systemTemp`, which is **not**
/// `/tmp` on iOS — it resolves to the app sandbox
/// `Application/<UUID>/tmp/`. The Maestro `runScript:` block runs on the
/// host Mac, NOT inside the simulator, so reach the file via:
///
/// ```bash
/// APP_DATA=$(xcrun simctl get_app_container booted ch.mint.mobile data)
/// TOKEN=$(cat "$APP_DATA/tmp/mint_debug.token")
/// curl -sS -H "Authorization: Bearer $TOKEN" \
///   http://127.0.0.1:8181/debug/state/prefs | jq .
/// ```
///
/// Primary channel is still the stdout log line — `_serve()` prints the
/// resolved absolute path on bind, so an OSLog grep is the canonical
/// recovery path if the file write fails (read-only fs, sandbox quirk).
class DebugServer {
  DebugServer._({required this.server, required this.bearerToken});

  final HttpServer server;
  final String bearerToken;

  static const String schemaVersion = 'v1';
  static const String _tokenFileName = 'mint_debug.token';

  static DebugServer? _instance;

  static DebugServer? get instance => _instance;

  /// Starts the debug server on [port] (default 8181), binds to loopback,
  /// writes the bearer token to a temp file the Maestro runner can read,
  /// and registers built-in surfaces ([router], `http`, `prefs`).
  ///
  /// Idempotent: re-calls return the existing instance.
  static Future<DebugServer?> start({
    required GoRouter router,
    int port = 8181,
  }) async {
    // Hard release guard — even if the compile-time gate slips, no thread
    // ever binds in release.
    if (!kDebugMode) return null;

    if (_instance != null) return _instance;

    // Seed the HTTP-event ring buffer BEFORE registering surfaces so the
    // first poll never returns null.
    installHttpEventBuffer();

    final server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      port,
      shared: false,
    );

    final token = _generateToken();
    final tokenPath = await _writeTokenFile(token);

    DebugStateSurfaces.registerBuiltins(router: router);

    final instance = DebugServer._(server: server, bearerToken: token);
    _instance = instance;

    // Detached request loop. `await for` keeps Dart from holding the
    // server up; the loop ends when [stop] closes the server.
    unawaited(instance._serve());

    // Stdout is the primary token-discovery channel (greppable from the
    // host via `xcrun simctl spawn booted log show`). The file at
    // [tokenPath] is a convenience for desktop dev — on iOS sim it lives
    // inside the app sandbox (see file-header doc), NOT host `/tmp`.
    // ignore: avoid_print
    print( // intentionally raw stdout — E2E harness greps the port handshake
        '[ch.mint.debug] DebugServer listening on '
        '127.0.0.1:${server.port} '
        '(token at ${tokenPath ?? "<file-write-failed; use stdout grep>"})');

    return instance;
  }

  Future<void> stop() async {
    await server.close(force: true);
    if (_instance == this) _instance = null;
  }

  Future<void> _serve() async {
    try {
      await for (final req in server) {
        try {
          await _dispatch(req);
        } catch (e) {
          // Never let one bad surface bring down the server.
          try {
            await _writeJson(req, 500, {'error': e.toString()});
          } catch (_) {/* response already closed */}
        }
      }
    } catch (_) {
      // Server closed.
    }
  }

  Future<void> _dispatch(HttpRequest req) async {
    final path = req.uri.path;

    // /debug/health is intentionally unauthenticated — Maestro and CI
    // probes need a quick reachability check without the bearer.
    if (req.method == 'GET' && (path == '/debug/health')) {
      await _writeJson(req, 200, {
        'ok': true,
        'schema': schemaVersion,
        'uptimeMs':
            DateTime.now().difference(_startedAt).inMilliseconds,
      });
      return;
    }

    // Bearer-auth for every other endpoint.
    if (!_isAuthed(req)) {
      await _writeJson(req, 401, {'error': 'unauthorised'});
      return;
    }

    if (req.method == 'GET' && path == '/debug/state') {
      final snap = await _snapshot();
      await _writeJson(req, 200, snap);
      return;
    }

    if (req.method == 'GET' && path.startsWith('/debug/state/')) {
      final surface = path.substring('/debug/state/'.length);
      final snap = await DebugRegistry.snapshot(include: [surface]);
      if (snap.isEmpty) {
        await _writeJson(
            req, 404, {'error': 'unknown_surface', 'name': surface});
        return;
      }
      await _writeJson(req, 200, {
        '_meta': _meta(),
        surface: snap[surface],
      });
      return;
    }

    await _writeJson(req, 404, {'error': 'not_found', 'path': path});
  }

  Future<Map<String, dynamic>> _snapshot() async {
    final body = await DebugRegistry.snapshot();
    return {
      '_meta': _meta(),
      ...body,
    };
  }

  Map<String, dynamic> _meta() => {
        'schema': schemaVersion,
        'capturedAt': DateTime.now().toIso8601String(),
        'surfaces': DebugRegistry.names(),
      };

  bool _isAuthed(HttpRequest req) {
    final header = req.headers.value(HttpHeaders.authorizationHeader);
    if (header == null) return false;
    if (!header.startsWith('Bearer ')) return false;
    final got = header.substring('Bearer '.length).trim();
    // Constant-time compare — same length + bitwise xor — to avoid
    // remote timing oracles. Bearer is 43 chars (32 bytes base64url).
    return _constantTimeEquals(got, bearerToken);
  }

  Future<void> _writeJson(
      HttpRequest req, int status, Map<String, dynamic> body) async {
    req.response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..headers.add('Cache-Control', 'no-store')
      ..write(jsonEncode(body));
    await req.response.close();
  }

  // ─── Helpers ────────────────────────────────────────────────────────

  static String _generateToken() {
    final rng = Random.secure();
    final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  /// Writes the bearer token to `<systemTemp>/mint_debug.token`. Returns
  /// the resolved absolute path on success, `null` on failure (read-only
  /// fs / sandbox quirk). On POSIX hosts we chmod 0600 so a co-tenant on
  /// the same CI worker cannot read the token before it rotates next
  /// launch.
  static Future<String?> _writeTokenFile(String token) async {
    try {
      final dir = Directory.systemTemp;
      final file = File('${dir.path}/$_tokenFileName');
      await file.writeAsString(token, flush: true);
      if (!Platform.isWindows) {
        // chmod 600 — owner read/write only. Best-effort: failures on
        // platforms with a non-POSIX filesystem semantics are non-fatal
        // because the next-launch rotation already bounds blast radius
        // to one session.
        try {
          await Process.run('chmod', ['600', file.path]);
        } catch (_) {/* best-effort */}
      }
      return file.path;
    } catch (_) {
      // tmpdir unavailable — token still works via stdout log line.
      return null;
    }
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  final DateTime _startedAt = DateTime.now();
}
