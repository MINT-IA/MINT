import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _routeBlock(String source, String path) {
  final starts = RegExp(r'^ {4}ScopedGoRoute\s*\(', multiLine: true)
      .allMatches(source)
      .map((match) => match.start)
      .toList();
  final blocks = <String>[
    for (var index = 0; index < starts.length; index += 1)
      source.substring(
        starts[index],
        index + 1 < starts.length ? starts[index + 1] : source.length,
      ),
  ];
  final pathPattern = RegExp(
    "^\\s+path:\\s*'${RegExp.escape(path)}'\\s*,",
    multiLine: true,
  );
  final matches = blocks.where(pathPattern.hasMatch).toList();

  expect(
    matches,
    hasLength(1),
    reason: '$path route must appear exactly once in app.dart',
  );
  return matches.single;
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
