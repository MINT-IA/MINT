/// FIX-191: Verify that every context.push/context.go target in screens
/// corresponds to a real GoRoute path in app.dart.
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FIX-191: all static context.push targets match a GoRoute path', () {
    // 1. Extract all GoRoute paths from app.dart
    final appDart = File('lib/app.dart').readAsStringSync();
    final routePattern = RegExp(r"path:\s*'(/[^']*)'");
    final definedRoutes = routePattern
        .allMatches(appDart)
        .map((m) => m.group(1)!)
        .toSet();

    // 2. Extract all STATIC context.push/context.go targets from screens
    // Only match pure string literals (no interpolation)
    final screenDir = Directory('lib/screens');
    final pushPattern = RegExp(r"context\.(push|go)\('(/[a-z0-9\-/]+)'");
    final brokenRoutes = <String>[];

    for (final file in screenDir.listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final content = file.readAsStringSync();
      for (final match in pushPattern.allMatches(content)) {
        final route = match.group(2)!;
        final basePath = route.split('?').first;
        // Match: exact, or parent path (child routes like /profile/byok)
        final hasMatch = definedRoutes.contains(basePath) ||
            definedRoutes.any((r) => basePath.startsWith('$r/'));
        if (!hasMatch) {
          brokenRoutes.add('${file.path.split('lib/').last}: $route');
        }
      }
    }

    expect(brokenRoutes, isEmpty,
        reason: 'Broken routes:\n${brokenRoutes.join('\n')}');
  });
}
