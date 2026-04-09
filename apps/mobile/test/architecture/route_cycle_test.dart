// GATE-01: Route cycle detection via DFS on the GoRouter tree.
//
// Parses apps/mobile/lib/app.dart to build a directed graph from
// parent-child route relationships, then runs Tarjan's SCC algorithm
// to detect cycles. Any strongly connected component = test failure.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Build adjacency list from the router declaration in app.dart.
///
/// Extracts parent-child relationships from nested ScopedGoRoute
/// declarations. A parent route `/profile` with child route `consent`
/// produces edge `/profile` -> `/profile/consent`.
Map<String, Set<String>> buildRouteGraph(String source) {
  final graph = <String, Set<String>>{};

  // Match ScopedGoRoute declarations with their path
  final routePattern = RegExp(
    r'''ScopedGoRoute\s*\(\s*path:\s*['"]([^'"]+)['"]''',
  );

  // Find all route paths to register as nodes
  for (final match in routePattern.allMatches(source)) {
    final path = match.group(1)!;
    graph.putIfAbsent(path, () => <String>{});
  }

  // Find parent-child relationships via nesting (routes: [...])
  // We track brace depth to associate children with parents.
  _parseNestedRoutes(source, graph);

  // Find redirect targets
  final redirectPattern = RegExp(
    r'''ScopedGoRoute\s*\(\s*path:\s*['"]([^'"]+)['"]\s*,\s*redirect:\s*\([^)]*\)\s*=>\s*['"]([^'"]+)['"]''',
  );
  for (final match in redirectPattern.allMatches(source)) {
    final from = match.group(1)!;
    final to = match.group(2)!;
    graph.putIfAbsent(from, () => <String>{});
    graph.putIfAbsent(to, () => <String>{});
    graph[from]!.add(to);
  }

  return graph;
}

/// Parse nested `routes: [...]` blocks to find parent→child edges.
void _parseNestedRoutes(String source, Map<String, Set<String>> graph) {
  // Strategy: find ScopedGoRoute with `routes:` parameter that contains
  // child ScopedGoRoute declarations. We use a simplified state machine.
  final parentPattern = RegExp(
    r'''ScopedGoRoute\s*\(\s*\n?\s*path:\s*['"]([^'"]+)['"]\s*,''',
  );

  // Find routes that have sub-routes by looking for the `routes: [` pattern
  // within the same ScopedGoRoute block.
  final routeBlockPattern = RegExp(
    r'''ScopedGoRoute\s*\(\s*(?:\n\s*)?path:\s*['"]([^'"]+)['"].*?routes:\s*\[(.*?)\]\s*,?\s*\)''',
    dotAll: true,
  );

  for (final match in routeBlockPattern.allMatches(source)) {
    final parentPath = match.group(1)!;
    final childBlock = match.group(2)!;

    // Extract child paths from the routes block
    final childPattern = RegExp(r'''ScopedGoRoute\s*\(\s*(?:\n\s*)?path:\s*['"]([^'"]+)['"]''');
    for (final childMatch in childPattern.allMatches(childBlock)) {
      final childRelPath = childMatch.group(1)!;
      final childFullPath = childRelPath.startsWith('/')
          ? childRelPath
          : '$parentPath/$childRelPath';
      graph.putIfAbsent(parentPath, () => <String>{});
      graph.putIfAbsent(childFullPath, () => <String>{});
      graph[parentPath]!.add(childFullPath);
    }
  }
}

/// Tarjan's SCC algorithm. Returns all SCCs with size > 1.
List<Set<String>> findStronglyConnectedComponents(
    Map<String, Set<String>> graph) {
  var index = 0;
  final stack = <String>[];
  final onStack = <String>{};
  final indices = <String, int>{};
  final lowlinks = <String, int>{};
  final sccs = <Set<String>>[];

  void strongConnect(String v) {
    indices[v] = index;
    lowlinks[v] = index;
    index++;
    stack.add(v);
    onStack.add(v);

    for (final w in graph[v] ?? <String>{}) {
      if (!indices.containsKey(w)) {
        strongConnect(w);
        lowlinks[v] = lowlinks[v]! < lowlinks[w]! ? lowlinks[v]! : lowlinks[w]!;
      } else if (onStack.contains(w)) {
        lowlinks[v] = lowlinks[v]! < indices[w]! ? lowlinks[v]! : indices[w]!;
      }
    }

    if (lowlinks[v] == indices[v]) {
      final scc = <String>{};
      String w;
      do {
        w = stack.removeLast();
        onStack.remove(w);
        scc.add(w);
      } while (w != v);
      if (scc.length > 1) {
        sccs.add(scc);
      }
    }
  }

  for (final v in graph.keys) {
    if (!indices.containsKey(v)) {
      strongConnect(v);
    }
  }

  return sccs;
}

void main() {
  late String appSource;

  setUpAll(() {
    // Read app.dart source to parse the router tree
    final appFile = File('lib/app.dart');
    expect(appFile.existsSync(), isTrue,
        reason: 'lib/app.dart must exist');
    appSource = appFile.readAsStringSync();
  });

  group('GATE-01: Route cycle detection', () {
    test('GoRouter tree has zero strongly connected components (no cycles)',
        () {
      final graph = buildRouteGraph(appSource);

      // Sanity check: we parsed routes
      expect(graph.keys.length, greaterThan(50),
          reason: 'Should find 50+ routes in app.dart');

      final sccs = findStronglyConnectedComponents(graph);

      if (sccs.isNotEmpty) {
        final report = sccs
            .map((scc) => '  Cycle: ${scc.join(' -> ')}')
            .join('\n');
        fail('Found ${sccs.length} cycle(s) in the route graph:\n$report');
      }
    });

    test('redirect chains do not form loops', () {
      // Extract all redirect-only routes and verify no chain loops
      final redirectPattern = RegExp(
        r'''ScopedGoRoute\s*\(\s*path:\s*['"]([^'"]+)['"]\s*,\s*redirect:\s*\([^)]*\)\s*=>\s*['"]([^'"]+)['"]''',
      );
      final redirectMap = <String, String>{};
      for (final match in redirectPattern.allMatches(appSource)) {
        redirectMap[match.group(1)!] = match.group(2)!;
      }

      // Follow each redirect chain, max depth 10
      for (final start in redirectMap.keys) {
        var current = start;
        final visited = <String>{};
        while (redirectMap.containsKey(current)) {
          if (visited.contains(current)) {
            fail('Redirect loop detected starting from $start: '
                '${visited.join(' -> ')} -> $current');
          }
          visited.add(current);
          current = redirectMap[current]!;
        }
      }
    });
  });
}
