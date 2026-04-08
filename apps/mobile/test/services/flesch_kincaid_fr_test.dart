// Phase 10 Plan 10-03 — unit tests for the FK French readability gate.
//
// The tool itself lives in `tools/checks/flesch_kincaid_fr.dart` (pure Dart,
// no Flutter deps). The test file lives here because `apps/mobile/test/` is
// already wired into the `services` shard of CI and has `flutter_test`
// available; standing up a second `dart test` package under `tools/` would
// double CI time for no benefit.

import 'package:flutter_test/flutter_test.dart';

// Import the pure-Dart tool by relative path. This is ugly but deliberate:
// the tool is NOT a Flutter package and should not end up under lib/ where
// it would be bundled into the app binary.
// ignore: avoid_relative_lib_imports
import '../../../../tools/checks/flesch_kincaid_fr.dart';

void main() {
  group('kandelMolesFr — French readability scoring', () {
    test('mission statement scores in the B1/B2 easy band', () {
      // K–M expected ~88 for this sentence (B1 plain French).
      final score = kandelMolesFr(
        "Mint te dit ce que personne n'a intérêt à te dire.",
      );
      expect(score, greaterThan(80),
          reason: 'Mission line is plain French → should land in 80+ band.');
      expect(score, lessThan(100),
          reason: 'Score must stay bounded below 100.');
    });

    test('long jargon-heavy paragraph scores below the B1 floor', () {
      const jargon =
          "La déduction de coordination impacte la rente de vieillesse LPP "
          "en fonction du taux de conversion obligatoire fixé par l'ordonnance "
          "OPP2 et des bonifications de vieillesse accumulées sur le compte "
          "de prévoyance professionnelle du deuxième pilier.";
      final score = kandelMolesFr(jargon);
      expect(score, lessThan(50),
          reason: 'Jargon-heavy legalese must trip the gate.');
    });

    test('empty input is safe (returns 0)', () {
      expect(kandelMolesFr(''), 0.0);
      expect(kandelMolesFr('   '), 0.0);
    });

    test('single short sentence still produces a finite score', () {
      final score = kandelMolesFr('On commence là.');
      expect(score.isFinite, isTrue);
    });
  });

  group('countWords', () {
    test('splits on whitespace and strips empties', () {
      expect(countWords(''), 0);
      expect(countWords('un'), 1);
      expect(countWords('un deux trois'), 3);
      expect(countWords('  un   deux  '), 2);
    });
  });

  group('scoreArb — CLI mode', () {
    test('filters by key prefix and flags short strings as skipped', () {
      final arb = <String, dynamic>{
        '@@locale': 'fr',
        '@intentScreenTitle': {'description': 'meta'},
        'intentScreenTitle': "Qu'est-ce qui t'amène ?",
        'intentScreenSubtitle':
            'Choisis ce qui ressemble le plus à ta situation. On commence là.',
        'unrelatedKey': 'Ceci ne doit pas être scoré du tout.',
      };
      final results = scoreArb(
        arb,
        keyPrefixes: const ['intentScreen'],
        minWords: 8,
      );
      expect(results.map((r) => r.key).toList(),
          ['intentScreenTitle', 'intentScreenSubtitle']);

      final title = results.firstWhere((r) => r.key == 'intentScreenTitle');
      final subtitle =
          results.firstWhere((r) => r.key == 'intentScreenSubtitle');
      expect(title.skipped, isTrue,
          reason: '4-word title is below the 8-word FK reliability floor.');
      expect(subtitle.skipped, isFalse);
      expect(subtitle.score, greaterThan(50),
          reason: 'Subtitle is plain B1 French and must pass.');
    });

    test('ignores metadata keys (@-prefixed) and non-string values', () {
      final arb = <String, dynamic>{
        '@landingV2Paragraph': {'description': 'meta'},
        'landingV2Paragraph':
            "Mint te dit ce que personne n'a intérêt à te dire. "
                "Sur tes assurances, ton 3a, ton salaire.",
        'landingV2Flag': 42, // non-string: ignored
      };
      final results = scoreArb(
        arb,
        keyPrefixes: const ['landingV2'],
        minWords: 8,
      );
      expect(results.length, 1);
      expect(results.single.key, 'landingV2Paragraph');
    });
  });
}
