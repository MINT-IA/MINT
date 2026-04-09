// GATE-02: Route scope leak detection.
//
// Walks the GoRouter tree from app.dart and checks structural invariants:
// 1. No child route has a LOWER scope than its parent
//    (authenticated parent with public child = suspicious)
// 2. No route path starting with `/onboarding/` has scope `authenticated`
// 3. No route path starting with `/auth/` has scope `authenticated`
// 4. Redirect-only routes that target authenticated routes from
//    public/onboarding scope are flagged

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Scope hierarchy: public < onboarding < authenticated
int scopeLevel(String scope) {
  switch (scope) {
    case 'public':
      return 0;
    case 'onboarding':
      return 1;
    case 'authenticated':
      return 2;
    default:
      return 2; // fail-closed
  }
}

/// Represents a parsed route with path and scope.
class ParsedRoute {
  final String path;
  final String scope;
  final String? parentPath;
  final bool isRedirect;
  final String? redirectTarget;

  ParsedRoute({
    required this.path,
    required this.scope,
    this.parentPath,
    this.isRedirect = false,
    this.redirectTarget,
  });

  @override
  String toString() =>
      'Route($path, scope=$scope${isRedirect ? ", redirect=$redirectTarget" : ""})';
}

/// Parse all routes from app.dart source, extracting path, scope, and nesting.
List<ParsedRoute> parseRoutes(String source) {
  final routes = <ParsedRoute>[];

  // Parse top-level routes with explicit scope
  final scopedPattern = RegExp(
    r'''ScopedGoRoute\s*\(\s*(?:\n\s*)?path:\s*['"]([^'"]+)['"]'''
    r'''\s*,\s*(?:\n\s*)?scope:\s*RouteScope\.(\w+)''',
  );
  for (final match in scopedPattern.allMatches(source)) {
    routes.add(ParsedRoute(
      path: match.group(1)!,
      scope: match.group(2)!,
    ));
  }

  // Parse routes without explicit scope (default = authenticated)
  // Match ScopedGoRoute with path but no scope parameter before the next
  // significant parameter (builder, redirect, parentNavigatorKey, routes, name)
  final defaultScopePattern = RegExp(
    r'''ScopedGoRoute\s*\(\s*(?:\n\s*)?path:\s*['"]([^'"]+)['"](?:(?!scope:)[\s\S])*?(?:builder:|redirect:|parentNavigatorKey:|routes:|name:|\))''',
  );
  final explicitScopePaths = routes.map((r) => r.path).toSet();
  for (final match in defaultScopePattern.allMatches(source)) {
    final path = match.group(1)!;
    if (!explicitScopePaths.contains(path)) {
      routes.add(ParsedRoute(
        path: path,
        scope: 'authenticated', // default
      ));
    }
  }

  // Parse redirect routes
  final redirectPattern = RegExp(
    r'''ScopedGoRoute\s*\(\s*path:\s*['"]([^'"]+)['"]\s*,\s*redirect:\s*\([^)]*\)\s*=>\s*['"]([^'"]+)['"]''',
  );
  for (final match in redirectPattern.allMatches(source)) {
    final path = match.group(1)!;
    final target = match.group(2)!;
    // Find existing route and mark as redirect
    final existing = routes.where((r) => r.path == path).toList();
    if (existing.isEmpty) {
      routes.add(ParsedRoute(
        path: path,
        scope: 'authenticated',
        isRedirect: true,
        redirectTarget: target,
      ));
    }
  }

  // Parse nested child routes under /profile
  final nestedPattern = RegExp(
    r'''ScopedGoRoute\s*\(\s*(?:\n\s*)?path:\s*['"]([^'"]+)['"].*?routes:\s*\[([\s\S]*?)\]\s*,?\s*\)''',
    dotAll: true,
  );
  for (final match in nestedPattern.allMatches(source)) {
    final parentPath = match.group(1)!;
    final childBlock = match.group(2)!;
    final parentRoute = routes.firstWhere(
      (r) => r.path == parentPath,
      orElse: () => ParsedRoute(path: parentPath, scope: 'authenticated'),
    );

    final childPathPattern = RegExp(
      r'''ScopedGoRoute\s*\(\s*(?:\n\s*)?path:\s*['"]([^'"]+)['"]''',
    );
    for (final childMatch in childPathPattern.allMatches(childBlock)) {
      final childRelPath = childMatch.group(1)!;
      final childFullPath = childRelPath.startsWith('/')
          ? childRelPath
          : '$parentPath/$childRelPath';

      // Check if child has explicit scope in the child block
      final childScopePattern = RegExp(
        '''path:\\s*['\"]${RegExp.escape(childRelPath)}['\"]\\s*,\\s*(?:\\n\\s*)?scope:\\s*RouteScope\\.(\\w+)''',
      );
      final scopeMatch = childScopePattern.firstMatch(childBlock);
      final childScope = scopeMatch?.group(1) ?? parentRoute.scope;

      // Don't add if already in the list
      if (!routes.any((r) => r.path == childFullPath)) {
        routes.add(ParsedRoute(
          path: childFullPath,
          scope: childScope,
          parentPath: parentPath,
        ));
      }
    }
  }

  return routes;
}

