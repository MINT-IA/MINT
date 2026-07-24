import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _locales = ['fr', 'en', 'de', 'es', 'it', 'pt'];

/// beads MINT_nosync-dwr — flag du panel -a6e + review #1001 : la copie
/// rachat échelonné ne doit ni JUGER une stratégie (« malin », « smart »
/// — recommandation implicite, posture LSFin éducation-stricte) ni
/// SURAFFIRMER le mécanisme (« chaque déduction reste dans la tranche la
/// plus haute » — faux si la tranche traverse des paliers ou si le
/// revenu varie ; la copie qualifie avec « peut » + « à revenu
/// comparable »).
const _keys = [
  'rachatEchelonneTauxMarginalTip',
  'rachatEchelonneImpactBlocExplain',
];

// Mots complets (regex \b) par langue — review #1001 : contains('wise')
// matchait « otherwise ».
final _judgmentPatterns = [
  RegExp(r'\b(malin|astucieux|futé|judicieux|habile)\b'),
  RegExp(r'\b(smart|clever|wise|shrewd|savvy)\b'),
  RegExp(r'\b(klug|schlau|weise|geschickt)\b'),
  RegExp(r'\b(inteligente|astuto|listo|sensato)\b'),
  RegExp(r'\b(furbo|saggio|scaltro)\b'),
  RegExp(r'\b(esperto|sábio|sensato)\b'),
];

void main() {
  test('copie rachat échelonné : éducatif neutre, qualifié, sans jugement '
      '(2 clés × 6 langues)', () {
    for (final locale in _locales) {
      final arb = json.decode(
        File('lib/l10n/app_$locale.arb').readAsStringSync(),
      ) as Map<String, dynamic>;
      for (final key in _keys) {
        final text = (arb[key] as String).toLowerCase();
        for (final pat in _judgmentPatterns) {
          expect(pat.hasMatch(text), isFalse,
              reason: '[$locale/$key] jugement de stratégie '
                  '(${pat.pattern}) — recommandation implicite');
        }
        expect(RegExp(r'\bintelligente\b').hasMatch(text), isFalse,
            reason: '[$locale/$key] jugement de stratégie');
      }
      // Le tip reste ancré sur le mécanisme (marginal | Grenzsteuersatz)
      // ET qualifié (peut/kann/can/puede/può/pode — pas d'absolu).
      final tip =
          (arb['rachatEchelonneTauxMarginalTip'] as String).toLowerCase();
      expect(
          tip.contains('marginal') || tip.contains('grenzsteuersatz'), isTrue,
          reason: '[$locale] le tip doit expliquer le mécanisme');
      // NB : \b ASCII ne borde pas « può » (ò hors \w) — testé à part.
      expect(
          RegExp(r'\b(peut|kann|can|puede|pode)\b').hasMatch(tip) ||
              tip.contains('può'),
          isTrue,
          reason: '[$locale] review #1001 : le mécanisme doit être qualifié '
              '(« peut », revenu comparable), pas universel');
    }
  });
}
