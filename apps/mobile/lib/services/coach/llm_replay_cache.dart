/// Phase 90 PERS-05 (v2.13) — LLM replay-cache reader.
///
/// Per panel-locked architecture
/// (`.planning/decisions/2026-05-05-persona-narrative-scenario-coverage-panel.md`)
/// hard rule #3 : « ANY backend dependency MUST have a recorded-fixture
/// mock. ANTHROPIC_API_KEY must NOT gate any script. »
///
/// This is the runtime side of the cache. Reading only — recording is
/// done externally by `tools/simulator/record_replay_fixture.sh`
/// (Phase A4) which captures a live walker response + writes the JSON
/// fixture to the repo's `assets/llm_replay_cache/` tree, then the
/// developer runs `flutter pub get` to bundle the asset.
///
/// Modes (read from dart-define `MINT_LLM_CACHE_MODE`) :
///   - `replay` (default for walker / widget tests) : look up fixture
///     by (archetype, locale, scenario, turn, prompt_hash). Hit returns
///     the cached response. Miss raises `MissingReplayCacheError`
///     loudly (Phase 51 anti-trap : never silently fall back to live).
///   - `record` : caller is responsible for persisting to repo path
///     externally. This service is read-only and ignores `record`
///     (treated as `live`).
///   - `live` : returns null, caller does the normal HTTP call.
///
/// Cache key derivation matches `tools/simulator/cache/replay/SCHEMA.md` :
///   sha256(archetype + "|" + locale + "|" + forced_kind + "|" + turn +
///          "|" + prompt_normalized)[:16]
///
/// **Release builds** : `kReleaseMode` short-circuit returns null
/// unconditionally. The replay-cache is debug/profile only — production
/// users always hit the live backend, never read fixture data.

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

class MissingReplayCacheError implements Exception {
  final String key;
  final String assetPath;
  const MissingReplayCacheError(this.key, this.assetPath);
  @override
  String toString() =>
      'MissingReplayCacheError: no fixture at $assetPath for key $key. '
      'Either run `tools/simulator/record_replay_fixture.sh` to capture '
      'a live response, or set MINT_LLM_CACHE_MODE=live to bypass cache.';
}

class LlmReplayCache {
  LlmReplayCache._();

  static const String _modeDefine = String.fromEnvironment(
    'MINT_LLM_CACHE_MODE',
    defaultValue: 'live',
  );

  static const String _archetypeDefine = String.fromEnvironment(
    'MINT_E2E_ARCHETYPE',
    defaultValue: '',
  );

  static const String _forcedKindDefine = String.fromEnvironment(
    'MINT_E2E_FORCE_ECLAIRAGE_KIND',
    defaultValue: '',
  );

  static String get mode {
    if (kReleaseMode) return 'live';
    return _modeDefine.trim().toLowerCase();
  }

  /// Returns true when the cache should intercept HTTP calls.
  static bool get isReplayActive => mode == 'replay';

  /// Look up a cached response. Returns null if cache mode is `live`,
  /// throws `MissingReplayCacheError` if mode is `replay` and the
  /// fixture is absent.
  ///
  /// `scenario` defaults to `premier_eclairage` for the first chat
  /// scenario ; future scenarios (FATCA, deuil, rente-vs-capital, etc.)
  /// pass an explicit value.
  static Future<Map<String, dynamic>?> lookup({
    required int turn,
    required String prompt,
    required String locale,
    String scenario = 'premier_eclairage',
  }) async {
    // Phase A5 (v2.13) — defence in depth. The `mode` getter already
    // forces 'live' under kReleaseMode (line 67), but a future refactor
    // could regress that without breaking unit tests. This second guard
    // throws a hard StateError if anyone manages to reach the lookup
    // path in a release build — making the regression visible at
    // runtime instead of silently shipping fixture data to end users.
    if (kReleaseMode) {
      throw StateError(
        'LlmReplayCache.lookup invoked in kReleaseMode. The replay '
        'cache is debug/profile only ; production users must hit the '
        'live backend. Audit the call site.',
      );
    }
    if (mode != 'replay') return null;
    if (_archetypeDefine.isEmpty) {
      // Replay mode requested but no archetype seeded → operational
      // misconfiguration. Loud failure.
      throw const MissingReplayCacheError(
        'no-archetype',
        'MINT_E2E_ARCHETYPE dart-define empty in replay mode',
      );
    }

    final assetPath = 'assets/llm_replay_cache/$_archetypeDefine/$locale/'
        '${scenario}_turn_${turn.toString().padLeft(2, '0')}.json';

    final key = _deriveKey(
      archetype: _archetypeDefine,
      locale: locale,
      forcedKind: _forcedKindDefine,
      turn: turn,
      prompt: prompt,
    );

    String raw;
    try {
      raw = await rootBundle.loadString(assetPath);
    } catch (_) {
      throw MissingReplayCacheError(key, assetPath);
    }

    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final responseEnvelope =
        (decoded['response'] as Map<String, dynamic>?) ?? const {};
    final body = (responseEnvelope['body'] as Map<String, dynamic>?) ??
        responseEnvelope;
    return body;
  }

  static String _deriveKey({
    required String archetype,
    required String locale,
    required String forcedKind,
    required int turn,
    required String prompt,
  }) {
    final normalized = prompt.trim().toLowerCase();
    final material = '$archetype|$locale|$forcedKind|$turn|$normalized';
    final digest = sha256.convert(utf8.encode(material));
    return digest.toString().substring(0, 16);
  }
}
