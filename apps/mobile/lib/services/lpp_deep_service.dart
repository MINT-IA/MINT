import 'dart:math';

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
  /// [avoirActuel]         — avoir actuel LPP (CHF)
  /// [rachatMax]           — montant total du rachat possible (CHF)
  /// [revenuImposable]     — revenu imposable annuel (CHF)
  /// [tauxMarginalEstime]  — taux marginal estime (0.25 – 0.45)
  /// [horizon]             — nombre d'annees d'echelonnement (1 – 15)
  ///
  /// Regle : Pas d'EPL dans les 3 ans suivant un rachat (LPP art. 79b al. 3).
  static RachatEchelonneResult compare({
    required double avoirActuel,
    required double rachatMax,
    required double revenuImposable,
    required double tauxMarginalEstime,
    required int horizon,
  }) {
    // Clamp inputs
    final clampedTaux = tauxMarginalEstime.clamp(0.10, 0.50);
    final clampedHorizon = horizon.clamp(1, 15);
    final clampedRachat = rachatMax.clamp(0.0, 500000.0);

    // --- Bloc (1 an) ---
    final economieBlocTotal = _estimateTaxSaving(
      revenuImposable,
      clampedRachat,
      clampedTaux,
    );

    // --- Echelonne ---
    final rachatAnnuel = clampedRachat / clampedHorizon;
    final List<RachatYearPlan> plan = [];
    double totalEconomieEchelonne = 0;

    for (int i = 0; i < clampedHorizon; i++) {
      final eco = _estimateTaxSaving(
        revenuImposable,
        rachatAnnuel,
        clampedTaux,
      );
      totalEconomieEchelonne += eco;
      plan.add(RachatYearPlan(
        annee: i + 1,
        montantRachat: rachatAnnuel,
        economieFiscale: eco,
        coutNet: rachatAnnuel - eco,
      ));
    }

    return RachatEchelonneResult(
      economieBlocTotal: economieBlocTotal,
      economieEchelonneTotal: totalEconomieEchelonne,
      delta: totalEconomieEchelonne - economieBlocTotal,
      yearlyPlan: plan,
      disclaimer:
          'Simulation pedagogique basee sur une progressivite estimee. '
          'Le rachat LPP est soumis a acceptation par la caisse de pension. '
          'Blocage EPL de 3 ans apres chaque rachat (LPP art. 79b al. 3). '
          'Consulte ta caisse de pension et un ou une specialiste '
          'en prevoyance avant toute decision.',
    );
  }

  /// Estimation de l'economie fiscale via un modele progressif simplifie.
  ///
  /// Le taux marginal effectif diminue a mesure que la deduction augmente,
  /// car les tranches inferieures sont taxees a un taux plus bas.
  static double _estimateTaxSaving(
    double income,
    double deduction,
    double marginalRate,
  ) {
    if (deduction <= 0 || income <= 0) return 0.0;

    // Modele simplifie : taux marginal decroit lineairement
    // sur la tranche deduite
    const steps = 10;
    final stepSize = deduction / steps;
    var currentIncome = income;
    var totalSaved = 0.0;

    for (var i = 0; i < steps; i++) {
      // Le taux a ce niveau de revenu
      final ratio = (currentIncome / income).clamp(0.0, 1.0);
      final rate = marginalRate * (0.7 + 0.3 * ratio);
      totalSaved += stepSize * rate;
      currentIncome -= stepSize;
    }

    return totalSaved;
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
      title: 'Demander un decompte de sortie',
      description:
          'Exige un decompte detaille de ta caisse de pension '
          'avec la repartition obligatoire / surobligatoire.',
      urgency: ChecklistUrgency.haute,
    ));

    // Transfert dans les 30 jours
    if (statut == LibrePassageStatut.changementEmploi && hasNewEmployer) {
      checklist.add(const ChecklistItem(
        title: 'Transferer ton avoir dans les 30 jours',
        description:
            'L\'avoir doit etre transfere a la nouvelle caisse de pension. '
            'Communiquez les coordonnees de la nouvelle caisse a l\'ancienne.',
        urgency: ChecklistUrgency.critique,
      ));

      if (daysSinceDeparture > 20) {
        alerts.add(const LibrePassageAlert(
          title: 'Delai de transfert bientot echu',
          message:
              'Le transfert de ton avoir doit intervenir dans les 30 jours. '
              'Contacte ton ancienne caisse de pension rapidement.',
          urgency: ChecklistUrgency.critique,
        ));
      }

      recommendations.add(
        'Verifiez que le reglement de la nouvelle caisse autorise les rachats '
        'et comparez les taux de conversion surobligatoires.',
      );
    }

    // Pas de nouvel employeur -> libre passage
    if (!hasNewEmployer) {
      checklist.add(const ChecklistItem(
        title: 'Ouvrir un compte de libre passage',
        description:
            'Sans nouvel employeur, ton avoir doit etre place sur un ou '
            'deux comptes de libre passage (max. 2 selon la loi).',
        urgency: ChecklistUrgency.critique,
      ));

      checklist.add(const ChecklistItem(
        title: 'Choisir entre compte bancaire et police de libre passage',
        description:
            'Le compte bancaire offre plus de flexibilite. La police '
            'd\'assurance peut inclure une couverture risque.',
        urgency: ChecklistUrgency.haute,
      ));

      recommendations.add(
        'Comparez les taux d\'interet des fondations de libre passage '
        '(ex: Finpension, VIAC, Freizugigkeit.ch).',
      );
      recommendations.add(
        'Scinder ton avoir en 2 comptes permet d\'echelonner '
        'les retraits et de reduire la progressivite fiscale.',
      );
    }

    // Depart de Suisse
    if (statut == LibrePassageStatut.departSuisse) {
      checklist.add(const ChecklistItem(
        title: 'Verifier les regles de retrait selon le pays de destination',
        description:
            'UE/AELE : seule la part surobligatoire peut etre retiree en '
            'especes. La part obligatoire reste en Suisse. '
            'Hors UE/AELE : retrait total possible.',
        urgency: ChecklistUrgency.critique,
      ));

      checklist.add(const ChecklistItem(
        title: 'Annoncer ton depart a la caisse de pension',
        description:
            'Informe ta caisse dans les 30 jours suivant ton depart.',
        urgency: ChecklistUrgency.haute,
      ));

      if (daysSinceDeparture > 0 && daysSinceDeparture <= 180) {
        alerts.add(const LibrePassageAlert(
          title: 'Transfert a effectuer dans les 6 mois',
          message:
              'Apres un depart de Suisse, tu disposes de 6 mois pour '
              'transferer ton avoir ou ouvrir un compte de libre passage.',
          urgency: ChecklistUrgency.haute,
        ));
      }

      recommendations.add(
        'En cas de depart vers l\'UE, la part obligatoire reste en Suisse '
        'et peut etre retiree a l\'age de la retraite.',
      );
    }

    // Cessation d'activite
    if (statut == LibrePassageStatut.cessationActivite) {
      checklist.add(const ChecklistItem(
        title: 'Verifier tes droits au chomage',
        description:
            'En cas de chomage, ta prevoyance professionnelle continue '
            'via la fondation institution suppletive (Fondation LPP).',
        urgency: ChecklistUrgency.haute,
      ));

      if (age >= 58) {
        recommendations.add(
          'A partir de 58 ans, tu peux demander le maintien de '
          'l\'assurance complete aupres de ton ancienne caisse de pension.',
        );
      }
    }

    // Avoirs oublies
    checklist.add(const ChecklistItem(
      title: 'Rechercher des avoirs oublies',
      description:
          'Utilisez la Centrale du 2e pilier (sfbvg.ch) pour '
          'rechercher d\'eventuels avoirs de libre passage oublies.',
      urgency: ChecklistUrgency.moyenne,
    ));

    // Couverture risque
    checklist.add(const ChecklistItem(
      title: 'Verifier la couverture risque transitoire',
      description:
          'Pendant la periode de libre passage, la couverture deces '
          'et invalidite peut etre reduite. Verifie tes contrats.',
      urgency: ChecklistUrgency.haute,
    ));

    return LibrePassageResult(
      checklist: checklist,
      alerts: alerts,
      recommendations: recommendations,
      disclaimer:
          'Ces informations sont pedagogiques et ne constituent pas '
          'un conseil juridique ou financier personnalise. Les regles '
          'dependent de ta caisse de pension et de ta situation. '
          'Base legale : LFLP, OLP. Consultez un ou une specialiste '
          'en prevoyance professionnelle.',
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
  }) {
    final alerts = <String>[];

    // --- Calcul du montant max retirable ---
    double montantMax;

    if (age < 50) {
      // Avant 50 ans : la totalite de l'avoir peut etre retiree
      montantMax = avoirTotal;
    } else {
      // Des 50 ans : le plus eleve entre :
      // a) l'avoir a 50 ans (simplifie ici a 50% de l'avoir actuel)
      // b) la moitie de l'avoir actuel
      final avoirA50 = avoirTotal * 0.5; // Estimation simplifiee
      montantMax = max(avoirA50, avoirTotal / 2);
    }

    // Minimum 20'000 CHF
    if (montantMax < 20000) {
      montantMax = 0;
      alerts.add(
        'Le montant minimum de retrait EPL est de CHF 20\'000. '
        'Ton avoir est insuffisant.',
      );
    }

    // Blocage 3 ans apres rachat
    if (aRachete && anneesSDepuisRachat < 3) {
      final anneesRestantes = 3 - anneesSDepuisRachat;
      montantMax = 0;
      alerts.add(
        'Blocage EPL : tu as effectue un rachat LPP il y a moins de '
        '3 ans. Le retrait EPL sera possible dans $anneesRestantes an(s) '
        '(LPP art. 79b al. 3).',
      );
    }

    // Montant applicable
    final applicable = min(montantSouhaite, montantMax).clamp(0.0, montantMax);

    // --- Estimation de l'impot sur le retrait EPL ---
    // Taux reduit (environ 1/5 du bareme ordinaire, entre 3% et 10%)
    double tauxImposition;
    if (applicable < 50000) {
      tauxImposition = 0.03;
    } else if (applicable < 100000) {
      tauxImposition = 0.05;
    } else if (applicable < 250000) {
      tauxImposition = 0.07;
    } else {
      tauxImposition = 0.09;
    }
    final impot = applicable * tauxImposition;

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
        'A partir de 50 ans, le montant retirable est limite. '
        'Verifie le montant exact aupres de ta caisse de pension.',
      );
    }

    if (applicable > 0) {
      alerts.add(
        'Le retrait EPL reduit tes prestations de risque '
        '(invalidite et deces). Verifie ta couverture residuelle.',
      );
      alerts.add(
        'En cas de vente du bien immobilier, le montant retire doit etre '
        'rembourse a la caisse de pension (obligation de remboursement).',
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
          'Simulation pedagogique a titre indicatif. Le montant retirable '
          'exact depend du reglement de ta caisse de pension et de '
          'ton avoir a 50 ans. L\'impot varie selon le canton et '
          'la situation personnelle. Base legale : art. 30c LPP, '
          'OEPL. Consulte ta caisse de pension et un ou une '
          'specialiste avant toute decision.',
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