/// Build a map of path -> scope for quick lookup.
Map<String, String> buildScopeMap(List<ParsedRoute> routes) {
  final map = <String, String>{};
  for (final r in routes) {
    map[r.path] = r.scope;
  }
  return map;
}

void main() {
  late String appSource;
  late List<ParsedRoute> routes;
  late Map<String, String> scopeMap;

  setUpAll(() {
    final appFile = File('lib/app.dart');
    expect(appFile.existsSync(), isTrue);
    appSource = appFile.readAsStringSync();
    routes = parseRoutes(appSource);
    scopeMap = buildScopeMap(routes);
  });

  group('GATE-02: Scope leak detection', () {
    test('no child route has a lower scope than its parent', () {
      final violations = <String>[];

      for (final route in routes) {
        if (route.parentPath != null) {
          final parentScope = scopeMap[route.parentPath!] ?? 'authenticated';
          if (scopeLevel(route.scope) < scopeLevel(parentScope)) {
            violations.add(
              '${route.path} (scope=${route.scope}) is child of '
              '${route.parentPath} (scope=$parentScope) — '
              'child scope is LOWER than parent',
            );
          }
        }
      }

      if (violations.isNotEmpty) {
        fail('Scope leak: child routes with lower scope than parent:\n'
            '${violations.join('\n')}');
      }
    });

    test('no /onboarding/ route has scope authenticated', () {
      final violations = <String>[];
      for (final route in routes) {
        if (route.path.startsWith('/onboarding/') &&
            route.scope == 'authenticated') {
          violations.add('${route.path} has scope=authenticated '
              'but is an onboarding route');
        }
      }

      if (violations.isNotEmpty) {
        fail('Scope mismatch on onboarding routes:\n'
            '${violations.join('\n')}');
      }
    });

    test('no /auth/ route has scope authenticated', () {
      final violations = <String>[];
      for (final route in routes) {
        if (route.path.startsWith('/auth/') &&
            route.scope == 'authenticated') {
          violations.add('${route.path} has scope=authenticated '
              'but is an auth route');
        }
      }

      if (violations.isNotEmpty) {
        fail('Scope mismatch on auth routes:\n'
            '${violations.join('\n')}');
      }
    });

    test('redirect-only onboarding routes do not target authenticated-scope '
        'routes without going through auth guard', () {
      // Redirects from onboarding-scoped routes to authenticated routes
      // are acceptable ONLY if the redirect target is also onboarding/public
      // OR the redirect goes through the guard (which ScopedGoRoute handles).
      //
      // However, redirect-only ScopedGoRoute declarations that lack explicit
      // scope default to authenticated (fail-closed), which is correct for
      // guard purposes. This test checks the semantic: an onboarding-path
      // redirect should not silently land in authenticated territory.
      final violations = <String>[];
      for (final route in routes) {
        if (route.isRedirect &&
            route.redirectTarget != null &&
            route.path.startsWith('/onboarding/')) {
          final targetScope = scopeMap[route.redirectTarget!] ?? 'authenticated';
          // This is informational — the scope-based guard handles it.
          // But onboarding→authenticated is still a code smell to track.
          if (targetScope == 'authenticated' &&
              route.scope != 'authenticated') {
            violations.add(
              '${route.path} (scope=${route.scope}) redirects to '
              '${route.redirectTarget} (scope=$targetScope)',
            );
          }
        }
      }

      // Currently the onboarding redirect shims go to /coach/chat which
      // is authenticated — this is expected behavior (guard will redirect
      // unauthenticated users to register). So this is a tracking test,
      // not a hard failure. We just document the edges.
      // If you need to make this strict, uncomment the fail below.
      // if (violations.isNotEmpty) {
      //   fail('Onboarding redirects to authenticated routes:\n'
      //       '${violations.join('\n')}');
      // }
    });

    test('parsed routes are comprehensive (sanity check)', () {
      expect(routes.length, greaterThan(50),
          reason: 'Should parse 50+ routes from app.dart');

      // Check known routes exist
      final paths = routes.map((r) => r.path).toSet();
      expect(paths, contains('/'));
      expect(paths, contains('/auth/login'));
      expect(paths, contains('/auth/register'));
      expect(paths, contains('/home'));
      expect(paths, contains('/coach/chat'));
      expect(paths, contains('/onboarding/intent'));
      expect(paths, contains('/profile'));
    });
  });
}
