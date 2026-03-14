import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/mortgage_service.dart';

/// Tests unitaires pour MortgageService (Sprint S17).
///
/// Couvre les 5 calculateurs hypothecaires :
///   A. AffordabilityCalculator  — capacite d'achat (regle 1/3, fonds propres 20%)
///   B. SaronVsFixedCalculator   — comparateur SARON vs taux fixe
///   C. ImputedRentalCalculator  — valeur locative et impact fiscal
///   D. AmortizationCalculator   — amortissement direct vs indirect
///   E. EplCombinedCalculator    — financement EPL multi-sources
///
/// Base legale : directive ASB, FINMA, LIFD, LPP art. 30c, OPP3.
void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  //  A. AffordabilityCalculator
  // ═══════════════════════════════════════════════════════════════════════════

  group('AffordabilityCalculator', () {
    test('scenario standard — revenu 150k, prix 800k, fonds propres suffisants', () {
      final r = AffordabilityCalculator.calculate(
        revenuBrutAnnuel: 150000,
        epargneDispo: 120000,
        avoir3a: 40000,
        avoirLpp: 80000,
        prixAchat: 800000,
        canton: 'ZH',
      );

      // Fonds propres = 120000 + 40000 + min(80000, 800000*0.10) = 240000
      expect(r.fondsPropresTotal, closeTo(240000, 1));
      // Requis = 800000 * 0.20 = 160000
      expect(r.fondsPropresRequis, closeTo(160000, 1));
      expect(r.fondsPropresOk, isTrue);
      expect(r.manqueFondsPropres, closeTo(0, 1));
    });

    test('regle du 1/3 — charges theoriques ne depassent pas 33% du revenu', () {
      // Revenu 200k, prix 700k, fonds propres largement suffisants
      final r = AffordabilityCalculator.calculate(
        revenuBrutAnnuel: 200000,
        epargneDispo: 200000,
        avoir3a: 50000,
        avoirLpp: 100000,
        prixAchat: 700000,
        canton: 'VD',
      );

      // charges = hypotheque * 6% + prix * 1%
      // hypotheque = max(0, 700000 - fondsPropresTotal)
      // fondsPropresTotal = 200000 + 50000 + min(100000, 70000) = 320000
      // hypotheque = max(0, 700000 - 320000) = 380000
      // charges annuelles = 380000 * 0.06 + 700000 * 0.01 = 22800 + 7000 = 29800
      // ratio = 29800 / 200000 = 0.149
      expect(r.ratioCharges, lessThan(1 / 3));
      expect(r.capaciteOk, isTrue);
    });

    test('revenu zero — ratio charges = 1.0, capacite non ok', () {
      final r = AffordabilityCalculator.calculate(
        revenuBrutAnnuel: 0,
        epargneDispo: 100000,
        avoir3a: 0,
        avoirLpp: 0,
        prixAchat: 500000,
        canton: 'GE',
      );

      expect(r.ratioCharges, 1.0);
      expect(r.capaciteOk, isFalse);
      expect(r.prixMaxAccessible, 0.0);
    });

    test('fonds propres insuffisants — manque detecte', () {
      final r = AffordabilityCalculator.calculate(
        revenuBrutAnnuel: 120000,
        epargneDispo: 30000,
        avoir3a: 10000,
        avoirLpp: 20000,
        prixAchat: 800000,
        canton: 'BE',
      );

      // FP total = 30000 + 10000 + min(20000, 80000) = 60000
      // FP requis = 160000
      expect(r.fondsPropresOk, isFalse);
      expect(r.manqueFondsPropres, closeTo(100000, 1));
      expect(r.chiffreChocPositif, isFalse);
    });

    test('LPP est plafonne a 10% du prix d achat', () {
      final r = AffordabilityCalculator.calculate(
        revenuBrutAnnuel: 200000,
        epargneDispo: 50000,
        avoir3a: 30000,
        avoirLpp: 500000,
        prixAchat: 600000,
        canton: 'ZH',
      );

      // LPP utilise = min(500000, 600000 * 0.10) = 60000
      // FP = 50000 + 30000 + 60000 = 140000
      expect(r.fondsPropresTotal, closeTo(140000, 1));
    });

    test('prix achat zero — pas de manque', () {
      final r = AffordabilityCalculator.calculate(
        revenuBrutAnnuel: 100000,
        epargneDispo: 50000,
        avoir3a: 20000,
        avoirLpp: 30000,
        prixAchat: 0,
        canton: 'LU',
      );

      expect(r.fondsPropresRequis, 0.0);
      expect(r.fondsPropresOk, isTrue);
      expect(r.manqueFondsPropres, 0.0);
    });

    test('charges theoriques = hypotheque * 6% + prix * 1%', () {
      // Cas verifie manuellement
      final r = AffordabilityCalculator.calculate(
        revenuBrutAnnuel: 180000,
        epargneDispo: 100000,
        avoir3a: 0,
        avoirLpp: 0,
        prixAchat: 500000,
        canton: 'ZH',
      );

      // FP = 100000 + 0 + 0 = 100000
      // Hypotheque = max(0, 500000 - 100000) = 400000
      // Charges annuelles = 400000 * 0.06 + 500000 * 0.01 = 24000 + 5000 = 29000
      // Mensuelles = 29000 / 12
      expect(r.chargesTheoriquesMensuelles, closeTo(29000 / 12, 1));
    });

    test('disclaimer contient les mentions legales obligatoires', () {
      final r = AffordabilityCalculator.calculate(
        revenuBrutAnnuel: 100000,
        epargneDispo: 50000,
        avoir3a: 0,
        avoirLpp: 0,
        prixAchat: 400000,
        canton: 'ZH',
      );

      expect(r.disclaimer, contains('ASB'));
      expect(r.disclaimer, contains('spécialiste'));
    });

    test('chiffre choc positif quand capacite et fonds propres ok', () {
      final r = AffordabilityCalculator.calculate(
        revenuBrutAnnuel: 300000,
        epargneDispo: 300000,
        avoir3a: 80000,
        avoirLpp: 200000,
        prixAchat: 500000,
        canton: 'ZH',
      );

      expect(r.capaciteOk, isTrue);
      expect(r.fondsPropresOk, isTrue);
      expect(r.chiffreChocPositif, isTrue);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  //  B. SaronVsFixedCalculator
  // ═══════════════════════════════════════════════════════════════════════════

  group('SaronVsFixedCalculator', () {
    test('comparaison 10 ans — fixe a 2.50% vs SARON 2.05%', () {
      final r = SaronVsFixedCalculator.compare(
        montantHypothecaire: 500000,
        dureeAns: 10,
      );

      // Fixe : 500000 * 0.025 * 10 = 125000
      expect(r.fixe.coutTotal, closeTo(125000, 1));
      expect(r.fixe.tauxInitial, 0.025);

      // SARON stable : 500000 * 0.0205 * 10 = 102500
      expect(r.saronStable.coutTotal, closeTo(102500, 1));
      expect(r.saronStable.tauxInitial, 0.0205);
    });

    test('economie SARON stable positive quand fixe > SARON', () {
      final r = SaronVsFixedCalculator.compare(
        montantHypothecaire: 400000,
        dureeAns: 10,
      );

      expect(r.economieSaronStable, greaterThan(0));
      expect(r.chiffreChocTexte, contains('economise'));
    });

    test('SARON hausse — taux augmente de 0.25% par an', () {
      final r = SaronVsFixedCalculator.compare(
        montantHypothecaire: 500000,
        dureeAns: 5,
      );

      // An 1 : 500000 * 0.0205 = 10250
      expect(r.saronHausse.annualData[0].coutAnnuel, closeTo(10250, 1));
      // An 2 : 500000 * (0.0205 + 0.0025) = 500000 * 0.0230 = 11500
      expect(r.saronHausse.annualData[1].coutAnnuel, closeTo(11500, 1));
      // An 5 : 500000 * (0.0205 + 0.0100) = 500000 * 0.0305 = 15250
      expect(r.saronHausse.annualData[4].coutAnnuel, closeTo(15250, 1));
    });

    test('duree clampee — min 5 ans, max 15 ans', () {
      final r3 = SaronVsFixedCalculator.compare(
        montantHypothecaire: 500000,
        dureeAns: 3,
      );
      expect(r3.fixe.annualData.length, 5);

      final r20 = SaronVsFixedCalculator.compare(
        montantHypothecaire: 500000,
        dureeAns: 20,
      );
      expect(r20.fixe.annualData.length, 15);
    });

    test('montant hypothecaire clampe — min 100k, max 5M', () {
      final r = SaronVsFixedCalculator.compare(
        montantHypothecaire: 50000,
        dureeAns: 10,
      );
      // Clampe a 100000
      expect(r.fixe.coutTotal, closeTo(100000 * 0.025 * 10, 1));
    });

    test('cout cumule croissant annee apres annee', () {
      final r = SaronVsFixedCalculator.compare(
        montantHypothecaire: 500000,
        dureeAns: 10,
      );

      for (int i = 1; i < r.fixe.annualData.length; i++) {
        expect(r.fixe.annualData[i].coutCumule,
            greaterThan(r.fixe.annualData[i - 1].coutCumule));
      }
    });

    test('disclaimer ne contient pas de termes interdits', () {
      final r = SaronVsFixedCalculator.compare(
        montantHypothecaire: 500000,
        dureeAns: 10,
      );

      // "garantit" (conjugue) est acceptable dans "ne garantit pas",
      // mais "garanti" comme adjectif absolu est interdit.
      // On verifie l'absence de termes interdits sous forme absolue.
      expect(r.disclaimer, isNot(contains('sans risque')));
      expect(r.disclaimer, isNot(contains('conseil hypothecaire personnalise')));
      // Le disclaimer doit contenir la mention educative
      expect(r.disclaimer, contains('educatif'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  //  C. ImputedRentalCalculator
  // ═══════════════════════════════════════════════════════════════════════════

  group('ImputedRentalCalculator', () {
    test('valeur locative ZH — 3.5% de la valeur venale', () {
      final r = ImputedRentalCalculator.calculate(
        valeurVenale: 1000000,
        interetsAnnuels: 10000,
        fraisEntretien: 0,
        canton: 'ZH',
        bienAncien: false,
        tauxMarginal: 0.30,
      );

      expect(r.valeurLocative, closeTo(35000, 1));
    });

    test('bien ancien — forfait entretien 20% vs 10% pour bien recent', () {
      final rRecent = ImputedRentalCalculator.calculate(
        valeurVenale: 1000000,
        interetsAnnuels: 10000,
        fraisEntretien: 0,
        canton: 'ZH',
        bienAncien: false,
        tauxMarginal: 0.30,
      );

      final rAncien = ImputedRentalCalculator.calculate(
        valeurVenale: 1000000,
        interetsAnnuels: 10000,
        fraisEntretien: 0,
        canton: 'ZH',
        bienAncien: true,
        tauxMarginal: 0.30,
      );

      // Forfait entretien ancien (20%) > recent (10%)
      expect(rAncien.deductionFraisEntretien,
          greaterThan(rRecent.deductionFraisEntretien));
    });

    test('frais effectifs utilises si superieurs au forfait', () {
      final r = ImputedRentalCalculator.calculate(
        valeurVenale: 1000000,
        interetsAnnuels: 10000,
        fraisEntretien: 50000,
        canton: 'ZH',
        bienAncien: false,
        tauxMarginal: 0.30,
      );

      // Forfait = 35000 * 0.10 = 3500 vs frais effectifs 50000
      expect(r.deductionFraisEntretien, closeTo(50000, 1));
    });

    test('impact positif — chiffre choc negatif (impot supplementaire)', () {
      final r = ImputedRentalCalculator.calculate(
        valeurVenale: 1500000,
        interetsAnnuels: 5000,
        fraisEntretien: 0,
        canton: 'GE',
        bienAncien: false,
        tauxMarginal: 0.35,
      );

      // VL = 1500000 * 0.045 = 67500
      // Deductions faibles => impact net positif => impot supplementaire
      expect(r.impactNet, greaterThan(0));
      expect(r.chiffreChocPositif, isFalse);
    });

    test('canton inconnu — taux par defaut 3.5%', () {
      final r = ImputedRentalCalculator.calculate(
        valeurVenale: 1000000,
        interetsAnnuels: 10000,
        fraisEntretien: 0,
        canton: 'XX',
        bienAncien: false,
        tauxMarginal: 0.30,
      );

      expect(r.valeurLocative, closeTo(35000, 1));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  //  D. AmortizationCalculator
  // ═══════════════════════════════════════════════════════════════════════════

  group('AmortizationCalculator', () {
    test('indirect vs direct — indirect plus avantageux grace a la double deduction', () {
      final r = AmortizationCalculator.compare(
        montantHypothecaire: 500000,
        tauxInteret: 0.02,
        dureeAns: 15,
        tauxMarginal: 0.30,
      );

      // Indirect beneficie de la double deduction (interets + 3a)
      expect(r.economieIndirect, greaterThan(0));
      expect(r.chiffreChocPositif, isTrue);
    });

    test('direct — dette diminue chaque annee', () {
      final r = AmortizationCalculator.compare(
        montantHypothecaire: 500000,
        tauxInteret: 0.02,
        dureeAns: 10,
        tauxMarginal: 0.30,
      );

      // La dette diminue dans le plan direct
      for (int i = 1; i < r.directPlan.length; i++) {
        expect(r.directPlan[i].detteRestante,
            lessThanOrEqualTo(r.directPlan[i - 1].detteRestante));
      }
    });

    test('indirect — dette reste constante', () {
      final r = AmortizationCalculator.compare(
        montantHypothecaire: 500000,
        tauxInteret: 0.02,
        dureeAns: 10,
        tauxMarginal: 0.30,
      );

      for (final point in r.indirectPlan) {
        expect(point.detteRestante, closeTo(500000, 1));
      }
    });

    test('capital 3a accumule dans l amortissement indirect', () {
      final r = AmortizationCalculator.compare(
        montantHypothecaire: 500000,
        tauxInteret: 0.02,
        dureeAns: 15,
        tauxMarginal: 0.30,
      );

      // Capital 3a final > 0 et croissant
      expect(r.capital3aFinal, greaterThan(0));
      for (int i = 1; i < r.indirectPlan.length; i++) {
        expect(r.indirectPlan[i].capital3a,
            greaterThan(r.indirectPlan[i - 1].capital3a));
      }
    });

    test('duree clampee entre 1 et 30 ans', () {
      final r0 = AmortizationCalculator.compare(
        montantHypothecaire: 500000,
        tauxInteret: 0.02,
        dureeAns: 0,
        tauxMarginal: 0.30,
      );
      expect(r0.directPlan.length, 1);

      final r50 = AmortizationCalculator.compare(
        montantHypothecaire: 500000,
        tauxInteret: 0.02,
        dureeAns: 50,
        tauxMarginal: 0.30,
      );
      expect(r50.directPlan.length, 30);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  //  E. EplCombinedCalculator
  // ═══════════════════════════════════════════════════════════════════════════

  group('EplCombinedCalculator', () {
    test('cash couvre tout — pas d impot', () {
      final r = EplCombinedCalculator.calculate(
        epargneCash: 300000,
        avoir3a: 50000,
        avoirLpp: 100000,
        prixCible: 1000000,
        canton: 'ZH',
      );

      // FP requis = 200000, cash = 300000 => cash couvre tout
      expect(r.objectifAtteint, isTrue);
      expect(r.totalImpots, closeTo(0, 1));
      expect(r.sources.length, 1); // Seulement cash
      expect(r.sources[0].label, 'Epargne cash');
    });

    test('allocation dans l ordre cash > 3a > LPP', () {
      final r = EplCombinedCalculator.calculate(
        epargneCash: 50000,
        avoir3a: 80000,
        avoirLpp: 200000,
        prixCible: 1000000,
        canton: 'ZH',
      );

      // FP requis = 200000
      // Cash: 50000, 3a: 80000, LPP: min(200000, 100000) -> max LPP = 100000 -> utilise 70000
      // Gross = 200000 but net < 200000 after progressive tax on 150k withdrawals
      expect(r.objectifAtteint, isFalse);
      expect(r.sources.length, 3);
      expect(r.sources[0].label, 'Epargne cash');
      expect(r.sources[0].montant, closeTo(50000, 1));
      expect(r.sources[1].label, 'Retrait 3a');
      expect(r.sources[1].montant, closeTo(80000, 1));
      expect(r.sources[2].label, 'Retrait LPP (EPL)');
      expect(r.sources[2].montant, closeTo(70000, 1));
    });

    test('LPP plafonne a 10% du prix', () {
      final r = EplCombinedCalculator.calculate(
        epargneCash: 0,
        avoir3a: 0,
        avoirLpp: 500000,
        prixCible: 1000000,
        canton: 'ZH',
      );

      // LPP max = 10% de 1M = 100000
      // FP requis = 200000 => objectif non atteint
      expect(r.fondsPropresTotal, closeTo(100000, 1));
      expect(r.objectifAtteint, isFalse);
    });

    test('impot progressif sur retrait 3a et LPP', () {
      final r = EplCombinedCalculator.calculate(
        epargneCash: 0,
        avoir3a: 150000,
        avoirLpp: 200000,
        prixCible: 1000000,
        canton: 'ZH',
      );

      // Impot > 0 car retrait 3a et LPP
      expect(r.totalImpots, greaterThan(0));
    });

    test('alerte quand retrait combine 3a + LPP', () {
      final r = EplCombinedCalculator.calculate(
        epargneCash: 0,
        avoir3a: 100000,
        avoirLpp: 200000,
        prixCible: 800000,
        canton: 'VD',
      );

      // Devrait avoir une alerte sur la progressivite
      final hasProgressivityAlert = r.alertes.any(
          (a) => a.contains('progressivite') || a.contains('etaler'));
      expect(hasProgressivityAlert, isTrue);
    });

    test('alerte quand fonds propres insuffisants', () {
      final r = EplCombinedCalculator.calculate(
        epargneCash: 10000,
        avoir3a: 5000,
        avoirLpp: 20000,
        prixCible: 1000000,
        canton: 'ZH',
      );

      expect(r.objectifAtteint, isFalse);
      final hasInsufAlert = r.alertes.any((a) => a.contains('manque'));
      expect(hasInsufAlert, isTrue);
    });

    test('pourcentage couvert calcule correctement', () {
      final r = EplCombinedCalculator.calculate(
        epargneCash: 100000,
        avoir3a: 0,
        avoirLpp: 0,
        prixCible: 1000000,
        canton: 'ZH',
      );

      // 100000 / 1000000 * 100 = 10%
      expect(r.pourcentageCouvert, closeTo(10.0, 0.1));
    });

    test('disclaimer contient les references legales', () {
      final r = EplCombinedCalculator.calculate(
        epargneCash: 100000,
        avoir3a: 50000,
        avoirLpp: 100000,
        prixCible: 500000,
        canton: 'ZH',
      );

      expect(r.disclaimer, contains('LPP art. 30c'));
      expect(r.disclaimer, contains('OPP3'));
      expect(r.disclaimer, contains('LIFD art. 38'));
    });
  });
}
