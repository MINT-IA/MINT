import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/financial_core/income_tax_model_v2.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';

/// beads MINT_nosync-8p4 (PR B de -5up) — le chemin revenu de
/// tax_calculator délégue au modèle v2 (miroir des conventions backend
/// couple_optimizer.py, PR #1005) : marginale = pente locale
/// (delta 1000, clamp 0-0.50), économie = différence exacte. Les tables
/// v1 (_effectiveRates100k / _incomeAdjustment) sont supprimées.
void main() {
  test('contrat parts <-> total : 26 cantons x statuts x revenus '
      '(review #1007)', () {
    // La décomposition et le total partagent désormais les mêmes boucles
    // (délégation) — ce contrat verrouille l'identité sur toute la
    // grille : bornes (<40k), intervalles, extrapolation (>250k),
    // fallback canton inconnu, marié x0.80 proportionnel vs somme.
    const incomes = [8000.0, 40000.0, 85000.0, 100000.0, 140000.0, 300000.0];
    final cantons = [...cantonalCommunalTaxChf.keys, 'XX'];
    for (final canton in cantons) {
      for (final income in incomes) {
        for (final married in [false, true]) {
          final total = estimateIncomeTaxV2(income, canton,
              isMarried: married);
          final parts = estimateIncomeTaxV2Parts(income, canton,
              isMarried: married);
          expect(parts.federal + parts.cantonal, closeTo(total, 0.01),
              reason: '$canton/$income/married=$married');
          expect(parts.federal, greaterThanOrEqualTo(0));
          expect(parts.cantonal, greaterThanOrEqualTo(0));
        }
      }
    }
  });

  test('tombstone : les tables v1 sont supprimées du source', () {
    final src = File('lib/services/financial_core/tax_calculator.dart')
        .readAsStringSync();
    expect(src.contains('_effectiveRates100k'), isFalse);
    expect(src.contains('_incomeAdjustment'), isFalse);
    expect(src.contains('_interpolateIncomeAdjustment'), isFalse);
  });

  test('marginale = pente locale v2 (convention backend #1005)', () {
    final rate = RetirementTaxCalculator.estimateMarginalRate(140000, 'VD');
    final expected = (estimateIncomeTaxV2(140000, 'VD') -
            estimateIncomeTaxV2(139000, 'VD')) /
        1000;
    expect(rate, closeTo(expected, 1e-9));
    expect(rate, inInclusiveRange(0.0, 0.50));
  });

  test('économie déduction = différence exacte v2', () {
    final saving = RetirementTaxCalculator.estimateTaxSaving(
      income: 140000,
      deduction: 12000,
      canton: 'VD',
    );
    final expected = estimateIncomeTaxV2(140000, 'VD') -
        estimateIncomeTaxV2(128000, 'VD');
    expect(saving, closeTo(expected, 0.01));
  });

  test('override certificat conservé : taux réel scanné prime', () {
    expect(
      RetirementTaxCalculator.estimateMarginalRate(140000, 'VD',
          actualRate: 0.22),
      0.22,
    );
    expect(
      RetirementTaxCalculator.estimateTaxSaving(
        income: 140000,
        deduction: 10000,
        canton: 'VD',
        actualMarginalRate: 0.22,
      ),
      closeTo(2200, 0.01),
    );
  });

  test('mensuel = v2/12 (célibataire, marié, enfants) — review #1006', () {
    final single = RetirementTaxCalculator.estimateMonthlyIncomeTax(
      revenuAnnuelImposable: 120000,
      canton: 'GE',
    );
    expect(single, closeTo(estimateIncomeTaxV2(120000, 'GE') / 12, 0.01));

    final married = RetirementTaxCalculator.estimateMonthlyIncomeTax(
      revenuAnnuelImposable: 120000,
      canton: 'GE',
      etatCivil: 'marie',
    );
    expect(married,
        closeTo(estimateIncomeTaxV2(120000, 'GE', isMarried: true) / 12, 0.01));

    final kids = RetirementTaxCalculator.estimateMonthlyIncomeTax(
      revenuAnnuelImposable: 120000,
      canton: 'GE',
      etatCivil: 'marie',
      nombreEnfants: 2,
    );
    expect(kids, closeTo(married * 0.72 / 0.85, 0.01));
  });

  test('enfants : ratio relatif marié (convention #997/#1005)', () {
    final base = RetirementTaxCalculator.estimateMarginalRate(140000, 'VD',
        isMarried: true);
    final kids = RetirementTaxCalculator.estimateMarginalRate(140000, 'VD',
        isMarried: true, children: 2);
    expect(kids, closeTo(base * 0.72 / 0.85, 1e-9));
  });
}
