import 'dart:math';

import 'package:mint_mobile/services/financial_core/financial_core.dart';
import 'package:mint_mobile/services/tax_estimator_service.dart';

// ============================================================================
// LPP Deep Service — Sprint S15 (Chantier 4)
//
// Trois simulateurs pedagogiques pour le 2e pilier approfondi :
//   A. RachatEchelonneSimulator  — rachat LPP echelonne vs bloc
//   B. LibrePassageAdvisor       — checklist libre passage
//   C. EplSimulator              — retrait EPL (encouragement propriete logement)
//
// Base legale : LPP art. 79b al. 3, LFLP, art. 30c LPP
// ============================================================================

// ─────────────────────────────────────────────────────────────────────────────
// A. Rachat Echelonne
// ─────────────────────────────────────────────────────────────────────────────

/// Resultat annuel du plan de rachat echelonne
class RachatYearPlan {
  final int annee;
  final double montantRachat;
  final double economieFiscale;
  final double coutNet;

  const RachatYearPlan({
    required this.annee,
    required this.montantRachat,
    required this.economieFiscale,
    required this.coutNet,
  });
}

/// Resultat global de la comparaison bloc vs echelonne
class RachatEchelonneResult {
  final double economieBlocTotal;
  final double economieEchelonneTotal;
  final double delta;
  final List<RachatYearPlan> yearlyPlan;
  final String disclaimer;

  const RachatEchelonneResult({
    required this.economieBlocTotal,
    required this.economieEchelonneTotal,
    required this.delta,
    required this.yearlyPlan,
    required this.disclaimer,
  });
}

