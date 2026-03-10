import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/services/retirement_service.dart';

/// Tests unitaires pour RetirementService (Sprint S21).
///
/// Couvre les 3 modules de planification retraite :
///   1. estimateAvs    — estimation rente AVS (LAVS art. 21-29)
///   2. compareLpp     — comparaison capital vs rente LPP
///   3. calculateBudget — budget retraite
///
/// Constantes 2025/2026 :
///   - Rente AVS max : 30'240 CHF/an (2'520 CHF/mois)
///   - Taux conversion LPP min : 6.8%
///   - Duree cotisation complete : 44 ans
///   - Penalite anticipation : 6.8%/an
void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  //  1. estimateAvs
  // ═══════════════════════════════════════════════════════════════════════════

  group('estimateAvs — estimation rente AVS', () {
    test('retraite a 65 ans, sans lacune — rente maximale', () {
      final r = RetirementService.estimateAvs(
        ageActuel: 50,
        ageRetraite: 65,
        anneesLacunes: 0,
      );

      expect(r['scenario'], 'normal');
      expect(r['facteurAjustement'], 1.0);
      expect(r['penaliteOuBonusPct'], 0.0);
      // Rente mensuelle = 2520 (max)
      expect(r['renteMensuelle'] as double, closeTo(2520.0, 1));
      // Rente annuelle = 30240
      expect(r['renteAnnuelle'] as double, closeTo(30240.0, 1));
    });

    test('anticipation 63 ans — penalite 2 x 6.8% = 13.6%', () {
      final r = RetirementService.estimateAvs(
        ageActuel: 50,
        ageRetraite: 63,
        anneesLacunes: 0,
      );

      expect(r['scenario'], 'anticipation');
      expect((r['facteurAjustement'] as double), closeTo(1.0 - 0.136, 0.001));
      expect((r['penaliteOuBonusPct'] as double), closeTo(-13.6, 0.1));
      // Rente reduite
      expect((r['renteMensuelle'] as double), closeTo(2520 * 0.864, 1));
    });

    test('ajournement 67 ans — bonus 2 ans (+10.8%)', () {
      final r = RetirementService.estimateAvs(
        ageActuel: 60,
        ageRetraite: 67,
        anneesLacunes: 0,
      );

      expect(r['scenario'], 'ajournement');
      expect((r['facteurAjustement'] as double), closeTo(1.106, 0.001));
      expect((r['penaliteOuBonusPct'] as double), closeTo(10.6, 0.1));
    });

    test('ajournement maximum 70 ans — bonus 5 ans (+31.5%)', () {
      final r = RetirementService.estimateAvs(
        ageActuel: 60,
        ageRetraite: 70,
        anneesLacunes: 0,
      );

      expect(r['scenario'], 'ajournement');
      expect((r['facteurAjustement'] as double), closeTo(1.315, 0.001));
    });

    test('lacunes de cotisation — rente reduite proportionnellement', () {
      final r = RetirementService.estimateAvs(
        ageActuel: 50,
        ageRetraite: 65,
        anneesLacunes: 4,
      );

      // gapFactor = (44 - 4) / 44 = 40/44
      final expectedMensuel = 2520.0 * 40 / 44;
      expect((r['renteMensuelle'] as double), closeTo(expectedMensuel, 1));
    });

    test('couple — rente couple plafonnee a 150% de la rente max', () {
      final r = RetirementService.estimateAvs(
        ageActuel: 50,
        ageRetraite: 65,
        isCouple: true,
        anneesLacunes: 0,
      );

      // Rente couple = min(2520 * 2, 2520 * 1.5) = 3780
      expect(r['renteCoupleMensuelle'] as double, closeTo(3780.0, 1));
    });

    test('projection cumul — (esperance - age retraite) x rente annuelle', () {
      final r = RetirementService.estimateAvs(
        ageActuel: 50,
        ageRetraite: 65,
        anneesLacunes: 0,
        esperanceVie: 85,
      );

      // Duree = 85 - 65 = 20 ans
      expect(r['dureeEstimeeAns'], 20);
      expect((r['totalCumule'] as double), closeTo(30240.0 * 20, 1));
    });

    test('anticipation 1 an — penalite 6.8%', () {
      final r = RetirementService.estimateAvs(
        ageActuel: 60,
        ageRetraite: 64,
        anneesLacunes: 0,
      );

      expect(r['scenario'], 'anticipation');
      expect((r['facteurAjustement'] as double), closeTo(0.932, 0.001));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  //  2. compareLpp — capital vs rente
  // ═══════════════════════════════════════════════════════════════════════════

  group('compareLpp — capital vs rente', () {
    test('rente calculee avec taux 6.8%', () {
      final r = RetirementService.compareLpp(
        capitalLpp: 500000,
        canton: 'ZH',
      );

      // Rente annuelle = 500000 * 0.068 = 34000
      expect(r['renteAnnuelle'] as double, closeTo(34000, 1));
      // Rente mensuelle = 34000 / 12
      expect(r['renteMensuelle'] as double, closeTo(34000 / 12, 1));
    });

    test('impot progressif sur capital ZH (6.5% base)', () {
      final r = RetirementService.compareLpp(
        capitalLpp: 500000,
        canton: 'ZH',
      );

      // Impot progressif :
      // 0-100k: 100000 * 0.065 * 1.0 = 6500
      // 100k-200k: 100000 * 0.065 * 1.15 = 7475
      // 200k-500k: 300000 * 0.065 * 1.30 = 25350
      // Total: 39325
      expect(r['capitalImpot'] as double, closeTo(39325, 1));
      expect(r['capitalNet'] as double, closeTo(500000 - 39325, 1));
    });

    test('impot progressif VD (8.0% base) — capital 300k', () {
      final r = RetirementService.compareLpp(
        capitalLpp: 300000,
        canton: 'VD',
      );

      // 0-100k: 100000 * 0.08 * 1.0 = 8000
      // 100k-200k: 100000 * 0.08 * 1.15 = 9200
      // 200k-300k: 100000 * 0.08 * 1.30 = 10400
      // Total: 27600
      expect(r['capitalImpot'] as double, closeTo(27600, 1));
    });

    test('breakeven age — point ou rente cumule depasse capital net', () {
      final r = RetirementService.compareLpp(
        capitalLpp: 500000,
        canton: 'ZH',
        ageRetraite: 65,
        esperanceVie: 87,
      );

      final breakevenAge = r['breakevenAge'] as int;
      // Le breakeven devrait etre raisonnable (entre 65 et 87)
      expect(breakevenAge, greaterThanOrEqualTo(65));
      expect(breakevenAge, lessThanOrEqualTo(87));
    });

    test('canton inconnu — taux par defaut 6.5%', () {
      final r = RetirementService.compareLpp(
        capitalLpp: 100000,
        canton: 'XX',
      );

      // Impot = 100000 * 0.065 * 1.0 = 6500
      expect(r['capitalImpot'] as double, closeTo(6500, 1));
    });

    test('capital zero — pas d impot, pas de rente', () {
      final r = RetirementService.compareLpp(
        capitalLpp: 0,
        canton: 'ZH',
      );

      expect(r['renteAnnuelle'] as double, closeTo(0, 1));
      expect(r['capitalImpot'] as double, closeTo(0, 1));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  //  3. calculateBudget — budget retraite
  // ═══════════════════════════════════════════════════════════════════════════

  group('calculateBudget — budget retraite', () {
    test('solde positif quand revenus > depenses', () {
      final r = RetirementService.calculateBudget(
        avsMensuel: 2520,
        lppMensuel: 2000,
        capital3aNet: 100000,
        depensesMensuelles: 4000,
        revenuPreRetraite: 8000,
      );

      // Total = 2520 + 2000 + 100000/(20*12) + 0 = 2520 + 2000 + 416.67 = 4936.67
      expect((r['solde'] as double), greaterThan(0));
    });

    test('alerte deficit quand depenses > revenus', () {
      final r = RetirementService.calculateBudget(
        avsMensuel: 1500,
        lppMensuel: 800,
        capital3aNet: 0,
        depensesMensuelles: 5000,
        revenuPreRetraite: 8000,
      );

      expect((r['solde'] as double), lessThan(0));
      final alertes = r['alertes'] as List<String>;
      expect(alertes.any((a) => a.contains('Deficit')), isTrue);
    });

    test('taux de remplacement < 60% — alerte', () {
      final r = RetirementService.calculateBudget(
        avsMensuel: 2000,
        lppMensuel: 500,
        depensesMensuelles: 4000,
        revenuPreRetraite: 10000,
      );

      // Total revenus = 2000 + 500 = 2500
      // Taux = 2500 / 10000 * 100 = 25%
      final tauxRemplacement = r['tauxRemplacement'] as double;
      expect(tauxRemplacement, lessThan(60));
      final alertes = r['alertes'] as List<String>;
      expect(alertes.any((a) => a.contains('remplacement')), isTrue);
    });

    test('PC eligible si revenus < seuil (3000 individuel)', () {
      final r = RetirementService.calculateBudget(
        avsMensuel: 1500,
        lppMensuel: 500,
        depensesMensuelles: 3000,
        revenuPreRetraite: 6000,
        isCouple: false,
      );

      // Total = 2000 < 3000 seuil => PC eligible
      expect(r['pcEligible'], isTrue);
    });

    test('PC seuil couple = 4500', () {
      final r = RetirementService.calculateBudget(
        avsMensuel: 3000,
        lppMensuel: 1000,
        depensesMensuelles: 5000,
        revenuPreRetraite: 10000,
        isCouple: true,
      );

      // Total = 4000 < 4500 => PC eligible
      expect(r['pcEligible'], isTrue);
    });

    test('duree 3a — nombre d annees de couverture par le capital 3a', () {
      final r = RetirementService.calculateBudget(
        avsMensuel: 2520,
        lppMensuel: 2000,
        capital3aNet: 240000,
        depensesMensuelles: 5000,
        revenuPreRetraite: 8000,
      );

      // duree3a = 240000 / (5000 * 12) = 4.0 ans
      expect((r['duree3aAns'] as double), closeTo(4.0, 0.1));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  //  Constantes et helpers
  // ═══════════════════════════════════════════════════════════════════════════

  group('constantes et helpers', () {
    test('rente AVS max annuelle = 30240', () {
      expect(RetirementService.avsMaxRenteAnnuelle, 30240.0);
    });

    test('taux conversion LPP = 6.8%', () {
      expect(RetirementService.lppConversionRate, 0.068);
    });

    test('26 cantons definis pour impot retrait capital', () {
      expect(tauxImpotRetraitCapital.length, 26);
    });

    test('cantons tries alphabetiquement', () {
      final codes = RetirementService.allCantonCodes;
      for (int i = 1; i < codes.length; i++) {
        expect(codes[i].compareTo(codes[i - 1]), greaterThan(0));
      }
    });

    test('formatChf — format avec apostrophe suisse', () {
      expect(RetirementService.formatChf(12345.0), contains("12'345"));
      expect(RetirementService.formatChf(1000000.0), contains("1'000'000"));
    });
  });
}
