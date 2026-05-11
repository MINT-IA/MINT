// Phase 96 D-18 — Dart metaphor resolver, mirrors the backend Python.
//
// Loads `assets/metaphors.toml` from the asset bundle once at app boot via
// `MetaphorLookup.loadFromAssets()`. The TOML file is byte-equal to its
// backend mirror at `services/backend/app/data/metaphors.toml` — parity
// enforced by `tools/checks/metaphor_parity.py` + lefthook pre-commit.
//
// Karpathy #2 simplicity-first : single static cache, no async lookup,
// no listener API. The narrator response payload supplies the metaphor
// already-resolved server-side (Plan 96-03+ wires the backend mirror) ;
// the Dart side is the failover surface when the response field is empty.

import 'package:flutter/services.dart' show rootBundle;
import 'package:toml/toml.dart';

/// Static metaphor library resolver. Call [loadFromAssets] once at app
/// boot — before any widget consumes [lookup]. Misses (unknown triplet,
/// resolver not yet loaded) return the empty string by contract.
class MetaphorLookup {
  // Parsed-TOML cache. `null` until [loadFromAssets] resolves.
  static Map<String, dynamic>? _loaded;

  /// Visible for testing — allows tests to inject a fake TOML map without
  /// touching the asset bundle. Production code MUST NOT call this ;
  /// production code calls [loadFromAssets].
  static void debugSetLoaded(Map<String, dynamic>? map) {
    _loaded = map;
  }

  /// Whether the resolver has loaded the asset.  Hooked by widget tests
  /// that need to assert loadFromAssets() ran during app boot.
  static bool get isLoaded => _loaded != null;

  /// Load `assets/metaphors.toml` from the bundle and cache the parsed
  /// map. Idempotent — repeat calls are safe but redundant.
  ///
  /// Wire into `apps/mobile/lib/main.dart` before `runApp(...)` so the
  /// resolver is ready by the time the first NarrativeSleeve renders.
  static Future<void> loadFromAssets() async {
    final tomlString = await rootBundle.loadString('assets/metaphors.toml');
    final document = TomlDocument.parse(tomlString);
    _loaded = document.toMap();
  }

  /// Return the metaphor string for the [archetype] × [canton] ×
  /// [lifeEvent] triplet, or the empty string on miss. Empty string is
  /// also returned when the resolver has not yet loaded — callers are
  /// expected to conditionally render the metaphor block based on the
  /// returned string's emptiness.
  static String lookup({
    required String archetype,
    required String canton,
    required String lifeEvent,
  }) {
    final loaded = _loaded;
    if (loaded == null) return '';
    final archMap = loaded[archetype];
    if (archMap is! Map) return '';
    final cantonMap = archMap[canton];
    if (cantonMap is! Map) return '';
    final eventMap = cantonMap[lifeEvent];
    if (eventMap is! Map) return '';
    final m = eventMap['metaphor'];
    return m is String ? m : '';
  }
}
