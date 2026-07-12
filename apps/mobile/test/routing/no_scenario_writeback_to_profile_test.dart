import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _scenarioFactWritePatterns = <RegExp>[
  RegExp(r'void\s+_writeBackResult\s*\('),
  RegExp(r'projectedRenteLpp\s*:'),
  RegExp(r'projectedCapital65\s*:'),
  RegExp(r'targetRetirementAge\s*:\s*_ageRetraiteSlider'),
];

List<String> _scenarioWrites(String source) => [
      for (final pattern in _scenarioFactWritePatterns)
        for (final match in pattern.allMatches(source)) match.group(0)!,
    ];

void main() {
  group('scenario levers never overwrite durable ledger facts', () {
    test('matcher is non-vacuous against a seeded write-back', () {
      const violation = '''
void _writeBackResult() {
  profile.copyWith(projectedCapital65: scenarioResult);
}
''';

      expect(_scenarioWrites(violation), isNotEmpty);
    });

    test('/epl keeps simulated withdrawal outside avoirLppTotal', () {
      final source =
          File('lib/screens/lpp_deep/epl_screen.dart').readAsStringSync();

      expect(_scenarioWrites(source), isEmpty);
      expect(
        source,
        isNot(matches(RegExp(
          r'avoirLppTotal\s*:\s*result\.montantSouhaiteApplicable',
        ))),
      );
    });

    test('/rente-vs-capital does not persist projections or slider age', () {
      final source = File(
        'lib/screens/arbitrage/rente_vs_capital_screen.dart',
      ).readAsStringSync();

      expect(_scenarioWrites(source), isEmpty);
    });
  });
}
