// Phase 32 Wave 0 fixture — parity lint drift test case.
// Used by tools/checks/route_registry_parity.py --dry-run-fixture.
// Expected behavior: parity lint MUST exit non-zero when
// app.dart has a GoRoute absent from kRouteRegistry.
//
// Simulated app.dart snippet (has routes):
//   GoRoute(path: '/a', ...)
//   GoRoute(path: '/b', ...)
//   GoRoute(path: '/c-drift-only-in-code', ...)  // <-- drift
//
// Simulated kRouteRegistry keys: ['/a', '/b']
// Expected: lint exits 1, stderr mentions '/c-drift-only-in-code'.
//
// Wave 4 (Plan 32-04) wires tools/checks/route_registry_parity.py to accept
// --dry-run-fixture pointing at this file. Until then, this file is documentation
// for the expected lint behavior.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// Simulated router (do not import; this file is fixture-only, not compiled
// into mint_mobile).
final _simulatedRouter = GoRouter(
  routes: [
    GoRoute(path: '/a', builder: (_, __) => const SizedBox()),
    GoRoute(path: '/b', builder: (_, __) => const SizedBox()),
    GoRoute(path: '/c-drift-only-in-code', builder: (_, __) => const SizedBox()),
  ],
);

// Simulated kRouteRegistry: missing '/c-drift-only-in-code' deliberately.
const List<String> _simulatedRegistryKeys = ['/a', '/b'];

// Reference use to avoid "unused" lint if this file is analyzed.
// ignore: unused_element
Object? _noop() => [_simulatedRouter, _simulatedRegistryKeys];
