// Phase 32 Wave 4 (Plan 32-04) fixture — parity lint KNOWN-MISSES respect test.
//
// Consumed by tools/checks/route_registry_parity.py --dry-run-fixture.
// Expected behavior: parity lint MUST exit 0. The only path expressions in
// the simulated app.dart are unparsable by the regex (ternary + dynamic) —
// both explicitly covered by tools/checks/route_registry_parity-KNOWN-MISSES.md
// Category 2 + Category 3. Zero literal paths extracted, zero registry keys,
// parity trivially holds.
//
// Simulated inputs:
//   APP_DART_PATHS = []  (ternary + dynamic are silently skipped by regex)
//   REGISTRY_KEYS  = []

// ignore_for_file: unused_element, unused_local_variable, dead_code

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

bool isNew = true;
String _buildDynamicPath(String seg) => '/dynamic/$seg';

// -- BEGIN fake app.dart --
final _simulatedRouter = GoRouter(
  routes: [
    // Category 2 — ternary path expression (regex-unparsable).
    GoRoute(
      path: isNew ? '/v2' : '/legacy',
      builder: (_, __) => const SizedBox(),
    ),
    // Category 3 — dynamic path builder (regex-unparsable).
    GoRoute(
      path: _buildDynamicPath('seg'),
      builder: (_, __) => const SizedBox(),
    ),
  ],
);
// -- END fake app.dart --

// -- BEGIN fake registry --
const Map<String, RouteMeta> kRouteRegistry = <String, RouteMeta>{};
// -- END fake registry --

Object? _noop() => [_simulatedRouter, kRouteRegistry];
