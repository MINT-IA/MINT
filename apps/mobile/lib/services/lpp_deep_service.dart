import 'dart:math';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/financial_core/financial_core.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';
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
    int age = 50, // P1-1 audit 2026-04-18 : accepte age réel, impacte bonif LPP
    /// Salaire LPP-assuré — requis pour appliquer la règle OPP2 art. 60b
    /// aux expats arrivés < 5 ans en CH (plafond 20% du salaire assuré).
    /// Audit 2026-04-18 Q2 swiss-brain.
    double? salaireAssure,
    /// Nombre d'années de cotisation LPP en CH. Si < 5 et l'archetype
    /// est `expat*`, OPP2 art. 60b s'applique.
    int anneesCotisationCH = 100, // sentinel "pas expat récent" par défaut
    /// Archétype financier (`swiss_native`, `expat_eu`, `expat_non_eu`,
    /// `expat_us`, `returning_swiss`, `independent_with_lpp`,
    /// `independent_no_lpp`, `cross_border`).
    String archetype = 'swiss_native',
    // Legacy param kept for backwards compatibility, ignored if canton provided
    double tauxMarginalEstime = 0.30,
    S? l,
  }) {
    // Horizon jusqu'à 25 ans (audit 2026-04-18 P0-1 : rachats 350k+ demandent
    // un étalement long au rythme cashflow soutenable).
    final clampedHorizon = horizon.clamp(1, 25);
    // No arbitrary 500k cap — use actual rachat max from profile/slider
    final clampedRachat = rachatMax.clamp(0.0, double.infinity);
    final clampedAge = age.clamp(18, 70);

    // --- Impôt de base (sans rachat) ---
    // Use NetIncomeBreakdown to convert gross → net (replaces hardcoded * 0.87)
    final baseBreakdown = NetIncomeBreakdown.compute(
      grossSalary: revenuImposable,
      canton: canton,
      age: clampedAge,
    );
    final netMensuel = baseBreakdown.monthlyNetPayslip;
    final impotSansRachat = TaxEstimatorService.estimateAnnualTax(
      netMonthlyIncome: netMensuel,
      cantonCode: canton,
      civilStatus: civilStatus,
      childrenCount: 0,
      age: clampedAge,
    );

    // --- Bloc (1 an) ---
    // On ne peut déduire que min(rachat, revenu) en 1 an (LIFD art. 33).
    final blocDeductible = clampedRachat.clamp(0.0, revenuImposable);
    final blocBreakdown = NetIncomeBreakdown.compute(
      grossSalary: revenuImposable - blocDeductible,
      canton: canton,
      age: clampedAge,
    );
    final netMensuelApresBloc = blocBreakdown.monthlyNetPayslip;
    final impotApresBloc = TaxEstimatorService.estimateAnnualTax(
      netMonthlyIncome: netMensuelApresBloc,
      cantonCode: canton,
      civilStatus: civilStatus,
      childrenCount: 0,
      age: clampedAge,
    );
    final economieBlocTotal =
        (impotSansRachat - impotApresBloc).clamp(0.0, impotSansRachat);

    // --- Echelonne ---
    final rachatAnnuel = clampedRachat / clampedHorizon;
    // Trois plafonds cumulés (audit simulateur 2026-04-18) :
    //   (a) LIFD art. 33 al. 1 let. d — déduction plafonnée au revenu
    //       imposable (tax rule).
    //   (b) Réalité cashflow : un ménage suisse peut rarement absorber
    //       plus de 25% de son brut en rachat LPP une année donnée
    //       (littérature actuarielle + pratique fiduciaire). Pour
    //       350k de rachat max avec horizon=3, sans ce cap on
    //       calculait un rachat annuel de 116'667 CHF = 95% du brut,
    //       non faisable en trésorerie.
    //   (c) Plafond pratique absolu 50'000 CHF/an — au-delà, les
    //       progressifs fiscaux rendent l'étalement sur plus d'années
    //       plus efficace fiscalement ET plus réaliste en cashflow.
    const double cashflowRatioMax = 0.25;
    const double cashflowAbsoluteCap = 50000.0;
    final cashflowCap =
        min(revenuImposable * cashflowRatioMax, cashflowAbsoluteCap);

    // OPP2 art. 60b al. 1 (swiss-brain Q2 2026-04-18) : les personnes
    // arrivées de l'étranger sont plafonnées à 20% du salaire assuré LPP
    // par an durant les 5 premières années de contribution en CH. Au-delà,
    // le plafond légal disparaît (seul reste la contrainte LIFD art. 33
    // ≤ revenu imposable).
    // Accepte les deux conventions (enum .name camelCase "expatEu" et
    // schéma doctrine snake_case "expat_eu") pour tolérer les callers.
    final a = archetype.toLowerCase().replaceAll('_', '');
    final isExpatArchetype =
        a == 'expateu' || a == 'expatnoneu' || a == 'expatus';
    final isExpatRecent = anneesCotisationCH < 5 && isExpatArchetype;
    final opp2LegalCap = (isExpatRecent && salaireAssure != null && salaireAssure > 0)
        ? salaireAssure * 0.20
        : double.infinity;

    final rachatAnnuelEffectif = rachatAnnuel
        .clamp(0.0, min(min(revenuImposable, cashflowCap), opp2LegalCap))
        .toDouble();
    final List<RachatYearPlan> plan = [];
    double totalEconomieEchelonne = 0;

    final echelonBreakdown = NetIncomeBreakdown.compute(
      grossSalary: revenuImposable - rachatAnnuelEffectif,
      canton: canton,
      age: clampedAge,
    );
    final netMensuelApresEchelon = echelonBreakdown.monthlyNetPayslip;
    final impotApresEchelon = TaxEstimatorService.estimateAnnualTax(
      netMonthlyIncome: netMensuelApresEchelon,
      cantonCode: canton,
      civilStatus: civilStatus,
      childrenCount: 0,
      age: clampedAge,
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

    // Check si le total effectif couvre le rachat max — sinon signaler à l'user
    // que l'horizon choisi est trop court pour absorber tout le rachat au rythme
    // réaliste (cashflow 20% brut, cap absolu 50k/an).
    final totalEffectifRachat = rachatAnnuelEffectif * clampedHorizon;
    final rachatNonAbsorbe = clampedRachat - totalEffectifRachat;
    String cashflowNote = '';
    if (rachatNonAbsorbe > 1000 && rachatAnnuel > cashflowCap) {
      final horizonNecessaire = (clampedRachat / rachatAnnuelEffectif).ceil();
      cashflowNote = 'Au rythme réaliste de '
          '${rachatAnnuelEffectif.round()}\u00a0CHF/an, ton rachat '
          'max demanderait $horizonNecessaire\u00a0années — '
          'l\'horizon actuel ($clampedHorizon\u00a0ans) ne couvre qu\'une partie '
          '(${totalEffectifRachat.round()}\u00a0CHF sur ${clampedRachat.round()}). ';
    }

    return RachatEchelonneResult(
      economieBlocTotal: economieBlocTotal,
      economieEchelonneTotal: totalEconomieEchelonne,
      delta: totalEconomieEchelonne - economieBlocTotal,
      yearlyPlan: plan,
      disclaimer: cashflowNote + (l?.lppRachatDisclaimerEchelonne ??
          'Simulation pédagogique basée sur les barèmes cantonaux estimés. '
          'Le rachat LPP est soumis à acceptation par la caisse de pension. '
          'La déduction annuelle est plafonnée au revenu imposable (LIFD art.\u00a033) '
          'et cappée à 20% du brut ou 50\'000\u00a0CHF/an pour rester réaliste en trésorerie. '
          'Blocage EPL de 3 ans après chaque rachat (LPP art.\u00a079b al.\u00a03). '
          'Consulte ta caisse de pension et un·e spécialiste '
          'en prévoyance avant toute décision.'),
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
    S? l,
  }) {
    final checklist = <ChecklistItem>[];
    final alerts = <LibrePassageAlert>[];
    final recommendations = <String>[];

    // Regles communes
    checklist.add(ChecklistItem(
      title: l?.lppChecklistTitleDecompte ?? 'Demander un décompte de sortie',
      description: l?.lppChecklistDescDecompte ??
          'Exige un décompte détaillé de ta caisse de pension '
          'avec la répartition obligatoire / surobligatoire.',
      urgency: ChecklistUrgency.haute,
    ));

    // Transfert dans les 30 jours
    if (statut == LibrePassageStatut.changementEmploi && hasNewEmployer) {
      checklist.add(ChecklistItem(
        title: l?.lppChecklistTitleTransfert30j ?? 'Transférer ton avoir dans les 30 jours',
        description: l?.lppChecklistDescTransfert30j ??
            'L\'avoir doit être transféré à la nouvelle caisse de pension. '
            'Communiquez les coordonnées de la nouvelle caisse à l\'ancienne.',
        urgency: ChecklistUrgency.critique,
      ));

      if (daysSinceDeparture > 20) {
        alerts.add(LibrePassageAlert(
          title: l?.lppChecklistAlertTransfertTitle ?? 'Délai de transfert bientôt échu',
          message: l?.lppChecklistAlertTransfertMsg ??
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
      checklist.add(ChecklistItem(
        title: l?.lppChecklistTitleOuvrirLP ?? 'Ouvrir un compte de libre passage',
        description: l?.lppChecklistDescOuvrirLP ??
            'Sans nouvel employeur, ton avoir doit être placé sur un ou '
            'deux comptes de libre passage (max. 2 selon la loi).',
        urgency: ChecklistUrgency.critique,
      ));

      checklist.add(ChecklistItem(
        title: l?.lppChecklistTitleChoisirLP ?? 'Choisir entre compte bancaire et police de libre passage',
        description: l?.lppChecklistDescChoisirLP ??
            'Le compte bancaire offre plus de flexibilité. La police '
            'd\'assurance peut inclure une couverture risque.',
        urgency: ChecklistUrgency.haute,
      ));

      recommendations.add(
        'Comparez les taux d\'intérêt des fondations de libre passage '
        '(auprès d\'un prestataire de libre passage).',
      );
      recommendations.add(
        'Scinder ton avoir en 2 comptes permet d\'échelonner '
        'les retraits et de réduire la progressivité fiscale.',
      );
    }

    // Depart de Suisse
    if (statut == LibrePassageStatut.departSuisse) {
      checklist.add(ChecklistItem(
        title: l?.lppChecklistTitleVerifierDestination ?? 'Vérifier les règles de retrait selon le pays de destination',
        description: l?.lppChecklistDescVerifierDestination ??
            'UE/AELE : seule la part surobligatoire peut être retirée en '
            'espèces. La part obligatoire reste en Suisse. '
            'Hors UE/AELE : retrait total possible.',
        urgency: ChecklistUrgency.critique,
      ));

      checklist.add(ChecklistItem(
        title: l?.lppChecklistTitleAnnoncerDepart ?? 'Annoncer ton départ à la caisse de pension',
        description: l?.lppChecklistDescAnnoncerDepart ??
            'Informe ta caisse dans les 30 jours suivant ton départ.',
        urgency: ChecklistUrgency.haute,
      ));

      if (daysSinceDeparture > 0 && daysSinceDeparture <= 180) {
        alerts.add(LibrePassageAlert(
          title: l?.lppChecklistAlertTransfert6mTitle ?? 'Transfert à effectuer dans les 6 mois',
          message: l?.lppChecklistAlertTransfert6mMsg ??
              'Après un départ de Suisse, tu disposes de 6 mois pour '
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
      checklist.add(ChecklistItem(
        title: l?.lppChecklistTitleChomage ?? 'Vérifier tes droits au chômage',
        description: l?.lppChecklistDescChomage ??
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
    checklist.add(ChecklistItem(
      title: l?.lppChecklistTitleAvoirs ?? 'Rechercher des avoirs oubliés',
      description: l?.lppChecklistDescAvoirs ??
          'Utilisez la Centrale du 2e pilier (sfbvg.ch) pour '
          'rechercher d\'éventuels avoirs de libre passage oubliés.',
      urgency: ChecklistUrgency.moyenne,
    ));

    // Couverture risque
    checklist.add(ChecklistItem(
      title: l?.lppChecklistTitleCouverture ?? 'Vérifier la couverture risque transitoire',
      description: l?.lppChecklistDescCouverture ??
          'Pendant la période de libre passage, la couverture décès '
          'et invalidité peut être réduite. Vérifie tes contrats.',
      urgency: ChecklistUrgency.haute,
    ));

    return LibrePassageResult(
      checklist: checklist,
      alerts: alerts,
      recommendations: recommendations,
      disclaimer: l?.lppLibrePassageDisclaimer ??
          'Ces informations sont pédagogiques et ne constituent pas '
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
  /// Réduction estimée de la rente invalidité suite au retrait EPL.
  /// `null` quand MINT n'a pas de certificat de caisse (le calcul exact
  /// dépend du règlement caisse — cf. audit P1-2 2026-04-18). La UI
  /// affiche alors "à demander à ta caisse" plutôt qu'un chiffre magique.
  final double? reductionRenteInvalidite;
  /// Réduction estimée du capital décès. Même sémantique null que ci-dessus.
  final double? reductionCapitalDeces;
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
    S? l,
  }) {
    final alerts = <String>[];

    // --- Calcul du montant max retirable (LPP art. 30c) ---
    double montantMax;

    if (age < 50) {
      // Avant 50 ans : la totalite de l'avoir peut etre retiree
      montantMax = avoirTotal;
    } else {
      // Dès 50 ans (LPP art. 30e al. 2) : max retirable = le plus élevé
      // entre (a) l'avoir à 50 ans et (b) la moitié de l'avoir actuel.
      //
      // (a) exigerait le certificat de la caisse (avoir_vieillesse à 50 ans)
      //     — MINT ne le connaît qu'après scan d'un certificat récent, pas
      //     inférable fiablement par ratio linéaire (audit P0-3 2026-04-18
      //     a retiré la formule inventée `25/(age-25)`).
      // Fallback honnête : utiliser la demi-part (b), toujours valide, et
      //     avertir l'utilisateur que son plafond réel peut être plus élevé
      //     s'il consulte son certificat.
      montantMax = avoirTotal / 2;
      alerts.add(
        'Estimation conservatrice basée sur la demi-part (LPP art.\u00a030e al.\u00a02). '
        'Ton plafond réel peut être plus élevé si ton avoir à 50\u00a0ans '
        'l\'est — consulte ton certificat de prévoyance pour le montant exact.',
      );
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
      // P1-3 audit 2026-04-18 : communique la date concrète de déblocage.
      final unlockDate = DateTime.now().add(Duration(days: anneesRestantes * 365));
      final unlockStr = '${unlockDate.day.toString().padLeft(2, '0')}.'
          '${unlockDate.month.toString().padLeft(2, '0')}.'
          '${unlockDate.year}';
      alerts.add(
        'Blocage EPL : tu as effectué un rachat LPP il y a moins de '
        '3 ans. Retrait EPL possible dès le\u00a0$unlockStr '
        '(environ $anneesRestantes an${anneesRestantes > 1 ? 's' : ''}, LPP art.\u00a079b al.\u00a03).',
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
    // Audit P1-2 2026-04-18 : ancien calcul `reductionRatio × avoirTotal × 0.06`
    // pour l'invalidité et `× 0.5` pour le décès étaient des pseudo-formules
    // sans base légale. La vraie réduction dépend du règlement de la caisse
    // (LPP art. 24 al. 2 : rente invalidité = avoir_vieillesse_projeté ×
    // taux_conversion × salaire_assuré/référence), que MINT ne connaît pas
    // sans le certificat. On expose l'impact QUALITATIVEMENT : un retrait
    // EPL réduit l'avoir de vieillesse, donc les prestations risque et
    // décès sont mécaniquement réduites — le montant exact vient du
    // règlement de la caisse, pas d'une formule magique.
    final reductionRatio =
        avoirTotal > 0 ? (applicable / avoirTotal).clamp(0.0, 1.0) : 0.0;
    // `null` = "à demander à la caisse" ; la UI rend un message qualitatif
    // à la place d'un chiffre (pas de sentinel -1, cf. feedback_no_shortcuts_ever).
    const double? reductionInvalidite = null;
    const double? reductionDeces = null;
    if (applicable > 0 && reductionRatio > 0) {
      alerts.add(
        'Le retrait EPL réduit ton avoir de vieillesse et donc tes '
        'prestations en cas d\'invalidité et de décès. Le montant exact '
        'dépend du règlement de ta caisse — demande-le avant de signer.',
      );
    }

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
      disclaimer: l?.lppEplDisclaimer ??
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
