import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/services/regulatory_sync_service.dart';
import 'package:mint_mobile/services/retirement_service.dart';

/// Tests unitaires pour RetirementService (Sprint S21).
///
/// Couvre les 2 modules de planification retraite :
///   1. compareLpp     — comparaison capital vs rente LPP
///   2. calculateBudget — budget retraite
///
/// Constantes 2025/2026 :
///   - Taux conversion LPP min : 6.8%
///   - Duree cotisation complete : 44 ans
void main() {
  setUp(RegulatorySyncService.clearCache);
  tearDown(RegulatorySyncService.clearCache);

  // ═══════════════════════════════════════════════════════════════════════════
  //  1. compareLpp — capital vs rente
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

    test('impot capital ZH — modèle v2 (IFD art. 38 + ESTV)', () {
      final r = RetirementService.compareLpp(
        capitalLpp: 500000,
        canton: 'ZH',
      );

      // v2 -2i2 : IFD art. 38 (1/5 du barème revenu) + interpolation
      // cantonale sur points ESTV officiels.
      // Sanity backend : estimate_capital_withdrawal_tax(500000, 'ZH')
      // = 35067.69.
      expect(r['capitalImpot'] as double, closeTo(35067.69, 1)); // v2 -2i2
      expect(r['capitalNet'] as double, closeTo(500000 - 35067.69, 1));
    });

    test('impot capital VD — capital 300k (modèle v2)', () {
      final r = RetirementService.compareLpp(
        capitalLpp: 300000,
        canton: 'VD',
      );

      // v2 -2i2 : sanity backend
      // estimate_capital_withdrawal_tax(300000, 'VD') = 22277.89.
      expect(r['capitalImpot'] as double, closeTo(22277.89, 1)); // v2 -2i2
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

    test('canton inconnu — repli ZH (resolveCanton)', () {
      final r = RetirementService.compareLpp(
        capitalLpp: 100000,
        canton: 'XX',
      );

      // v2 -2i2 : 'XX' → repli ZH (resolveCanton) ; sanity backend
      // estimate_capital_withdrawal_tax(100000, 'ZH') = 4816.89.
      expect(r['capitalImpot'] as double, closeTo(4816.89, 1)); // v2 -2i2
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

    test('rente AVS max annuelle year-aware applique la 13eme rente des 2026',
        () {
      expect(RetirementService.avsMaxRenteAnnuelleForYear(2025), 30240.0);
      expect(
        RetirementService.avsMaxRenteAnnuelleForYear(2026),
        closeTo(32760.0, 0.01),
      );
      expect(
        RetirementService.avsMaxRenteAnnuelleForYear(2035),
        closeTo(32760.0, 0.01),
      );
    });

    test('rente AVS max annuelle year-aware lit les cles registry statiques',
        () {
      RegulatorySyncService.setMockCache({
        'avs.max_annual_pension': 24000.0,
        'avs.13th_pension_active': 1.0,
        'avs.13th_pension_start_year': 2030.0,
        'avs.13th_pension_factor': 1.25,
      });

      expect(RetirementService.avsMaxRenteAnnuelleForYear(2029), 24000.0);
      expect(RetirementService.avsMaxRenteAnnuelleForYear(2030), 30000.0);

      RegulatorySyncService.setMockCache({
        'avs.max_annual_pension': 24000.0,
        'avs.13th_pension_active': 0.0,
        'avs.13th_pension_start_year': 2030.0,
        'avs.13th_pension_factor': 1.25,
      });

      expect(RetirementService.avsMaxRenteAnnuelleForYear(2035), 24000.0);
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
