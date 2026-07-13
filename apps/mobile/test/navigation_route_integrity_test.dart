/// FIX-191: Verify that every context.push/context.go target in screens
/// corresponds to a real GoRoute path in app.dart.
library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

bool _matchesParameterizedRoute(String definedRoute, String concreteRoute) {
  final definedSegments = definedRoute.split('/');
  final concreteSegments = concreteRoute.split('/');
  if (definedSegments.length != concreteSegments.length) return false;

  for (var i = 0; i < definedSegments.length; i++) {
    final defined = definedSegments[i];
    if (defined.startsWith(':')) continue;
    if (defined != concreteSegments[i]) return false;
  }
  return true;
}

void main() {
  test('FIX-191: parameterized routes match concrete path segments', () {
    expect(_matchesParameterizedRoute('/data-block/:type', '/data-block/3a'),
        isTrue);
    expect(
      _matchesParameterizedRoute('/data-block/:type', '/data-block/3a/extra'),
      isFalse,
    );
    expect(_matchesParameterizedRoute('/scan/:type', '/other/lpp'), isFalse);
  });

  test('FIX-191: all static context.push targets match a GoRoute path', () {
    // 1. Extract all GoRoute paths from app.dart
    final appDart = File('lib/app.dart').readAsStringSync();
    final routePattern = RegExp(r"path:\s*'(/[^']*)'");
    final definedRoutes =
        routePattern.allMatches(appDart).map((m) => m.group(1)!).toSet();

    // 2. Extract all STATIC route targets from screens, widgets, services, data
    // Scans: context.push/go, route: '/...' fields, and redirect patterns
    final dirsToScan = [
      Directory('lib/screens'),
      Directory('lib/widgets'),
      Directory('lib/services'),
      Directory('lib/data'),
    ];
    final pushPattern = RegExp(r"context\.(push|go)\('(/[a-z0-9\-/]+)'");
    final routeFieldPattern = RegExp(r"route:\s*'(/[a-z0-9\-/]+)'");
    final brokenRoutes = <String>[];

    for (final dir in dirsToScan) {
      if (!dir.existsSync()) continue;
      for (final file in dir.listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        final content = file.readAsStringSync();
        // Check context.push/go patterns
        final contentLines = content.split('\n');
        for (final match in pushPattern.allMatches(content)) {
          // Skip matches inside comments
          final lineIdx =
              content.substring(0, match.start).split('\n').length - 1;
          if (lineIdx < contentLines.length &&
              contentLines[lineIdx].trimLeft().startsWith('//')) {
            continue;
          }
          final route = match.group(2)!;
          final basePath = route.split('?').first;
          final hasMatch = definedRoutes.contains(basePath) ||
              definedRoutes.any((r) =>
                  basePath.startsWith('$r/') ||
                  _matchesParameterizedRoute(r, basePath));
          if (!hasMatch) {
            brokenRoutes.add('${file.path.split('lib/').last}: $route');
          }
        }
        // Check route: '/...' field patterns (e.g. in cap_engine, screen_registry)
        final lines = content.split('\n');
        for (final match in routeFieldPattern.allMatches(content)) {
          // Skip matches inside comments
          final lineIdx =
              content.substring(0, match.start).split('\n').length - 1;
          if (lineIdx < lines.length &&
              lines[lineIdx].trimLeft().startsWith('//')) {
            continue;
          }
          final route = match.group(1)!;
          final basePath = route.split('?').first;
          final hasMatch = definedRoutes.contains(basePath) ||
              definedRoutes.any((r) =>
                  basePath.startsWith('$r/') ||
                  _matchesParameterizedRoute(r, basePath));
          if (!hasMatch) {
            brokenRoutes.add('${file.path.split('lib/').last}: $route (field)');
          }
        }
      }
    }

    expect(brokenRoutes, isEmpty,
        reason: 'Broken routes:\n${brokenRoutes.join('\n')}');
  });
}
