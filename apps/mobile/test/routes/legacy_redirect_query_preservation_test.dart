import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _routeBlock(String source, String path) {
  final start = source.indexOf("ScopedGoRoute(path: '$path'");
  expect(start, isNonNegative, reason: '$path route missing from app.dart');

  final rest = source.substring(start);
  final nextRoute = rest.indexOf('\n    ScopedGoRoute(', 1);
  return nextRoute == -1 ? rest : rest.substring(0, nextRoute);
}

void main() {
  group('legacy redirects preserve query strings', () {
    final app = File('lib/app.dart').readAsStringSync();

    test('helper appends the original query string', () {
      expect(app, contains('final query = state.uri.query;'));
      expect(
        app,
        contains("query.isEmpty ? targetPath : '\$targetPath?\$query'"),
      );
    });

    for (final entry in const {
      '/ask-mint': '/coach/chat',
      '/tools': '/coach/chat',
      '/portfolio': '/home',
      '/score-reveal': '/home',
    }.entries) {
      test('${entry.key} redirects to ${entry.value} with query preserved', () {
        final block = _routeBlock(app, entry.key);

        expect(block,
            contains("_redirectPreservingQuery(state, '${entry.value}')"));
        expect(block, isNot(contains("return '${entry.value}';")));
      });
    }
  });
}
