import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/housing_sale_service.dart';

/// Unit tests for HousingSaleService — Sprint S24 (Vente immobiliere)
///
/// Tests pure Dart financial calculations for Swiss property sale:
///   - Impot sur les gains immobiliers (plus-value)
///   - Duree de detention et taux degressifs
///   - Remploi (report d'imposition, LHID art. 12 al. 3)
///   - Remboursement EPL (LPP art. 30d, OPP2 art. 30e)
///   - Produit net de la vente
///   - Alertes et checklist
///   - Compliance (disclaimer, sources, chiffre choc)
///
/// Legal references: LHID art. 12, LPP art. 30d, OPP2 art. 30e
void main() {
  // ════════════════════════════════════════════════════════════
  //  IMPOT SUR LES GAINS IMMOBILIERS
  // ════════════════════════════════════════════════════════════

  group('HousingSaleService - Plus-value et impot', () {
    test('plus-value brute = prix vente - prix achat - investissements - frais', () {
      final result = HousingSaleService.calculate(
        prixAchat: 500000,
        prixVente: 700000,
        anneeAchat: 2015,
        anneeVente: 2025,
        investissementsValorisants: 50000,
        fraisAcquisition: 10000,
        canton: 'ZH',
      );

      // 700000 - 500000 - 50000 - 10000 = 140000
      expect(result.plusValueBrute, 140000.0);
    });

    test('Zurich: detention 10 ans => taux 20%', () {
      final result = HousingSaleService.calculate(
        prixAchat: 500000,
        prixVente: 700000,
        anneeAchat: 2015,
        anneeVente: 2025,
        canton: 'ZH',
      );

      // Duration = 10, bracket [10, 15) => 0.20
      expect(result.dureeDetention, 10);
      expect(result.tauxImpositionPlusValue, 0.20);
    });

    test('Zurich: detention < 2 ans => taux speculatif 50%', () {
      final result = HousingSaleService.calculate(
        prixAchat: 500000,
        prixVente: 600000,
        anneeAchat: 2024,
        anneeVente: 2025,
        canton: 'ZH',
      );

      expect(result.dureeDetention, 1);
      expect(result.tauxImpositionPlusValue, 0.50);
    });

    test('Zurich: detention >= 20 ans => taux 0%', () {
      final result = HousingSaleService.calculate(
        prixAchat: 300000,
        prixVente: 700000,
        anneeAchat: 2000,
        anneeVente: 2025,
        canton: 'ZH',
      );

      expect(result.dureeDetention, 25);
      expect(result.tauxImpositionPlusValue, 0.0);
      expect(result.impotPlusValue, 0.0);
    });

    test('Vaud: detention 25+ ans => taux reduit 7% (jamais 0)', () {
      final result = HousingSaleService.calculate(
        prixAchat: 300000,
        prixVente: 700000,
        anneeAchat: 1995,
        anneeVente: 2025,
        canton: 'VD',
      );

      expect(result.dureeDetention, 30);
      expect(result.tauxImpositionPlusValue, 0.07);
    });

    test('impot = plus-value imposable * taux', () {
      final result = HousingSaleService.calculate(
        prixAchat: 500000,
        prixVente: 700000,
        anneeAchat: 2015,
        anneeVente: 2025,
        canton: 'ZH',
      );

      // plus-value = 200000, taux = 0.20, impot = 40000
      expect(result.impotPlusValue,
          closeTo(result.plusValueImposable * result.tauxImpositionPlusValue, 0.01));
    });

    test('vente a perte => plus-value imposable = 0, pas d\'impot', () {
      final result = HousingSaleService.calculate(
        prixAchat: 700000,
        prixVente: 600000,
        anneeAchat: 2015,
        anneeVente: 2025,
        canton: 'ZH',
      );

      expect(result.plusValueBrute, -100000.0);
      expect(result.plusValueImposable, 0.0);
      expect(result.impotPlusValue, 0.0);
    });

    test('canton inconnu => fallback sur VD', () {
      final resultUnknown = HousingSaleService.calculate(
        prixAchat: 500000,
        prixVente: 700000,
        anneeAchat: 2020,
        anneeVente: 2025,
        canton: 'XX',
      );

      final resultVD = HousingSaleService.calculate(
        prixAchat: 500000,
        prixVente: 700000,
        anneeAchat: 2020,
        anneeVente: 2025,
        canton: 'VD',
      );

      expect(resultUnknown.tauxImpositionPlusValue,
          resultVD.tauxImpositionPlusValue);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  REMPLOI (REPORT D'IMPOSITION)
  // ════════════════════════════════════════════════════════════

  group('HousingSaleService - Remploi', () {
    test('remploi total: prix remploi >= prix vente => impot differe complet', () {
      final result = HousingSaleService.calculate(
        prixAchat: 500000,
        prixVente: 700000,
        anneeAchat: 2015,
        anneeVente: 2025,
        canton: 'ZH',
        residencePrincipale: true,
        projetRemploi: true,
        prixRemploi: 800000,
      );

      expect(result.remploiReport, result.plusValueBrute);
      expect(result.plusValueImposable, 0.0);
      expect(result.impotPlusValue, 0.0);
    });

    test('remploi partiel: proportionnel au ratio', () {
      final result = HousingSaleService.calculate(
        prixAchat: 500000,
        prixVente: 700000,
        anneeAchat: 2015,
        anneeVente: 2025,
        canton: 'ZH',
        residencePrincipale: true,
        projetRemploi: true,
        prixRemploi: 350000, // 50% du prix de vente
      );

      // ratio = 350000 / 700000 = 0.50
      // remploi = plusValueBrute * 0.50
      final expectedRemploi = result.plusValueBrute * 0.50;
      expect(result.remploiReport, closeTo(expectedRemploi, 0.01));
      expect(result.plusValueImposable,
          closeTo(result.plusValueBrute - expectedRemploi, 0.01));
    });

    test('remploi impossible si pas residence principale', () {
      final result = HousingSaleService.calculate(
        prixAchat: 500000,
        prixVente: 700000,
        anneeAchat: 2015,
        anneeVente: 2025,
        canton: 'ZH',
        residencePrincipale: false,
        projetRemploi: true,
        prixRemploi: 800000,
      );

      expect(result.remploiReport, 0.0);
      expect(result.plusValueImposable, result.plusValueBrute);
    });

    test('pas de remploi sans projetRemploi', () {
      final result = HousingSaleService.calculate(
        prixAchat: 500000,
        prixVente: 700000,
        anneeAchat: 2015,
        anneeVente: 2025,
        canton: 'ZH',
        residencePrincipale: true,
        projetRemploi: false,
      );

      expect(result.remploiReport, 0.0);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  REMBOURSEMENT EPL
  // ════════════════════════════════════════════════════════════

  group('HousingSaleService - EPL', () {
    test('EPL LPP et 3a rembourses si residence principale', () {
      final result = HousingSaleService.calculate(
        prixAchat: 500000,
        prixVente: 700000,
        anneeAchat: 2015,
        anneeVente: 2025,
        canton: 'ZH',
        residencePrincipale: true,
        eplLppUtilise: 50000,
        epl3aUtilise: 20000,
      );

      expect(result.remboursementEplLpp, 50000.0);
      expect(result.remboursementEpl3a, 20000.0);
    });

    test('EPL pas rembourse si pas residence principale', () {
      final result = HousingSaleService.calculate(
        prixAchat: 500000,
        prixVente: 700000,
        anneeAchat: 2015,
        anneeVente: 2025,
        canton: 'ZH',
        residencePrincipale: false,
        eplLppUtilise: 50000,
        epl3aUtilise: 20000,
      );

      expect(result.remboursementEplLpp, 0.0);
      expect(result.remboursementEpl3a, 0.0);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  PRODUIT NET
  // ════════════════════════════════════════════════════════════

  group('HousingSaleService - Produit net', () {
    test('produit net = prix vente - hypotheque - impot - EPL', () {
      final result = HousingSaleService.calculate(
        prixAchat: 500000,
        prixVente: 700000,
        anneeAchat: 2015,
        anneeVente: 2025,
        canton: 'ZH',
        residencePrincipale: true,
        eplLppUtilise: 50000,
        epl3aUtilise: 20000,
        hypothequeRestante: 300000,
      );

      final expectedNet = 700000.0 -
          300000.0 -
          result.impotEffectif -
          50000.0 -
          20000.0;
      expect(result.produitNet, closeTo(expectedNet, 0.01));
    });

    test('produit net negatif => alerte', () {
      final result = HousingSaleService.calculate(
        prixAchat: 500000,
        prixVente: 520000,
        anneeAchat: 2024,
        anneeVente: 2025,
        canton: 'ZH',
        residencePrincipale: true,
        eplLppUtilise: 50000,
        epl3aUtilise: 20000,
        hypothequeRestante: 480000,
      );

      expect(result.produitNet, lessThan(0));
      expect(result.alerts, anyElement(contains('produit net est negatif')));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  ALERTES
  // ════════════════════════════════════════════════════════════

  group('HousingSaleService - Alertes', () {
    test('vente a perte => alerte moins-value', () {
      final result = HousingSaleService.calculate(
        prixAchat: 700000,
        prixVente: 600000,
        anneeAchat: 2015,
        anneeVente: 2025,
        canton: 'ZH',
      );

      expect(result.alerts, anyElement(contains('perte')));
    });

    test('detention < 2 ans => alerte speculative', () {
      final result = HousingSaleService.calculate(
        prixAchat: 500000,
        prixVente: 600000,
        anneeAchat: 2024,
        anneeVente: 2025,
        canton: 'ZH',
      );

      expect(result.alerts, anyElement(contains('speculative')));
    });

    test('EPL utilise => alerte obligation de remboursement', () {
      final result = HousingSaleService.calculate(
        prixAchat: 500000,
        prixVente: 700000,
        anneeAchat: 2015,
        anneeVente: 2025,
        canton: 'ZH',
        residencePrincipale: true,
        eplLppUtilise: 50000,
      );

      expect(result.alerts, anyElement(contains('LPP art. 30d')));
    });

    test('remploi sur non-residence principale => alerte', () {
      final result = HousingSaleService.calculate(
        prixAchat: 500000,
        prixVente: 700000,
        anneeAchat: 2015,
        anneeVente: 2025,
        canton: 'ZH',
        residencePrincipale: false,
        projetRemploi: true,
        prixRemploi: 800000,
      );

      expect(result.alerts,
          anyElement(contains('residence principale')));
    });

    test('hypotheque > 80% prix vente => alerte', () {
      final result = HousingSaleService.calculate(
        prixAchat: 500000,
        prixVente: 600000,
        anneeAchat: 2015,
        anneeVente: 2025,
        canton: 'ZH',
        hypothequeRestante: 500000,
      );

      expect(result.alerts, anyElement(contains('80%')));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  CHECKLIST ET COMPLIANCE
  // ════════════════════════════════════════════════════════════

  group('HousingSaleService - Checklist et compliance', () {
    test('checklist de base contient au moins 5 elements', () {
      final result = HousingSaleService.calculate(
        prixAchat: 500000,
        prixVente: 700000,
        anneeAchat: 2015,
        anneeVente: 2025,
        canton: 'ZH',
      );

      expect(result.checklist.length, greaterThanOrEqualTo(5));
      expect(result.checklist, anyElement(contains('estimation immobiliere')));
      expect(result.checklist, anyElement(contains('notaire')));
    });

    test('projet remploi ajoute element checklist', () {
      final result = HousingSaleService.calculate(
        prixAchat: 500000,
        prixVente: 700000,
        anneeAchat: 2015,
        anneeVente: 2025,
        canton: 'ZH',
        residencePrincipale: true,
        projetRemploi: true,
        prixRemploi: 800000,
      );

      expect(result.checklist, anyElement(contains('remploi')));
    });

    test('EPL LPP utilise ajoute element checklist', () {
      final result = HousingSaleService.calculate(
        prixAchat: 500000,
        prixVente: 700000,
        anneeAchat: 2015,
        anneeVente: 2025,
        canton: 'ZH',
        residencePrincipale: true,
        eplLppUtilise: 50000,
      );

      expect(result.checklist, anyElement(contains('EPL LPP')));
    });

    test('EPL 3a utilise ajoute element checklist', () {
      final result = HousingSaleService.calculate(
        prixAchat: 500000,
        prixVente: 700000,
        anneeAchat: 2015,
        anneeVente: 2025,
        canton: 'ZH',
        residencePrincipale: true,
        epl3aUtilise: 20000,
      );

      expect(result.checklist, anyElement(contains('EPL 3a')));
    });

    test('disclaimer mentionne outil educatif et LSFin', () {
      final result = HousingSaleService.calculate(
        prixAchat: 500000,
        prixVente: 700000,
        anneeAchat: 2015,
        anneeVente: 2025,
        canton: 'ZH',
      );

      expect(result.disclaimer, contains('outil educatif'));
      expect(result.disclaimer, contains('LSFin'));
    });

    test('sources contiennent LHID et LPP', () {
      final result = HousingSaleService.calculate(
        prixAchat: 500000,
        prixVente: 700000,
        anneeAchat: 2015,
        anneeVente: 2025,
        canton: 'ZH',
      );

      expect(result.sources, isNotEmpty);
      expect(result.sources, anyElement(contains('LHID art. 12')));
      expect(result.sources, anyElement(contains('LPP art. 30d')));
    });

    test('chiffre choc positif ou negatif selon produit net', () {
      // Cas positif
      final resultPositif = HousingSaleService.calculate(
        prixAchat: 500000,
        prixVente: 700000,
        anneeAchat: 2015,
        anneeVente: 2025,
        canton: 'ZH',
      );
      expect(resultPositif.chiffreChoc, contains('Produit net'));

      // Cas negatif
      final resultNegatif = HousingSaleService.calculate(
        prixAchat: 500000,
        prixVente: 520000,
        anneeAchat: 2024,
        anneeVente: 2025,
        canton: 'ZH',
        hypothequeRestante: 480000,
        eplLppUtilise: 50000,
        epl3aUtilise: 20000,
        residencePrincipale: true,
      );
      expect(resultNegatif.chiffreChoc, contains('negatif'));
    });
  });
}
