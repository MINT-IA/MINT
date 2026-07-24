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

// Frontières Latin par lookarounds — review #1001 r1/r2 : \b ASCII ne
// borde ni « futé » ni « può » (é/ò hors \w) et contains('wise')
// matchait « otherwise ». (?<![lettre])mot(?![lettre]) est sûr pour les
// six langues.
const _latin = 'a-zà-öø-ÿ';
RegExp _word(String alternatives) =>
    RegExp('(?<![$_latin])(?:$alternatives)(?![$_latin])');

final _judgmentPatterns = [
  _word('malin|astucieux|futé|judicieux|habile'),
  _word('smart|clever|wise|shrewd|savvy'),
  _word('klug|schlau|weise|geschickt'),
  _word('inteligente|astuto|listo|sensato'),
  _word('furbo|saggio|scaltro|intelligente'),
  _word('esperto|sábio'),
];

bool _hasJudgment(String text) =>
    _judgmentPatterns.any((p) => p.hasMatch(text));

void main() {
  test('self-test : la garde détecte les jugements accentués et évite les '
      'faux positifs', () {
    // Review #1001 r2 : \b ASCII laissait passer « futé » — preuve
    // positive que les mots accentués sont attrapés.
    expect(_hasJudgment('échelonner est futé'), isTrue);
    expect(_hasJudgment('scaglionare è furbo'), isTrue);
    expect(_hasJudgment('escalonar é sábio'), isTrue);
    expect(_hasJudgment('staggering is smart'), isTrue);
    // Faux positifs interdits.
    expect(_hasJudgment('otherwise the deduction'), isFalse);
    expect(_hasJudgment('les chiffres diffèrent'), isFalse);
    expect(_hasJudgment('une tranche futée'), isFalse,
        reason: 'mot différent (futée) — frontière droite active');
  });

  test('copie rachat échelonné : éducatif neutre, qualifié, sans jugement '
      '(2 clés × 6 langues)', () {
    for (final locale in _locales) {
      final arb = json.decode(
        File('lib/l10n/app_$locale.arb').readAsStringSync(),
      ) as Map<String, dynamic>;
      for (final key in _keys) {
        final text = (arb[key] as String).toLowerCase();
        expect(_hasJudgment(text), isFalse,
            reason: '[$locale/$key] jugement de stratégie — '
                'recommandation implicite');
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
