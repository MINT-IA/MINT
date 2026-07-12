import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _forbiddenAppRoutePayloads = <RegExp>[
  RegExp(r'state\.extra\s+as\s+CoachProfile'),
  RegExp(r'state\.extra\s+as\s+MintUserState'),
  RegExp(r'state\.extra\s+as\s+ExtractionResult'),
  RegExp(r'state\.extra\s+as\s+ConfidenceResult'),
  RegExp(r'state\.extra\s+as\s+Map<String,\s*dynamic>'),
  RegExp(r'\(state\.extra\s+as\s+[^)]+\)\.[A-Za-z_]'),
];

List<String> _findMatches(String source, Iterable<RegExp> patterns) => [
      for (final pattern in patterns)
        for (final match in pattern.allMatches(source))
          '${pattern.pattern}: ${match.group(0)}',
    ];

void main() {
  group('GoRouter.extra domain-data hard floor', () {
    test('matcher is non-vacuous against a seeded forbidden fixture', () {
      const seededViolation = '''
builder: (context, state) {
  final result = state.extra as ExtractionResult?;
  return Review(result: result);
}
''';

      expect(
        _findMatches(seededViolation, _forbiddenAppRoutePayloads),
        isNotEmpty,
      );
    });

    test('app route builders do not cast domain data from state.extra', () {
      final source = File('lib/app.dart').readAsStringSync();

      expect(
        _findMatches(source, _forbiddenAppRoutePayloads),
        isEmpty,
        reason: 'Routes may carry ids/enums/ephemera only. Domain objects '
            'must resolve from a provider or persisted ledger.',
      );
    });

    test('scan navigation carries scanSessionId, never extraction payloads',
        () {
      final sources = [
        'lib/screens/document_scan/document_scan_screen.dart',
        'lib/screens/document_scan/avs_guide_screen.dart',
        'lib/screens/document_scan/extraction_review_screen.dart',
      ].map((path) => File(path).readAsStringSync()).join('\n');

      expect(
        sources,
        isNot(matches(RegExp(
          r"context\.push\('/scan/(?:review|impact)'\s*,\s*extra\s*:",
        ))),
      );
      expect(sources, contains('scanSessionId'));
    });

    test('G1 product routes do not hydrate financial prefill from extra', () {
      final sources = [
        'lib/screens/mortgage/affordability_screen.dart',
        'lib/screens/arbitrage/rente_vs_capital_screen.dart',
        'lib/screens/lpp_deep/epl_screen.dart',
        'lib/screens/pillar_3a_deep/staggered_withdrawal_screen.dart',
      ].map((path) => File(path).readAsStringSync()).join('\n');

      expect(sources, isNot(contains("extra['prefill']")));
      expect(sources, isNot(contains("extra[\"prefill\"]")));

      final suggestionCard = File(
        'lib/widgets/coach/route_suggestion_card.dart',
      ).readAsStringSync();
      expect(suggestionCard, isNot(contains('context.push(route, extra:')));
    });
  });
}
