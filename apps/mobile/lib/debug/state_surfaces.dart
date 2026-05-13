import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/debug/debug_registry.dart';
import 'package:mint_mobile/debug/ring_buffer.dart';
import 'package:mint_mobile/services/observability/mint_http_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Built-in debug-state surfaces.
///
/// Registers each surface into [DebugRegistry] under a stable name. The
/// HTTP server reads the registry blind, so adding a new surface is one
/// new top-level function + one `register` call below.
///
/// Schema invariants (Tier 2 contract, panel-locked 2026-05-13):
///   - Each surface returns a flat-ish `Map<String, dynamic>` so the
///     LLM agent can `jq '.providers.anonymousSession.messagesRemaining'`
///     without recursing through arbitrary depth.
///   - String values, ints, bools, and `List<Map<String, dynamic>>` are
///     allowed. Anything else gets stringified by [_safe] at write time.
///   - Add `_meta` at the snapshot root, not per-surface, for cheap
///     framing-id reads.
class DebugStateSurfaces {
  DebugStateSurfaces._();

  /// Whitelist of `SharedPreferences` keys safe to expose. Anything not
  /// in here is dropped from the snapshot — fintech threat model says
  /// **whitelist, do not blacklist**.
  static const Set<String> prefsWhitelist = {
    'anonymous_message_count',
    'auth_local_mode',
    'mvp_onboarding_completed',
    'mvp_onboarding_step',
    'mint_locale',
    'has_seen_landing',
    'has_seen_beta_modal',
    'has_finished_onboarding',
  };

  static void registerBuiltins({required GoRouter router}) {
    DebugRegistry.register('router', () => _routerSurface(router));
    DebugRegistry.register('http', _httpSurface);
    DebugRegistry.register('prefs', _prefsSurface);
  }

  // ─── Router ─────────────────────────────────────────────────────────

  /// Snapshot of the GoRouter stack. Defers a single frame via
  /// [SchedulerBinding.endOfFrame] so the agent never sees an in-flight
  /// navigation animation that flaps between routes. The wait is capped
  /// at 100 ms so a test isolate that never pumps a frame, or a sim that
  /// is currently backgrounded, cannot stall the snapshot indefinitely.
  static Future<Map<String, dynamic>> _routerSurface(GoRouter router) async {
    try {
      await SchedulerBinding.instance.endOfFrame
          .timeout(const Duration(milliseconds: 100));
    } catch (_) {
      // No binding, no scheduled frame, or genuine timeout — fall back
      // to the current (possibly mid-transition) configuration.
    }
    final config = router.routerDelegate.currentConfiguration;
    final stack = config.matches.map<Map<String, dynamic>>((m) {
      final route = m.route;
      return {
        'path': m.matchedLocation,
        'name': route is GoRoute ? (route.name ?? '') : '',
      };
    }).toList();
    return {
      'currentRoute': stack.isNotEmpty ? stack.last['path'] : '/',
      'stack': stack,
      'canPop': stack.length > 1,
    };
  }

  // ─── HTTP buffer (last N events from MintHttpClient) ────────────────

  static Map<String, dynamic> _httpSurface() {
    final buffer = MintHttpClient.eventBuffer;
    if (buffer == null) {
      return {
        'inflightCount': MintHttpClient.inflightCount,
        'count': 0,
        'events': const <Map<String, dynamic>>[],
      };
    }
    final events = buffer.toList().map((e) => e.toDebugJson()).toList();
    return {
      'inflightCount': MintHttpClient.inflightCount,
      'count': events.length,
      'events': events,
    };
  }

  // ─── SharedPreferences (whitelist-filtered) ─────────────────────────

  static Future<Map<String, dynamic>> _prefsSurface() async {
    final prefs = await SharedPreferences.getInstance();
    final out = <String, dynamic>{};
    for (final key in prefsWhitelist) {
      if (!prefs.containsKey(key)) continue;
      out[key] = _safePrefValue(prefs, key);
    }
    return out;
  }

  static dynamic _safePrefValue(SharedPreferences prefs, String key) {
    final raw = prefs.get(key);
    if (raw == null || raw is num || raw is bool || raw is String) {
      return raw;
    }
    if (raw is List<String>) return raw;
    return raw.toString();
  }
}

/// Initialise the HTTP-event ring buffer that backs the `/http` surface.
/// Idempotent: call from `DebugServer.start()` before registering
/// surfaces so the buffer exists when the first request lands.
RingBuffer<MintHttpEvent> installHttpEventBuffer({int capacity = 50}) {
  final existing = MintHttpClient.eventBuffer;
  if (existing != null) return existing;
  final buffer = RingBuffer<MintHttpEvent>(capacity);
  MintHttpClient.eventBuffer = buffer;
  return buffer;
}
