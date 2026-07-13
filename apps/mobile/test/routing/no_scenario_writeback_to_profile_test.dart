import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _methodInvocation = RegExp(r'\b([A-Za-z_]\w*)\s*\(');

const _durableSinkVerbs = <String>{
  'apply',
  'commit',
  'merge',
  'persist',
  'record',
  'save',
  'set',
  'update',
  'upsert',
  'write',
};

const _durableSinkSubjects = <String>{
  'answer',
  'banking',
  'checkin',
  'contribution',
  'extraction',
  'fact',
  'focus',
  'inline',
  'ledger',
  'profile',
  'score',
  'wizard',
};

bool _isDurableProfileSink(String methodName) {
  final normalized = methodName.replaceAll('_', '').toLowerCase();
  if (normalized.contains('writeback')) return true;

  return _durableSinkVerbs.any(normalized.startsWith) &&
      _durableSinkSubjects.any(normalized.contains);
}

List<String> _scenarioWrites(String source) => [
      for (final match in _methodInvocation.allMatches(source))
        if (_isDurableProfileSink(match.group(1)!)) match.group(1)!,
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

    test('matcher rejects durable profile sinks regardless of payload shape',
        () {
      const violations = <String, String>{
        'copyWith containing several scenario values': '''
provider.updateProfile(profile.copyWith(
  avoirLppTotal: simulatedWithdrawal,
  pillar3aAnnualContribution: exploredContribution,
));
''',
        'answer merge': '''
await provider.mergeAnswers({'q_avoir_lpp': simulatedWithdrawal});
''',
        'fact application': '''
await provider.applySaveFact('avoirLpp', simulatedWithdrawal);
''',
        'equivalent profile setter': '''
provider.setProfile(profile.copyWith(avoirLppTotal: simulatedWithdrawal));
''',
        'equivalent answer updater': '''
provider.updateFromAnswers({'q_avoir_lpp': simulatedWithdrawal});
''',
      };

      for (final violation in violations.entries) {
        expect(
          _scenarioWrites(violation.value),
          isNotEmpty,
          reason: violation.key,
        );
      }
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
