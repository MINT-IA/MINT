import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _locales = ['fr', 'en', 'de', 'es', 'it', 'pt'];

const _trustSensitiveKeys = [
  'coachingAge45Message',
  'simLppBuybackTaxSavings',
  'simBuybackMarginalRateTip',
  'renteVsCapitalFiscalCapitalSaves',
  'firstSalaryTask5',
  'rachatEchelonneIntroBody',
  'rachatEchelonneTauxMarginalBody',
  'sim3aCoachBody',
  'realReturnFiscalDetail',
  'realReturnCumulativeFiscal',
  'firstJobFiscalSavings',
  'pillar3aIndepHeaderInfo',
  'pillar3aIndepPremierEclairageCaption',
  'pillar3aIndepPremierEclairageAvantageSalarie',
  'reportLppEconomie',
  'reportLppHowBody',
  'capCoupleLppBuybackWhyNow',
  'challengeFiscalite01Desc',
  'challengeFiscalite01Title',
  'challengeFiscalite02Desc',
  'narrativeRealReturnBody',
  'notifDeadline3aBody46Days',
  'retroactive3aEmptySubtitle',
  'retroactive3aSavingsLabel',
  'seasonal3aCountdownDesc',
  'semantics3aEconomieFiscale',
  'stepJitTax3aCond',
  'stepJitTax3aCons',
  'summaryEconomieFiscale',
];

const _bannedFragments = [
  'économie fiscale',
  'economie fiscale',
  'tu économises',
  'tu economises',
  'te fait économiser',
  'fait économiser',
  'maximiser',
  'maximum 3a',
  'tax saving',
  'tax savings',
  'saves you',
  'you save',
  'maximise',
  'maximize',
  'steuerersparnis',
  'steuern sparst',
  'du sparst',
  'maximiert',
  'maximieren',
  'ahorro fiscal',
  'ahorras',
  'te ahorra',
  'maximiza',
  'maximizar',
  'risparmio fiscale',
  'risparmi',
  'fa risparmiare',
  'massimizzare',
  'poupança fiscal',
  'poupas',
  'poupa-te',
  'maximiza',
  'maximizar',
];

void main() {
  group('Fiscal trust copy', () {
    for (final locale in _locales) {
      test('sensitive fiscal l10n keys stay indicative in $locale', () {
        final file = File('lib/l10n/app_$locale.arb');
        final arb = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

        for (final key in _trustSensitiveKeys) {
          final value = arb[key];
          expect(value, isA<String>(), reason: '$locale:$key must exist');

          final normalized = (value as String).toLowerCase();
          for (final banned in _bannedFragments) {
            expect(
              normalized,
              isNot(contains(banned)),
              reason: '$locale:$key must not promise deterministic tax gains',
            );
          }
        }
      });
    }
  });
}
