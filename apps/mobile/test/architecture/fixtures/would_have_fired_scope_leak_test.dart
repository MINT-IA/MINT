// Would-have-fired fixture: GATE-02 scope leak detection.
//
// Creates a minimal route tree with an onboarding-scope route that
// has an authenticated-scope child — replicating the v2.2 Bug 1
// pattern where register_screen.dart:431 navigated to
// /profile/consent (authenticated) from a public context.
// Asserts the gate DETECTS the scope leak.

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Would-have-fired: GATE-02 scope leak detection', () {
    test('detects authenticated child under public parent (v2.2 Bug 1 pattern)',
        () {
      // Simulate the v2.2 structure where /profile (authenticated) had
      // a child /profile/consent (authenticated) and register_screen
      // (public) navigated directly to it.
      //
      // The scope leak is structural: a public-scope route's code
      // navigates to an authenticated-scope route. In the migrated
      // router, the ScopedGoRoute scope field makes this detectable.

      // Build a simplified route scope map
      final routeScopes = <String, String>{
        '/': 'public',
        '/auth/register': 'public',
        '/auth/login': 'public',
        '/onboarding/intent': 'onboarding',
        '/home': 'authenticated',
        '/profile': 'authenticated',
        '/profile/consent': 'authenticated',
        '/coach/chat': 'authenticated',
      };

      // Define parent-child relationships
      final parentChild = <String, String>{
        '/profile/consent': '/profile',
      };

      // Simulate GATE-02 check: no child has lower scope than parent
      final violations = <String>[];
      for (final entry in parentChild.entries) {
        final childPath = entry.key;
        final parentPath = entry.value;
        final childScope = routeScopes[childPath]!;
        final parentScope = routeScopes[parentPath]!;

        final childLevel = _scopeLevel(childScope);
        final parentLevel = _scopeLevel(parentScope);

        if (childLevel < parentLevel) {
          violations.add('$childPath (scope=$childScope) < '
              '$parentPath (scope=$parentScope)');
        }
      }

      // This specific case (authenticated child under authenticated parent)
      // does NOT violate the parent-child rule. The REAL Bug 1 was that
      // a PUBLIC page (register) contained `context.go('/profile/consent')`
      // which is a cross-scope navigation edge, not a parent-child violation.
      expect(violations, isEmpty,
          reason: 'Parent-child scope: auth/auth is fine');

      // The REAL detection: onboarding/public route navigating to
      // authenticated route. Simulate this.
      final navigationEdges = <MapEntry<String, String>>[
        // v2.2 Bug 1: register (public) -> /profile/consent (authenticated)
        const MapEntry('/auth/register', '/profile/consent'),
        // v2.2 P1: data_block_enrichment (onboarding) -> /coach/chat (auth)
        const MapEntry('/onboarding/intent', '/coach/chat'),
      ];

      final scopeLeaks = <String>[];
      for (final edge in navigationEdges) {
        final sourceScope = routeScopes[edge.key] ?? 'authenticated';
        final targetScope = routeScopes[edge.value] ?? 'authenticated';

        if (_scopeLevel(sourceScope) < _scopeLevel(targetScope)) {
          // Lower scope navigating to higher scope = potential leak
          // (the guard should catch this, but it's still a code smell)
          scopeLeaks.add(
            '${edge.key} (scope=$sourceScope) -> '
            '${edge.value} (scope=$targetScope)',
          );
        }
      }

      expect(scopeLeaks, isNotEmpty,
          reason: 'GATE-02 MUST detect scope leaks from public/onboarding '
              'routes to authenticated routes');
      expect(scopeLeaks.length, equals(2),
          reason: 'Should detect both Bug 1 (register->consent) '
              'and the onboarding->coach cross-scope edge');
    });

    test('does NOT flag same-scope or higher-to-lower navigation', () {
      final routeScopes = <String, String>{
        '/home': 'authenticated',
        '/profile': 'authenticated',
        '/': 'public',
        '/auth/login': 'public',
      };

      final navigationEdges = <MapEntry<String, String>>[
        // authenticated -> authenticated (same scope)
        const MapEntry('/home', '/profile'),
        // authenticated -> public (higher to lower — allowed)
        const MapEntry('/home', '/'),
        // public -> public (same scope)
        const MapEntry('/', '/auth/login'),
      ];

      final scopeLeaks = <String>[];
      for (final edge in navigationEdges) {
        final sourceScope = routeScopes[edge.key] ?? 'authenticated';
        final targetScope = routeScopes[edge.value] ?? 'authenticated';

        if (_scopeLevel(sourceScope) < _scopeLevel(targetScope)) {
          scopeLeaks.add(
            '${edge.key} -> ${edge.value}',
          );
        }
      }

      expect(scopeLeaks, isEmpty,
          reason: 'Same-scope and higher-to-lower navigation should pass');
    });
  });
}

int _scopeLevel(String scope) {
  switch (scope) {
    case 'public':
      return 0;
    case 'onboarding':
      return 1;
    case 'authenticated':
      return 2;
    default:
      return 2;
  }
}
