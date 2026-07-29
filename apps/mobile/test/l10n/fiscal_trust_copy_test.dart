import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _locales = ['fr', 'en', 'de', 'es', 'it', 'pt'];

const _trustSensitiveKeys = [
  'naissanceTaxSavings',
  'naissanceEstimatedTaxSaving',
  'naissanceNetFormula',
  'fiscalEduRentBody',
  'simLppBuybackTaxSavings',
  'simLppBuybackDisclaimer',
  'vaultGuidanceLamalBody',
  'firstSalary3aInfo',
  'firstSalaryFranchise300Advice',
  'firstSalaryFranchise1500Advice',
  'firstSalaryFranchise2500Advice',
  'firstSalaryTask3',
  'simRealInterestSubtitle',
  'simBuybackMarginalRateTip',
  'renteVsCapitalFiscalCapitalSaves',
  'firstSalaryTask5',
  'rachatEchelonneIntroBody',
  'rachatEchelonneTauxMarginalBody',
  'sim3aCoachBody',
  'realReturnFiscalDetail',
  'realReturnCumulativeFiscal',
  'firstJobFiscalSavings',
  'demenagementEconomieFiscale',
  'demenagementTitreV2',
  'pillar3aIndepHeaderInfo',
  'pillar3aIndepEconomieFiscaleAn',
  'pillar3aIndepDisclaimer',
  'pillar3aIndepPremierEclairageCaption',
  'pillar3aIndepPremierEclairageAvantageSalarie',
  'reportLppEconomie',
  'reportLppHowBody',
  'capCoupleLppBuybackWhyNow',
  'lppVolontaireEconomieFiscaleLabel',
  'pillar3aIndepEconomieFiscaleAnLabel',
  'challengeFiscalite01Desc',
  'challengeFiscalite01Title',
  'challengeFiscalite02Desc',
  'retroactive3aEconomiesFiscales',
  'retroactive3aEconomieFiscale',
  'narrativeRealReturnBody',
  'notifDeadline3aBody46Days',
  'retroactive3aEmptySubtitle',
  'retroactive3aSavingsLabel',
  'seasonal3aCountdownDesc',
  'semantics3aEconomieFiscale',
  'imputedRentalSavingsLabel',
  'pillar3aRealReturnDisclaimer',
  'rcLppBuybackExplanation',
  'stepJitTax3aCond',
  'stepJitTax3aCons',
  'summaryEconomieFiscale',
  'chocQuestionTaxSaving',
  'reportActionDescDette',
  'stepJitTax3aInsight',
  'landingCoupleGeneric',
];

const _bannedFragments = [
  'économie fiscale',
  'économies fiscales',
  'économie d\'impôt',
  'economie fiscale',
  'tu économises',
  'tu economises',
  'te fait économiser',
  'fait économiser',
  'économiser jusqu',
  'conseillé',
  'recommandé',
  'perdent jusqu',
  'maximiser',
  'maximum 3a',
  'tax saving',
  'tax savings',
  'saves you',
  'you save',
  'save up to',
  'lose up to',
  'recommended',
  'maximise',
  'maximize',
  'steuerersparnis',
  'steuerersparnisse',
  'steuereinsparung',
  'steuereinsparungen',
  'steuern sparst',
  'du sparst',
  'empfohlen',
  'maximiert',
  'maximieren',
  'ahorro fiscal',
  'ahorros fiscales',
  'ahorras',
  'te ahorra',
  'recomendado',
  'pierden hasta',
  'maximiza',
  'maximizar',
  'risparmio fiscale',
  'risparmi fiscali',
  'risparmi',
  'fa risparmiare',
  'consigliato',
  'perdono fino',
  'massimizzare',
  'poupança fiscal',
  'poupanças fiscais',
  'poupanca fiscal',
  'poupancas fiscais',
  'poupas',
  'poupa-te',
  'perdem até',
];

const _reportDebtRequiredFragments = {
  'fr': ['peut', 'selon le taux'],
  'en': ['can', 'depending on the rate'],
  'de': ['kann', 'je nach zinssatz'],
  'es': ['puede', 'según la tasa'],
  'it': ['può', 'a seconda del tasso'],
  'pt': ['pode', 'consoante a taxa'],
};

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

          if (key == 'reportActionDescDette') {
            for (final required
                in _reportDebtRequiredFragments[locale] ?? const <String>[]) {
              expect(
                normalized,
                contains(required),
                reason: '$locale:$key must keep conditional debt-rate framing',
              );
            }
          }
        }
      });
    }
  });
}
