import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _scenarioFactWritePatterns = <RegExp>[
  RegExp(r'void\s+_writeBackResult\s*\('),
  RegExp(r'projectedRenteLpp\s*:'),
  RegExp(r'projectedCapital65\s*:'),
  RegExp(r'targetRetirementAge\s*:\s*_ageRetraiteSlider'),
  RegExp(r'mortgageCapacity\s*:\s*result\.'),
  RegExp(r'estimatedMonthlyPayment\s*:\s*result\.'),
  RegExp(r'rachatEffectue\s*:'),
  RegExp(r'dateRachats\s*:'),
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

    test('/hypotheque keeps calculated capacity and payment out of facts', () {
      final source = File(
        'lib/screens/mortgage/affordability_screen.dart',
      ).readAsStringSync();

      expect(_scenarioWrites(source), isEmpty);
    });

    test('/3a-retroactif keeps tax savings outside certified LPP facts', () {
      final source = File(
        'lib/screens/pillar_3a_deep/retroactive_3a_screen.dart',
      ).readAsStringSync();

      expect(
        _scenarioWrites(source),
        isEmpty,
        reason: 'A retroactive 3a tax simulation must not overwrite a '
            'certificate-backed LPP pension or any durable profile fact.',
      );
    });

    test('/pilier-3a never rewrites the profile after a scenario change', () {
      final source =
          File('lib/screens/simulator_3a_screen.dart').readAsStringSync();

      expect(
        _scenarioWrites(source),
        isEmpty,
        reason: 'A contribution lever is a local scenario value. Even a '
            'value-identical updateProfile call is a facade write and must '
            'not persist without explicit confirmation.',
      );
    });

    test('/rachat-lpp never records a simulated buyback as a real event', () {
      final source = File(
        'lib/screens/lpp_deep/rachat_echelonne_screen.dart',
      ).readAsStringSync();

      expect(
        _scenarioWrites(source),
        isEmpty,
        reason: 'Changing a scenario lever must not append DateTime.now(), '
            'rachatEffectue, or dateRachats without explicit confirmation of '
            'a completed real-world buyback.',
      );
    });
  });
}
