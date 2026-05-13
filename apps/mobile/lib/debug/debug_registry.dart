import 'dart:async';

/// A function that returns a debug-state snapshot for one surface.
///
/// Surfaces are registered by name (e.g. `router`, `http`, `prefs`); the
/// debug server collects them in parallel and serialises the result to
/// JSON. Each function must complete in < 50 ms to keep the agent's poll
/// loop tight.
typedef DebugSurfaceFn = FutureOr<Map<String, dynamic>> Function();

/// Process-wide registry of debug surfaces.
///
/// Designed for opt-in coupling: each subsystem (auth, chat, onboarding,
/// MintHttpClient) calls [register] when initialised. The debug server has
/// no dependency on those subsystems — it walks the registry blind. Means
/// dropping a surface is a single delete; adding one is a single import.
class DebugRegistry {
  DebugRegistry._();

  static final Map<String, DebugSurfaceFn> _surfaces = {};

  /// Registers (or overwrites) a surface. Idempotent.
  static void register(String name, DebugSurfaceFn fn) {
    _surfaces[name] = fn;
  }

  /// Removes a surface. Idempotent.
  static void unregister(String name) {
    _surfaces.remove(name);
  }

  /// Returns the registered surface names, sorted.
  static List<String> names() {
    final keys = _surfaces.keys.toList()..sort();
    return keys;
  }

  /// Drops every registered surface — debug-build teardown only.
  static void reset() => _surfaces.clear();

  /// Calls every selected surface in parallel; errors are caught and
  /// surfaced as `_error` so a single broken surface does not poison the
  /// whole snapshot.
  ///
  /// Pass [include] to filter — defaults to all registered surfaces.
  static Future<Map<String, dynamic>> snapshot({
    Iterable<String>? include,
  }) async {
    final selected = (include ?? _surfaces.keys).toList();
    final futures = <Future<MapEntry<String, Map<String, dynamic>>>>[];
    for (final name in selected) {
      final fn = _surfaces[name];
      if (fn == null) continue;
      futures.add(_invoke(name, fn));
    }
    final entries = await Future.wait(futures);
    return Map.fromEntries(entries);
  }

  static Future<MapEntry<String, Map<String, dynamic>>> _invoke(
    String name,
    DebugSurfaceFn fn,
  ) async {
    try {
      final result = await fn();
      return MapEntry(name, result);
    } catch (e, stack) {
      return MapEntry(name, {
        '_error': e.toString(),
        '_stack': stack.toString().split('\n').take(3).join(' | '),
      });
    }
  }
}
