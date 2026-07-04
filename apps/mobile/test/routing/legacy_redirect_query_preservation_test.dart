import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('/tools, /portfolio, and /score-reveal redirects preserve query params',
      () {
    final source = File('lib/app.dart').readAsStringSync();
    final routeTargets = <String, String>{
      '/tools': '/coach/chat',
      '/portfolio': '/home',
      '/score-reveal': '/home',
    };

    final violations = <String>[];
    for (final entry in routeTargets.entries) {
      final path = entry.key;
      final target = entry.value;
      final routeIndex = source.indexOf("path: '$path'");
      expect(routeIndex, isNot(-1), reason: '$path route must exist');
      final nextRouteIndex = source.indexOf('ScopedGoRoute(', routeIndex + 1);
      final block = source.substring(
        routeIndex,
        nextRouteIndex == -1 ? source.length : nextRouteIndex,
      );
      if (!block.contains('_redirectPreservingQuery(state,') ||
          RegExp("return\\s+['\"]$target['\"];").hasMatch(block)) {
        violations.add(path);
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Legacy redirects must preserve query context so topic, source, '
          'and mode survive the redirect.',
    );
  });
}
