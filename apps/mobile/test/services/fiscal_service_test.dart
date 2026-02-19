import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/fiscal_service.dart';

void main() {
  // =========================================================================
  // FISCAL SERVICE — Unit tests (Sprint S20)
  // =========================================================================
  //
  // Tests the cantonal tax comparison service:
  //   - estimateTax: estimate for one canton
  //   - compareAllCantons: rank all 26 cantons
  //   - simulateMove: compare two cantons (move scenario)
  //   - formatChf: Swiss apostrophe formatting
  //   - estimateNationalAverageRate: national average rate
  //   - Income & family adjustments
  //
  // Sources: LIFD, LHID, baremes cantonaux 2024-2026.
  // =========================================================================

  group('estimateTax - structure du resultat', () {
    test('returns all expected keys', () {
      final result = FiscalService.estimateTax(
        revenuBrut: 100000,
        canton: 'ZH',
      );

      expect(result.containsKey('canton'), true);
      expect(result.containsKey('cantonNom'), true);
      expect(result.containsKey('commune'), true);
      expect(result.containsKey('revenuImposable'), true);
      expect(result.containsKey('impotFederal'), true);
      expect(result.containsKey('impotCantonalCommunal'), true);
      expect(result.containsKey('chargeTotale'), true);
      expect(result.containsKey('tauxEffectif'), true);
    });

    test('canton and cantonNom match input', () {
      final result = FiscalService.estimateTax(
        revenuBrut: 100000,
        canton: 'GE',
      );

      expect(result['canton'], 'GE');
      expect(result['cantonNom'], 'Genève');
    });

    test('chargeTotale equals impotFederal + impotCantonalCommunal', () {
      final result = FiscalService.estimateTax(
        revenuBrut: 100000,
        canton: 'VD',
      );

      final federal = result['impotFederal'] as double;
      final cantonal = result['impotCantonalCommunal'] as double;
      final total = result['chargeTotale'] as double;

      expect(total, closeTo(federal + cantonal, 0.01));
    });

    test('tauxEffectif is percentage of chargeTotale over revenu', () {
      final result = FiscalService.estimateTax(
        revenuBrut: 100000,
        canton: 'BE',
      );

      final total = result['chargeTotale'] as double;
      final taux = result['tauxEffectif'] as double;

      expect(taux, closeTo(total / 100000 * 100, 0.01));
    });
  });

  group('estimateTax - comparaison cantonale', () {
    test('ZG (lowest) returns lower charge than BS (highest)', () {
      final taxZG = FiscalService.estimateTax(
        revenuBrut: 100000,
        canton: 'ZG',
      );
      final taxBS = FiscalService.estimateTax(
        revenuBrut: 100000,
        canton: 'BS',
      );

      final chargeZG = taxZG['chargeTotale'] as double;
      final chargeBS = taxBS['chargeTotale'] as double;

      expect(chargeZG, lessThan(chargeBS));
    });

    test('all charges are positive for 100k income', () {
      for (final canton in FiscalService.effectiveRates100kSingle.keys) {
        final result = FiscalService.estimateTax(
          revenuBrut: 100000,
          canton: canton,
        );
        expect(
          result['chargeTotale'] as double,
          greaterThan(0),
          reason: '$canton should have positive tax charge',
        );
      }
    });

    test('zero income returns zero charge', () {
      final result = FiscalService.estimateTax(
        revenuBrut: 0,
        canton: 'ZH',
      );

      expect(result['chargeTotale'] as double, equals(0.0));
      expect(result['tauxEffectif'] as double, equals(0.0));
    });
  });

  group('compareAllCantons', () {
    test('returns exactly 26 results', () {
      final results = FiscalService.compareAllCantons(revenuBrut: 100000);
      expect(results.length, 26);
    });

    test('results are sorted by chargeTotale ascending', () {
      final results = FiscalService.compareAllCantons(revenuBrut: 100000);

      for (int i = 0; i < results.length - 1; i++) {
        final current = results[i]['chargeTotale'] as double;
        final next = results[i + 1]['chargeTotale'] as double;
        expect(
          current,
          lessThanOrEqualTo(next),
          reason:
              'Rank ${i + 1} (${results[i]['canton']}) should be <= rank ${i + 2} (${results[i + 1]['canton']})',
        );
      }
    });

    test('first result has rang == 1', () {
      final results = FiscalService.compareAllCantons(revenuBrut: 100000);
      expect(results.first['rang'], 1);
    });

    test('last result has rang == 26', () {
      final results = FiscalService.compareAllCantons(revenuBrut: 100000);
      expect(results.last['rang'], 26);
    });

    test('first result differenceVsPremier is zero', () {
      final results = FiscalService.compareAllCantons(revenuBrut: 100000);
      expect(results.first['differenceVsPremier'] as double, equals(0.0));
    });

    test('ZG is ranked first for 100k single', () {
      final results = FiscalService.compareAllCantons(revenuBrut: 100000);
      expect(results.first['canton'], 'ZG');
    });
  });

  group('simulateMove - structure', () {
    test('returns correct structure', () {
      final result = FiscalService.simulateMove(
        revenuBrut: 100000,
        cantonDepart: 'VD',
        cantonArrivee: 'ZG',
      );

      expect(result.containsKey('cantonDepart'), true);
      expect(result.containsKey('cantonDepartNom'), true);
      expect(result.containsKey('cantonArrivee'), true);
      expect(result.containsKey('cantonArriveeNom'), true);
      expect(result.containsKey('chargeDepart'), true);
      expect(result.containsKey('chargeArrivee'), true);
      expect(result.containsKey('tauxDepart'), true);
      expect(result.containsKey('tauxArrivee'), true);
      expect(result.containsKey('economieAnnuelle'), true);
      expect(result.containsKey('economieMensuelle'), true);
      expect(result.containsKey('economie10Ans'), true);
      expect(result.containsKey('chiffreChoc'), true);
    });
  });

  group('simulateMove - scenarios', () {
    test('BS to ZG shows positive savings', () {
      final result = FiscalService.simulateMove(
        revenuBrut: 100000,
        cantonDepart: 'BS',
        cantonArrivee: 'ZG',
      );

      final economie = result['economieAnnuelle'] as double;
      expect(economie, greaterThan(0),
          reason: 'Moving from BS to ZG should save money');

      // 10-year savings should be 10x annual
      final economie10 = result['economie10Ans'] as double;
      expect(economie10, closeTo(economie * 10, 0.01));

      // Monthly savings should be annual / 12
      final economieMensuelle = result['economieMensuelle'] as double;
      expect(economieMensuelle, closeTo(economie / 12, 0.01));
    });

    test('same canton shows zero savings', () {
      final result = FiscalService.simulateMove(
        revenuBrut: 100000,
        cantonDepart: 'VD',
        cantonArrivee: 'VD',
      );

      expect(result['economieAnnuelle'] as double, equals(0.0));
      expect(result['economieMensuelle'] as double, equals(0.0));
      expect(result['economie10Ans'] as double, equals(0.0));
    });

    test('chiffreChoc mentions savings for positive move', () {
      final result = FiscalService.simulateMove(
        revenuBrut: 100000,
        cantonDepart: 'BS',
        cantonArrivee: 'ZG',
      );

      final chiffreChoc = result['chiffreChoc'] as String;
      expect(chiffreChoc, contains('économiserais'));
      expect(chiffreChoc, contains('10 ans'));
    });

    test('chiffreChoc mentions extra cost for negative move', () {
      final result = FiscalService.simulateMove(
        revenuBrut: 100000,
        cantonDepart: 'ZG',
        cantonArrivee: 'BS',
      );

      final chiffreChoc = result['chiffreChoc'] as String;
      expect(chiffreChoc, contains('coûterait'));
    });

    test('chiffreChoc mentions equivalence for same canton', () {
      final result = FiscalService.simulateMove(
        revenuBrut: 100000,
        cantonDepart: 'VD',
        cantonArrivee: 'VD',
      );

      final chiffreChoc = result['chiffreChoc'] as String;
      expect(chiffreChoc, contains('équivalente'));
    });
  });

  group('formatChf', () {
    test('formats correctly with apostrophe separator', () {
      expect(FiscalService.formatChf(12345), contains("12'345"));
      expect(FiscalService.formatChf(12345), startsWith('CHF'));
    });

    test('formats small number without apostrophe', () {
      expect(FiscalService.formatChf(500), contains('500'));
    });

    test('formats large number with multiple apostrophes', () {
      final formatted = FiscalService.formatChf(1234567);
      expect(formatted, contains("1'234'567"));
    });

    test('formats zero', () {
      expect(FiscalService.formatChf(0), contains('0'));
    });
  });

  group('estimateNationalAverageRate', () {
    test('returns a reasonable value for 100k single', () {
      final rate = FiscalService.estimateNationalAverageRate(
        revenuBrut: 100000,
      );

      // National average at 100k is 12.5%, so in percentage = 12.5
      // incomeAdj for 100k = 1.0, familyAdj for celibataire_0 = 1.0
      expect(rate, closeTo(12.5, 0.1));
    });

    test('returns positive value', () {
      final rate = FiscalService.estimateNationalAverageRate(
        revenuBrut: 80000,
      );

      expect(rate, greaterThan(0));
    });

    test('higher income yields higher rate', () {
      final rateLow = FiscalService.estimateNationalAverageRate(
        revenuBrut: 50000,
      );
      final rateHigh = FiscalService.estimateNationalAverageRate(
        revenuBrut: 300000,
      );

      expect(rateHigh, greaterThan(rateLow));
    });
  });

  group('Ajustement familial', () {
    test('married couple pays less than single (same income)', () {
      final taxSingle = FiscalService.estimateTax(
        revenuBrut: 100000,
        canton: 'ZH',
        etatCivil: 'celibataire',
        nombreEnfants: 0,
      );
      final taxMarried = FiscalService.estimateTax(
        revenuBrut: 100000,
        canton: 'ZH',
        etatCivil: 'marie',
        nombreEnfants: 0,
      );

      expect(
        taxMarried['chargeTotale'] as double,
        lessThan(taxSingle['chargeTotale'] as double),
      );
    });

    test('married with children pays less than married without children', () {
      final taxNoKids = FiscalService.estimateTax(
        revenuBrut: 100000,
        canton: 'BE',
        etatCivil: 'marie',
        nombreEnfants: 0,
      );
      final taxWithKids = FiscalService.estimateTax(
        revenuBrut: 100000,
        canton: 'BE',
        etatCivil: 'marie',
        nombreEnfants: 2,
      );

      expect(
        taxWithKids['chargeTotale'] as double,
        lessThan(taxNoKids['chargeTotale'] as double),
      );
    });

    test('family adjustment reduces national average rate for married', () {
      final rateSingle = FiscalService.estimateNationalAverageRate(
        revenuBrut: 100000,
        etatCivil: 'celibataire',
        nombreEnfants: 0,
      );
      final rateMarried = FiscalService.estimateNationalAverageRate(
        revenuBrut: 100000,
        etatCivil: 'marie',
        nombreEnfants: 2,
      );

      expect(rateMarried, lessThan(rateSingle));
    });
  });

  group('Ajustement revenu', () {
    test('higher income increases effective rate', () {
      final taxLow = FiscalService.estimateTax(
        revenuBrut: 50000,
        canton: 'VD',
      );
      final taxHigh = FiscalService.estimateTax(
        revenuBrut: 300000,
        canton: 'VD',
      );

      final tauxLow = taxLow['tauxEffectif'] as double;
      final tauxHigh = taxHigh['tauxEffectif'] as double;

      expect(tauxHigh, greaterThan(tauxLow),
          reason: 'Higher income should have higher effective rate');
    });

    test('income adjustment is progressive (not linear)', () {
      final tax50k = FiscalService.estimateTax(
        revenuBrut: 50000,
        canton: 'ZH',
      );
      final tax100k = FiscalService.estimateTax(
        revenuBrut: 100000,
        canton: 'ZH',
      );
      final tax200k = FiscalService.estimateTax(
        revenuBrut: 200000,
        canton: 'ZH',
      );

      final taux50k = tax50k['tauxEffectif'] as double;
      final taux100k = tax100k['tauxEffectif'] as double;
      final taux200k = tax200k['tauxEffectif'] as double;

      // Rate should increase with income (progressive)
      expect(taux100k, greaterThan(taux50k));
      expect(taux200k, greaterThan(taux100k));
    });
  });

  group('Constantes et donnees de reference', () {
    test('effectiveRates100kSingle has 26 entries', () {
      expect(FiscalService.effectiveRates100kSingle.length, 26);
    });

    test('cantonNames has 26 entries', () {
      expect(FiscalService.cantonNames.length, 26);
    });

    test('every rate canton has a name', () {
      for (final code in FiscalService.effectiveRates100kSingle.keys) {
        expect(
          FiscalService.cantonNames.containsKey(code),
          true,
          reason: 'Canton code $code missing from cantonNames',
        );
      }
    });

    test('sortedCantonCodes returns 26 codes alphabetically', () {
      final codes = FiscalService.sortedCantonCodes;
      expect(codes.length, 26);
      // Verify alphabetical order
      for (int i = 0; i < codes.length - 1; i++) {
        expect(
          codes[i].compareTo(codes[i + 1]),
          lessThan(0),
          reason: '${codes[i]} should come before ${codes[i + 1]}',
        );
      }
    });

    test('nationalAverageRate100k is between min and max canton rates', () {
      final rates = FiscalService.effectiveRates100kSingle.values;
      final minRate = rates.reduce((a, b) => a < b ? a : b);
      final maxRate = rates.reduce((a, b) => a > b ? a : b);

      expect(FiscalService.nationalAverageRate100k, greaterThan(minRate));
      expect(FiscalService.nationalAverageRate100k, lessThan(maxRate));
    });
  });
}
