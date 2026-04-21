// Phase 32 Wave 4 (Plan 32-04) fixture — parity lint drift test case.
//
// Consumed by tools/checks/route_registry_parity.py --dry-run-fixture.
// Expected behavior: parity lint MUST exit 1 (drift) and stderr MUST
// mention '/c-drift-only-in-code'.
//
// Simulated inputs encoded in the file:
//   APP_DART_PATHS = ['/a', '/b', '/c-drift-only-in-code']
//   REGISTRY_KEYS  = ['/a', '/b']
//
// The lint splits this file on the marker lines below and runs parity
// against the two synthetic blocks.

// ignore_for_file: unused_element, unused_local_variable, dead_code

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// -- BEGIN fake app.dart --
final _simulatedRouter = GoRouter(
  routes: [
    GoRoute(path: '/a', builder: (_, __) => const SizedBox()),
    ScopedGoRoute(
      path: '/b',
      builder: (_, __) => const SizedBox(),
    ),
    GoRoute(path: '/c-drift-only-in-code', builder: (_, __) => const SizedBox()),
  ],
);
// -- END fake app.dart --

// -- BEGIN fake registry --
const Map<String, RouteMeta> kRouteRegistry = <String, RouteMeta>{
  '/a': RouteMeta(path: '/a', category: RouteCategory.destination, owner: RouteOwner.system, requiresAuth: false),
  '/b': RouteMeta(path: '/b', category: RouteCategory.destination, owner: RouteOwner.system, requiresAuth: false),
};
// -- END fake registry --

Object? _noop() => [_simulatedRouter, kRouteRegistry];