class RachatEchelonneSimulator {
  /// Compare le rachat en bloc (1 an) vs echelonne sur [horizon] annees.
  ///
  /// Utilise TaxEstimatorService.estimateAnnualTax() pour un calcul réel :
  ///   économie = impôt(revenu) - impôt(revenu - déduction)
  ///
  /// [avoirActuel]     — avoir actuel LPP (CHF)
  /// [rachatMax]       — montant total du rachat possible (CHF)
  /// [revenuImposable] — revenu imposable annuel brut (CHF)
  /// [canton]          — code canton (ex: 'VS')
  /// [civilStatus]     — 'single' ou 'married'
  /// [horizon]         — nombre d'annees d'echelonnement (1 – 15)
  ///
  /// Regle : Pas d'EPL dans les 3 ans suivant un rachat (LPP art. 79b al. 3).
  static RachatEchelonneResult compare({
    required double avoirActuel,
    required double rachatMax,
    required double revenuImposable,
    required String canton,
    required String civilStatus,
    required int horizon,
    // Legacy param kept for backwards compatibility, ignored if canton provided
    double tauxMarginalEstime = 0.30,
  }) {
    final clampedHorizon = horizon.clamp(1, 15);
    // No arbitrary 500k cap — use actual rachat max from profile/slider
    final clampedRachat = rachatMax.clamp(0.0, double.infinity);

    // --- Impôt de base (sans rachat) ---
    // Convert brut to net mensuel (approx: brut * 0.87 / 12 for social charges)
    final netMensuel = revenuImposable * 0.87 / 12;
    final impotSansRachat = TaxEstimatorService.estimateAnnualTax(
      netMonthlyIncome: netMensuel,
      cantonCode: canton,
      civilStatus: civilStatus,
      childrenCount: 0,
      age: 50,
    );

    // --- Bloc (1 an) ---
    // On ne peut déduire que min(rachat, revenu) en 1 an (LIFD art. 33).
    final blocDeductible = clampedRachat.clamp(0.0, revenuImposable);
    final netMensuelApresBloc = (revenuImposable - blocDeductible) * 0.87 / 12;
    final impotApresBloc = TaxEstimatorService.estimateAnnualTax(
      netMonthlyIncome: netMensuelApresBloc,
      cantonCode: canton,
      civilStatus: civilStatus,
      childrenCount: 0,
      age: 50,
    );
    final economieBlocTotal =
        (impotSansRachat - impotApresBloc).clamp(0.0, impotSansRachat);

    // --- Echelonne ---
    final rachatAnnuel = clampedRachat / clampedHorizon;
    // Cap annuel : on ne peut pas déduire plus que le revenu
    final rachatAnnuelEffectif =
        rachatAnnuel.clamp(0.0, revenuImposable);
    final List<RachatYearPlan> plan = [];
    double totalEconomieEchelonne = 0;

    final netMensuelApresEchelon =
        (revenuImposable - rachatAnnuelEffectif) * 0.87 / 12;
    final impotApresEchelon = TaxEstimatorService.estimateAnnualTax(
      netMonthlyIncome: netMensuelApresEchelon,
      cantonCode: canton,
      civilStatus: civilStatus,
      childrenCount: 0,
      age: 50,
    );
    final economieAnnuelle =
        (impotSansRachat - impotApresEchelon).clamp(0.0, impotSansRachat);

    for (int i = 0; i < clampedHorizon; i++) {
      totalEconomieEchelonne += economieAnnuelle;
      plan.add(RachatYearPlan(
        annee: i + 1,
        montantRachat: rachatAnnuelEffectif,
        economieFiscale: economieAnnuelle,
        coutNet: rachatAnnuelEffectif - economieAnnuelle,
      ));
    }

    return RachatEchelonneResult(
      economieBlocTotal: economieBlocTotal,
      economieEchelonneTotal: totalEconomieEchelonne,
      delta: totalEconomieEchelonne - economieBlocTotal,
      yearlyPlan: plan,
      disclaimer: 'Simulation pédagogique basée sur les barèmes cantonaux estimés. '
          'Le rachat LPP est soumis à acceptation par la caisse de pension. '
          'La déduction annuelle est plafonnée au revenu imposable. '
          'Blocage EPL de 3 ans après chaque rachat (LPP art. 79b al. 3). '
          'Consulte ta caisse de pension et un·e spécialiste '
          'en prévoyance avant toute décision.',
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// B. Libre Passage Advisor
// ─────────────────────────────────────────────────────────────────────────────

enum LibrePassageStatut {
  changementEmploi,
  departSuisse,
  cessationActivite,
}

enum ChecklistUrgency { critique, haute, moyenne }

class ChecklistItem {
  final String title;
  final String description;
  final ChecklistUrgency urgency;
  final bool isDone;

  const ChecklistItem({
    required this.title,
    required this.description,
    required this.urgency,
    this.isDone = false,
  });
}

class LibrePassageAlert {
  final String title;
  final String message;
  final ChecklistUrgency urgency;

  const LibrePassageAlert({
    required this.title,
    required this.message,
    required this.urgency,
  });
}

class LibrePassageResult {
  final List<ChecklistItem> checklist;
  final List<LibrePassageAlert> alerts;
  final List<String> recommendations;
  final String disclaimer;

  const LibrePassageResult({
    required this.checklist,
    required this.alerts,
    required this.recommendations,
    required this.disclaimer,
  });
}

class LibrePassageAdvisor {
  /// Analyse la situation de libre passage et retourne une checklist.
  ///
  /// [statut]              — type de depart
  /// [avoir]               — avoir de prevoyance (CHF)
  /// [age]                 — age de la personne
  /// [hasNewEmployer]      — a un nouvel employeur
  /// [daysSinceDeparture]  — jours depuis le depart (0 si pas encore parti)
  static LibrePassageResult analyze({
    required LibrePassageStatut statut,
    required double avoir,
    required int age,
    required bool hasNewEmployer,
    int daysSinceDeparture = 0,
  }) {
    final checklist = <ChecklistItem>[];
    final alerts = <LibrePassageAlert>[];
    final recommendations = <String>[];

    // Regles communes
    checklist.add(const ChecklistItem(
      title: 'Demander un décompte de sortie',
      description: 'Exige un décompte détaillé de ta caisse de pension '
          'avec la répartition obligatoire / surobligatoire.',
      urgency: ChecklistUrgency.haute,
    ));

    // Transfert dans les 30 jours
    if (statut == LibrePassageStatut.changementEmploi && hasNewEmployer) {
      checklist.add(const ChecklistItem(
        title: 'Transférer ton avoir dans les 30 jours',
        description:
            'L\'avoir doit être transféré à la nouvelle caisse de pension. '
            'Communiquez les coordonnées de la nouvelle caisse à l\'ancienne.',
        urgency: ChecklistUrgency.critique,
      ));

      if (daysSinceDeparture > 20) {
        alerts.add(const LibrePassageAlert(
          title: 'Délai de transfert bientôt échu',
          message:
              'Le transfert de ton avoir doit intervenir dans les 30 jours. '
              'Contacte ton ancienne caisse de pension rapidement.',
          urgency: ChecklistUrgency.critique,
        ));
      }

      recommendations.add(
        'Vérifiez que le règlement de la nouvelle caisse autorise les rachats '
        'et comparez les taux de conversion surobligatoires.',
      );
    }

    // Pas de nouvel employeur -> libre passage
    if (!hasNewEmployer) {
      checklist.add(const ChecklistItem(
        title: 'Ouvrir un compte de libre passage',
        description:
            'Sans nouvel employeur, ton avoir doit être placé sur un ou '
            'deux comptes de libre passage (max. 2 selon la loi).',
        urgency: ChecklistUrgency.critique,
      ));

      checklist.add(const ChecklistItem(
        title: 'Choisir entre compte bancaire et police de libre passage',
        description: 'Le compte bancaire offre plus de flexibilité. La police '
            'd\'assurance peut inclure une couverture risque.',
        urgency: ChecklistUrgency.haute,
      ));

      recommendations.add(
        'Comparez les taux d\'intérêt des fondations de libre passage '
        '(ex: Finpension, VIAC, Freizugigkeit.ch).',
      );
      recommendations.add(
        'Scinder ton avoir en 2 comptes permet d\'échelonner '
        'les retraits et de réduire la progressivité fiscale.',
      );
    }

    // Depart de Suisse
    if (statut == LibrePassageStatut.departSuisse) {
      checklist.add(const ChecklistItem(
        title: 'Vérifier les règles de retrait selon le pays de destination',
        description:
            'UE/AELE : seule la part surobligatoire peut être retirée en '
            'espèces. La part obligatoire reste en Suisse. '
            'Hors UE/AELE : retrait total possible.',
        urgency: ChecklistUrgency.critique,
      ));

      checklist.add(const ChecklistItem(
        title: 'Annoncer ton départ à la caisse de pension',
        description: 'Informe ta caisse dans les 30 jours suivant ton départ.',
        urgency: ChecklistUrgency.haute,
      ));

      if (daysSinceDeparture > 0 && daysSinceDeparture <= 180) {
        alerts.add(const LibrePassageAlert(
          title: 'Transfert à effectuer dans les 6 mois',
          message: 'Après un départ de Suisse, tu disposes de 6 mois pour '
              'transférer ton avoir ou ouvrir un compte de libre passage.',
          urgency: ChecklistUrgency.haute,
        ));
      }

      recommendations.add(
        'En cas de départ vers l\'UE, la part obligatoire reste en Suisse '
        'et peut être retirée à l\'âge de la retraite.',
      );
    }

    // Cessation d'activite
    if (statut == LibrePassageStatut.cessationActivite) {
      checklist.add(const ChecklistItem(
        title: 'Vérifier tes droits au chômage',
        description:
            'En cas de chômage, ta prévoyance professionnelle continue '
            'via la fondation institution supplétive (Fondation LPP).',
        urgency: ChecklistUrgency.haute,
      ));

      if (age >= 58) {
        recommendations.add(
          'À partir de 58 ans, tu peux demander le maintien de '
          'l\'assurance complète auprès de ton ancienne caisse de pension.',
        );
      }
    }

    // Avoirs oublies
    checklist.add(const ChecklistItem(
      title: 'Rechercher des avoirs oubliés',
      description: 'Utilisez la Centrale du 2e pilier (sfbvg.ch) pour '
          'rechercher d\'éventuels avoirs de libre passage oubliés.',
      urgency: ChecklistUrgency.moyenne,
    ));

    // Couverture risque
    checklist.add(const ChecklistItem(
      title: 'Vérifier la couverture risque transitoire',
      description: 'Pendant la période de libre passage, la couverture décès '
          'et invalidité peut être réduite. Vérifie tes contrats.',
      urgency: ChecklistUrgency.haute,
    ));

    return LibrePassageResult(
      checklist: checklist,
      alerts: alerts,
      recommendations: recommendations,
      disclaimer: 'Ces informations sont pédagogiques et ne constituent pas '
          'un conseil juridique ou financier personnalisé. Les règles '
          'dépendent de ta caisse de pension et de ta situation. '
          'Base légale : LFLP, OLP. Consultez un ou une spécialiste '
          'en prévoyance professionnelle.',
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// C. EPL Simulator (Encouragement a la Propriete du Logement)
// ─────────────────────────────────────────────────────────────────────────────

class EplResult {
  final double montantMaxRetirable;
  final double montantSouhaiteApplicable;
  final double impotEstime;
  final double reductionRenteInvalidite;
  final double reductionCapitalDeces;
  final List<String> alerts;
  final String disclaimer;

  const EplResult({
    required this.montantMaxRetirable,
    required this.montantSouhaiteApplicable,
    required this.impotEstime,
    required this.reductionRenteInvalidite,
    required this.reductionCapitalDeces,
    required this.alerts,
    required this.disclaimer,
  });
}

class EplSimulator {
  /// Simule un retrait EPL (art. 30c LPP).
  ///
  /// [avoirTotal]          — avoir LPP total (CHF)
  /// [avoirObligatoire]    — part obligatoire (CHF)
  /// [avoirSurobligatoire] — part surobligatoire (CHF)
  /// [age]                 — age de la personne
  /// [montantSouhaite]     — montant EPL souhaite (CHF)
  /// [aRachete]            — a effectue un rachat LPP recemment
  /// [anneesSDepuisRachat] — annees ecoulees depuis le dernier rachat
  static EplResult simulate({
    required double avoirTotal,
    required double avoirObligatoire,
    required double avoirSurobligatoire,
    required int age,
    required double montantSouhaite,
    required bool aRachete,
    int anneesSDepuisRachat = 0,
    String canton = 'ZH',
  }) {
    final alerts = <String>[];

    // --- Calcul du montant max retirable (LPP art. 30c) ---
    double montantMax;

    if (age < 50) {
      // Avant 50 ans : la totalite de l'avoir peut etre retiree
      montantMax = avoirTotal;
    } else {
      // Des 50 ans : le plus eleve entre (LPP art. 30e) :
      // a) l'avoir a 50 ans — sans info exacte, on estime via les
      //    bonifications cumulees (moindre part de l'avoir actuel)
      // b) la moitie de l'avoir actuel
      // L'estimation a) utilise un ratio base sur les annees restantes:
      // un assure ayant cotise de 25 a 50 ans (25 ans) vs 25 a age actuel.
      final anneesDepuis25 = max(1, age - 25);
      final annees25a50 = 25; // 25 ans de 25 a 50 ans
      final ratioA50 = (annees25a50 / anneesDepuis25).clamp(0.3, 1.0);
      final avoirEstimeA50 = avoirTotal * ratioA50;
      montantMax = max(avoirEstimeA50, avoirTotal / 2);
    }

    // Minimum 20'000 CHF (OPP2 art. 5)
    if (montantMax < 20000) {
      montantMax = 0;
      alerts.add(
        'Le montant minimum de retrait EPL est de CHF 20\'000. '
        'Ton avoir est insuffisant.',
      );
    }

    // Blocage 3 ans apres rachat (LPP art. 79b al. 3)
    if (aRachete && anneesSDepuisRachat < 3) {
      final anneesRestantes = 3 - anneesSDepuisRachat;
      montantMax = 0;
      alerts.add(
        'Blocage EPL : tu as effectué un rachat LPP il y a moins de '
        '3 ans. Le retrait EPL sera possible dans $anneesRestantes an(s) '
        '(LPP art. 79b al. 3).',
      );
    }

    // Montant applicable
    final applicable = min(montantSouhaite, montantMax).clamp(0.0, montantMax);

    // --- Estimation de l'impot sur le retrait EPL ---
    // Utilise les tranches progressives cantonales (LIFD art. 38)
    final impot = RetirementTaxCalculator.capitalWithdrawalTax(
      capitalBrut: applicable,
      canton: canton,
    );

    // --- Impact sur les prestations de risque ---
    // Estimation simplifiee : reduction proportionnelle
    final reductionRatio =
        avoirTotal > 0 ? (applicable / avoirTotal).clamp(0.0, 1.0) : 0.0;

    // Rente invalidite : ~60% du salaire assure, reduite proportionnellement
    final reductionInvalidite = reductionRatio * avoirTotal * 0.06;

    // Capital deces : souvent 1x salaire assure ou % de l'avoir
    final reductionDeces = reductionRatio * avoirTotal * 0.5;

    // Alertes supplementaires
    if (applicable > 0 && age >= 50) {
      alerts.add(
        'À partir de 50 ans, le montant retirable est limité. '
        'Vérifie le montant exact auprès de ta caisse de pension.',
      );
    }

    if (applicable > 0) {
      alerts.add(
        'Le retrait EPL réduit tes prestations de risque '
        '(invalidité et décès). Vérifie ta couverture résiduelle.',
      );
      alerts.add(
        'En cas de vente du bien immobilier, le montant retiré doit être '
        'remboursé à la caisse de pension (obligation de remboursement).',
      );
    }

    return EplResult(
      montantMaxRetirable: montantMax,
      montantSouhaiteApplicable: applicable,
      impotEstime: impot,
      reductionRenteInvalidite: reductionInvalidite,
      reductionCapitalDeces: reductionDeces,
      alerts: alerts,
      disclaimer:
          'Simulation pédagogique à titre indicatif. Le montant retirable '
          'exact dépend du règlement de ta caisse de pension et de '
          'ton avoir à 50 ans. L\'impôt varie selon le canton et '
          'la situation personnelle. Base légale : art. 30c LPP, '
          'OEPL. Consulte ta caisse de pension et un ou une '
          'spécialiste avant toute décision.',
    );
  }

}

/// Formate un montant en CHF avec separateur de milliers (apostrophe suisse).
String formatChf(double amount) {
  return amount.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]}\'',
      );
}
