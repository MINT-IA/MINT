import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/lpp_deep_service.dart';

/// Unit tests pour LPP Deep Service — Sprint S15 (Chantier 4)
///
/// Teste les 3 simulateurs pedagogiques pour le 2e pilier approfondi :
///   A. RachatEchelonneSimulator — rachat LPP echelonne vs bloc
///   B. LibrePassageAdvisor      — checklist libre passage
///   C. EplSimulator             — retrait EPL (encouragement propriete logement)
///
/// Base legale : LPP art. 79b al. 3, LFLP, art. 30c LPP, OPP2 art. 5
void main() {
  // ════════════════════════════════════════════════════════════
  //  A. RACHAT ECHELONNE
  // ════════════════════════════════════════════════════════════

  group('RachatEchelonneSimulator', () {
    test('rachat echelonne donne plus d economie que rachat bloc', () {
      final result = RachatEchelonneSimulator.compare(
        avoirActuel: 200000,
        rachatMax: 50000,
        revenuImposable: 120000,
        canton: 'VD',
        civilStatus: 'single',
        horizon: 5,
      );
      // Delta positif = echelonne economise plus que bloc
      expect(result.delta, greaterThan(0));
      expect(
          result.economieEchelonneTotal, greaterThan(result.economieBlocTotal));
    });

    test('plan annuel contient le bon nombre d annees', () {
      final result = RachatEchelonneSimulator.compare(
        avoirActuel: 100000,
        rachatMax: 30000,
        revenuImposable: 80000,
        canton: 'VD',
        civilStatus: 'single',
        horizon: 3,
      );
      expect(result.yearlyPlan.length, 3);
    });

    test('chaque annee a rachat = min(rachatMax / horizon, revenu)', () {
      final result = RachatEchelonneSimulator.compare(
        avoirActuel: 100000,
        rachatMax: 40000,
        revenuImposable: 80000,
        canton: 'VD',
        civilStatus: 'single',
        horizon: 4,
      );
      for (final plan in result.yearlyPlan) {
        expect(plan.montantRachat, closeTo(10000, 0.01));
      }
    });

    test('cout net = rachat - economie fiscale', () {
      final result = RachatEchelonneSimulator.compare(
        avoirActuel: 100000,
        rachatMax: 20000,
        revenuImposable: 90000,
        canton: 'VD',
        civilStatus: 'single',
        horizon: 2,
      );
      for (final plan in result.yearlyPlan) {
        expect(
          plan.coutNet,
          closeTo(plan.montantRachat - plan.economieFiscale, 0.01),
        );
      }
    });

    test('horizon clampe entre 1 et 15', () {
      final resultHigh = RachatEchelonneSimulator.compare(
        avoirActuel: 100000,
        rachatMax: 30000,
        revenuImposable: 80000,
        canton: 'VD',
        civilStatus: 'single',
        horizon: 10, // within 1-15 range
      );
      // Source clamps horizon to 1-15, so 10 is within range
      expect(resultHigh.yearlyPlan.length, 10);
    });

    test('economie fiscale ne depasse pas impot total paye', () {
      final result = RachatEchelonneSimulator.compare(
        avoirActuel: 100000,
        rachatMax: 80000,
        revenuImposable: 80000,
        canton: 'VS',
        civilStatus: 'married',
        horizon: 1,
      );
      // L'economie ne peut pas depasser l'impot total
      // Pour un revenu de 80k VS marie, l'impot est ~8-12k
      // L'economie bloc est capee a ce montant
      expect(result.economieBlocTotal, lessThanOrEqualTo(15000));
      expect(result.economieBlocTotal, greaterThan(0));
    });

    test('rachat zero retourne economie zero', () {
      final result = RachatEchelonneSimulator.compare(
        avoirActuel: 100000,
        rachatMax: 0,
        revenuImposable: 80000,
        canton: 'VD',
        civilStatus: 'single',
        horizon: 3,
      );
      expect(result.economieBlocTotal, 0);
      expect(result.economieEchelonneTotal, 0);
    });

    test('economie fiscale bloc est capee par revenu imposable', () {
      final result = RachatEchelonneSimulator.compare(
        avoirActuel: 100000,
        rachatMax: 300000, // deduction > revenu imposable
        revenuImposable: 100000,
        canton: 'VD',
        civilStatus: 'single',
        horizon: 1,
      );
      // Bloc deductible cappe a revenu (100k), economie capee a impot total
      expect(result.economieBlocTotal, lessThanOrEqualTo(30000));
    });

    test('disclaimer mentionne LPP art. 79b al. 3', () {
      final result = RachatEchelonneSimulator.compare(
        avoirActuel: 100000,
        rachatMax: 20000,
        revenuImposable: 80000,
        canton: 'VD',
        civilStatus: 'single',
        horizon: 3,
      );
      expect(result.disclaimer, contains('79b'));
      expect(result.disclaimer, contains('spécialiste'));
    });

    test('rachat annuel cappe au revenu imposable', () {
      // Si rachat total = 600k sur 3 ans = 200k/an,
      // mais revenu = 100k, chaque annee ne deduit que 100k
      final result = RachatEchelonneSimulator.compare(
        avoirActuel: 200000,
        rachatMax: 600000,
        revenuImposable: 100000,
        canton: 'ZH',
        civilStatus: 'single',
        horizon: 3,
      );
      for (final plan in result.yearlyPlan) {
        expect(plan.montantRachat, lessThanOrEqualTo(100000));
      }
    });

    test('Julien golden test — rachat cappé 25% brut sur revenu 122k VS marie', () {
      // Audit 2026-04-18 P0-1 : le cap cashflow 25% brut force le rachat
      // annuel à min(500k/15, 122207 × 0.25) = min(33'333, 30'552) = 30'552.
      // Ancien calcul (pré-audit) : 33'333 CHF/an — irréaliste en cashflow
      // pour un revenu de 122k net de charges et dépenses courantes.
      final result = RachatEchelonneSimulator.compare(
        avoirActuel: 70377,
        rachatMax: 500000,
        revenuImposable: 122207,
        canton: 'VS',
        civilStatus: 'married',
        horizon: 15,
      );
      // Rachat annuel = min(500k/15 = 33'333, 122207 × 0.25 = 30'552) = 30'552
      expect(result.yearlyPlan.first.montantRachat, closeTo(30551.75, 1));
      // Economie par an doit etre < impot total (~15-20k pour 122k VS marie)
      expect(result.yearlyPlan.first.economieFiscale, lessThan(20000));
      // Economie par an doit etre raisonnable (5-10k pour ~30k deduit)
      expect(result.yearlyPlan.first.economieFiscale, greaterThan(2000));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  B. LIBRE PASSAGE ADVISOR
  // ════════════════════════════════════════════════════════════

  group('LibrePassageAdvisor', () {
    test('changement emploi avec nouvel employeur demande transfert 30j', () {
      final result = LibrePassageAdvisor.analyze(
        statut: LibrePassageStatut.changementEmploi,
        avoir: 150000,
        age: 35,
        hasNewEmployer: true,
      );
      final transfert = result.checklist.where(
        (c) => c.title.contains('30 jours'),
      );
      expect(transfert, isNotEmpty);
    });

    test('alerte critique si > 20 jours depuis depart avec nouvel employeur',
        () {
      final result = LibrePassageAdvisor.analyze(
        statut: LibrePassageStatut.changementEmploi,
        avoir: 150000,
        age: 35,
        hasNewEmployer: true,
        daysSinceDeparture: 25,
      );
      final alerteCritique = result.alerts.where(
        (a) => a.urgency == ChecklistUrgency.critique,
      );
      expect(alerteCritique, isNotEmpty);
    });

    test('sans nouvel employeur demande compte de libre passage', () {
      final result = LibrePassageAdvisor.analyze(
        statut: LibrePassageStatut.changementEmploi,
        avoir: 150000,
        age: 40,
        hasNewEmployer: false,
      );
      final librePassage = result.checklist.where(
        (c) => c.title.contains('libre passage'),
      );
      expect(librePassage, isNotEmpty);
    });

    test('depart suisse => verifier regles retrait', () {
      final result = LibrePassageAdvisor.analyze(
        statut: LibrePassageStatut.departSuisse,
        avoir: 200000,
        age: 40,
        hasNewEmployer: false,
      );
      final retraitItem = result.checklist.where(
        (c) => c.title.contains('pays de destination'),
      );
      expect(retraitItem, isNotEmpty);
    });

    test('depart suisse < 180 jours => alerte transfert', () {
      final result = LibrePassageAdvisor.analyze(
        statut: LibrePassageStatut.departSuisse,
        avoir: 200000,
        age: 40,
        hasNewEmployer: false,
        daysSinceDeparture: 100,
      );
      final transfertAlert = result.alerts.where(
        (a) => a.title.contains('6 mois'),
      );
      expect(transfertAlert, isNotEmpty);
    });

    test('cessation activite => verifier droits chomage', () {
      final result = LibrePassageAdvisor.analyze(
        statut: LibrePassageStatut.cessationActivite,
        avoir: 100000,
        age: 45,
        hasNewEmployer: false,
      );
      final chomageItem = result.checklist.where(
        (c) => c.title.contains('chômage'),
      );
      expect(chomageItem, isNotEmpty);
    });

    test('cessation activite a 58+ => recommandation maintien assurance', () {
      final result = LibrePassageAdvisor.analyze(
        statut: LibrePassageStatut.cessationActivite,
        avoir: 300000,
        age: 60,
        hasNewEmployer: false,
      );
      final maintien = result.recommendations.where(
        (r) => r.contains('58 ans'),
      );
      expect(maintien, isNotEmpty);
    });

    test('checklist contient toujours decompte de sortie et avoirs oublies',
        () {
      final result = LibrePassageAdvisor.analyze(
        statut: LibrePassageStatut.changementEmploi,
        avoir: 100000,
        age: 35,
        hasNewEmployer: true,
      );
      final decompte = result.checklist.where(
        (c) => c.title.contains('décompte'),
      );
      final oublies = result.checklist.where(
        (c) => c.title.contains('oubliés'),
      );
      expect(decompte, isNotEmpty);
      expect(oublies, isNotEmpty);
    });

    test('disclaimer mentionne LFLP et specialiste', () {
      final result = LibrePassageAdvisor.analyze(
        statut: LibrePassageStatut.changementEmploi,
        avoir: 100000,
        age: 35,
        hasNewEmployer: true,
      );
      expect(result.disclaimer, contains('LFLP'));
      expect(result.disclaimer, contains('spécialiste'));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  C. EPL SIMULATOR
  // ════════════════════════════════════════════════════════════

  group('EplSimulator', () {
    test('avant 50 ans : montant max = totalite de l avoir', () {
      final result = EplSimulator.simulate(
        avoirTotal: 150000,
        avoirObligatoire: 100000,
        avoirSurobligatoire: 50000,
        age: 40,
        montantSouhaite: 150000,
        aRachete: false,
      );
      expect(result.montantMaxRetirable, closeTo(150000, 0.01));
    });

    test('des 50 ans : fallback honnête = moitie avoir (LPP art. 30e al. 2)', () {
      // Audit 2026-04-18 P0-3 : l'ancienne formule inventée
      // `ratioA50 = 25/(age-25)` × avoirTotal n'avait aucune base légale.
      // Sans certificat d'avoir-à-50-ans, MINT utilise le fallback légal
      // garanti (la demi-part) et alerte l'utilisateur que son plafond
      // réel peut être plus élevé s'il consulte son certificat.
      final result = EplSimulator.simulate(
        avoirTotal: 200000,
        avoirObligatoire: 140000,
        avoirSurobligatoire: 60000,
        age: 55,
        montantSouhaite: 200000,
        aRachete: false,
      );
      expect(result.montantMaxRetirable, closeTo(100000.0, 1.0));
      expect(
        result.alerts.any((a) => a.contains('30e')),
        isTrue,
        reason: 'Alerte doit mentionner l\'article LPP 30e et inciter au certificat',
      );
    });

    test('minimum EPL de 20000 CHF', () {
      final result = EplSimulator.simulate(
        avoirTotal: 15000, // < 20000
        avoirObligatoire: 10000,
        avoirSurobligatoire: 5000,
        age: 35,
        montantSouhaite: 15000,
        aRachete: false,
      );
      expect(result.montantMaxRetirable, 0);
      expect(result.alerts, isNotEmpty);
      expect(result.alerts.first, contains('20\'000'));
    });

    test('blocage 3 ans apres rachat LPP (art. 79b al. 3)', () {
      final result = EplSimulator.simulate(
        avoirTotal: 200000,
        avoirObligatoire: 140000,
        avoirSurobligatoire: 60000,
        age: 40,
        montantSouhaite: 50000,
        aRachete: true,
        anneesSDepuisRachat: 1,
      );
      expect(result.montantMaxRetirable, 0);
      expect(result.montantSouhaiteApplicable, 0);
      final blocageAlert = result.alerts.where(
        (a) => a.contains('79b'),
      );
      expect(blocageAlert, isNotEmpty);
    });

    test('pas de blocage si rachat > 3 ans', () {
      final result = EplSimulator.simulate(
        avoirTotal: 200000,
        avoirObligatoire: 140000,
        avoirSurobligatoire: 60000,
        age: 40,
        montantSouhaite: 50000,
        aRachete: true,
        anneesSDepuisRachat: 4,
      );
      expect(result.montantMaxRetirable, greaterThan(0));
      expect(result.montantSouhaiteApplicable, closeTo(50000, 0.01));
    });

    test('impot progressif via RetirementTaxCalculator (ZH base rate 6.5%)', () {
      // EPL uses RetirementTaxCalculator.capitalWithdrawalTax with canton ZH (default)
      // ZH base rate = 0.065, progressive brackets: 0-100k (1.0x), 100k-200k (1.15x), etc.
      final result30k = EplSimulator.simulate(
        avoirTotal: 200000,
        avoirObligatoire: 140000,
        avoirSurobligatoire: 60000,
        age: 35,
        montantSouhaite: 30000,
        aRachete: false,
      );
      // 30000 * 0.065 * 1.0 = 1950
      expect(result30k.impotEstime, closeTo(1950, 1.0));

      final result80k = EplSimulator.simulate(
        avoirTotal: 200000,
        avoirObligatoire: 140000,
        avoirSurobligatoire: 60000,
        age: 35,
        montantSouhaite: 80000,
        aRachete: false,
      );
      // 80000 * 0.065 * 1.0 = 5200
      expect(result80k.impotEstime, closeTo(5200, 1.0));
    });

    test('impot progressif sur montants > 100k', () {
      final result150k = EplSimulator.simulate(
        avoirTotal: 300000,
        avoirObligatoire: 200000,
        avoirSurobligatoire: 100000,
        age: 35,
        montantSouhaite: 150000,
        aRachete: false,
      );
      // ZH base rate = 0.065
      // First 100k: 100000 * 0.065 * 1.0 = 6500
      // Next 50k: 50000 * 0.065 * 1.15 = 3737.5
      // Total = 10237.5
      expect(result150k.impotEstime, closeTo(10237.5, 1.0));
    });

    test('reduction prestations risque : null + alerte qualitative', () {
      // Audit 2026-04-18 P1-2 : la formule magique
      // `ratio × avoirTotal × 0.06` (invalidité) / `× 0.5` (décès) n'avait
      // aucune base légale LPP art. 24 al. 2. Remplacée par null +
      // alerte qualitative "à demander à ta caisse". La UI rend alors
      // le label `eplReductionAskCaisse` au lieu d'un chiffre CHF trompeur.
      final result = EplSimulator.simulate(
        avoirTotal: 200000,
        avoirObligatoire: 140000,
        avoirSurobligatoire: 60000,
        age: 35,
        montantSouhaite: 100000,
        aRachete: false,
      );
      expect(result.reductionRenteInvalidite, isNull);
      expect(result.reductionCapitalDeces, isNull);
      // Une alerte qualitative doit apparaître mentionnant la caisse
      expect(
        result.alerts.any((a) => a.contains('caisse')),
        isTrue,
        reason: 'Alerte qualitative sur réduction prestations manquante',
      );
    });

    test('alerte 50+ quand applicable > 0 et age >= 50', () {
      final result = EplSimulator.simulate(
        avoirTotal: 200000,
        avoirObligatoire: 140000,
        avoirSurobligatoire: 60000,
        age: 52,
        montantSouhaite: 50000,
        aRachete: false,
      );
      final alerte50 = result.alerts.where(
        (a) => a.contains('50 ans'),
      );
      expect(alerte50, isNotEmpty);
    });

    test('alerte remboursement en cas de vente', () {
      final result = EplSimulator.simulate(
        avoirTotal: 200000,
        avoirObligatoire: 140000,
        avoirSurobligatoire: 60000,
        age: 35,
        montantSouhaite: 50000,
        aRachete: false,
      );
      final alerteVente = result.alerts.where(
        (a) => a.contains('remboursement') || a.contains('vente'),
      );
      expect(alerteVente, isNotEmpty);
    });

    test('disclaimer mentionne art. 30c LPP et specialiste', () {
      final result = EplSimulator.simulate(
        avoirTotal: 200000,
        avoirObligatoire: 140000,
        avoirSurobligatoire: 60000,
        age: 35,
        montantSouhaite: 50000,
        aRachete: false,
      );
      expect(result.disclaimer, contains('30c LPP'));
      expect(result.disclaimer, contains('spécialiste'));
    });

    test('montant souhaite plafonne au montant max retirable', () {
      final result = EplSimulator.simulate(
        avoirTotal: 100000,
        avoirObligatoire: 70000,
        avoirSurobligatoire: 30000,
        age: 35,
        montantSouhaite: 200000, // > avoir total
        aRachete: false,
      );
      expect(result.montantSouhaiteApplicable, closeTo(100000, 0.01));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  HELPER — formatChf
  // ════════════════════════════════════════════════════════════

  group('formatChf', () {
    test('formate avec apostrophe suisse', () {
      expect(formatChf(1234567), "1'234'567");
      expect(formatChf(100000), "100'000");
      expect(formatChf(999), '999');
    });

    test('arrondit les decimales', () {
      expect(formatChf(1234.56), "1'235");
      expect(formatChf(999.4), '999');
    });
  });
}
