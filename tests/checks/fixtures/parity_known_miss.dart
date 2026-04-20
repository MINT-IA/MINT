// Phase 32 Wave 0 fixture — parity lint KNOWN-MISSES respect test.
// Expected behavior: parity lint MUST exit 0 when the only "missing"
// paths are documented in KNOWN-MISSES.md categories (ternary, dynamic).
//
// Simulated app.dart snippet (unparsable):
//   GoRoute(path: isNew ? '/v2' : '/legacy', ...)     // Category 2 ternary
//   GoRoute(path: _buildDynamicPath(seg), ...)        // Category 3 dynamic
//
// Simulated kRouteRegistry keys: []
// Expected: lint exits 0, stderr lists these as known-miss acknowledged.
//
// Wave 4 (Plan 32-04) wires tools/checks/route_registry_parity.py to accept
// --dry-run-fixture pointing at this file. Until then, this file is documentation
// for the expected lint behavior.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// ignore_for_file: unused_element, unused_local_variable, dead_code

// Simulated module-level state used by the fixture.
bool isNew = true;
String _buildDynamicPath(String seg) => '/dynamic/$seg';

// Simulated router with unparseable path expressions (category 2 + category 3).
// The parity lint regex CANNOT extract a literal path from either. Both are
// explicitly covered by route_registry_parity-KNOWN-MISSES.md.
final _simulatedRouter = GoRouter(
  routes: [
    GoRoute(
      path: isNew ? '/v2' : '/legacy', // Category 2 ternary
      builder: (_, __) => const SizedBox(),
    ),
    GoRoute(
      path: _buildDynamicPath('seg'), // Category 3 dynamic builder
      builder: (_, __) => const SizedBox(),
    ),
  ],
);

// Simulated empty kRouteRegistry: both paths are known-miss, so the empty
// registry is the expected state — lint must NOT flag these as drift.
const List<String> _simulatedRegistryKeys = <String>[];

Object? _noop() => [_simulatedRouter, _simulatedRegistryKeys];
