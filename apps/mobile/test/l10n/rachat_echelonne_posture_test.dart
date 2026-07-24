import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _locales = ['fr', 'en', 'de', 'es', 'it', 'pt'];

/// beads MINT_nosync-dwr — flag du panel -a6e : « échelonner tes rachats
/// est malin » qualifiait une stratégie (recommandation implicite,
/// posture LSFin éducation-stricte). La copie doit expliquer le
/// MÉCANISME (progressivité, taux marginal) sans juger une option.
const _judgmentWords = [
  'malin', 'astucieux', 'futé', // fr
  'smart', 'clever', 'wise', // en
  'klug', 'schlau', // de
  'inteligente', // es + pt
  'furbo', // it (« intelligente » it couvert ci-dessous)
];

void main() {
  test('rachatEchelonneTauxMarginalTip : éducatif neutre, sans jugement '
      'de stratégie (×6 langues)', () {
    for (final locale in _locales) {
      final arb = json.decode(
        File('lib/l10n/app_$locale.arb').readAsStringSync(),
      ) as Map<String, dynamic>;
      final tip =
          (arb['rachatEchelonneTauxMarginalTip'] as String).toLowerCase();
      for (final word in _judgmentWords) {
        expect(tip.contains(word), isFalse,
            reason: '[$locale] « $word » = jugement de stratégie '
                '(recommandation implicite, panel -a6e)');
      }
      // it : « intelligente » (mot complet) — éviter le faux positif sur
      // d'éventuels dérivés techniques.
      expect(RegExp(r'\bintelligente\b').hasMatch(tip), isFalse,
          reason: '[$locale] jugement de stratégie');
      // La copie doit rester ancrée sur le mécanisme fiscal
      // (« marginal » — de « Grenzsteuersatz »).
      expect(
          tip.contains('marginal') || tip.contains('grenzsteuersatz'), isTrue,
          reason: '[$locale] le tip doit expliquer le mécanisme du taux '
              'marginal, pas juger une option');
    }
  });
}
