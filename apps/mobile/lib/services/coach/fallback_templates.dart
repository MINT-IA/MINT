/// Fallback Templates — Sprint S35 (Coach Narrative).
///
/// Enhanced templates that use [CoachContext] for personalization
/// WITHOUT requiring an LLM call. These serve as the minimum quality
/// bar: if the LLM is unavailable or fails compliance, these are used.
///
/// All text in French (informal "tu"). No banned terms.
/// References: LSFin, LAVS, LPP, OPP3, LIFD.
library;

import 'coach_models.dart';

class FallbackTemplates {
  FallbackTemplates._();

  // ═══════════════════════════════════════════════════════════════
  // Greeting — max 30 words (ComponentType.greeting)
  // ═══════════════════════════════════════════════════════════════

  /// Generates a personalized greeting based on context signals:
  /// - Days since last visit
  /// - Fiscal season
  /// - FRI score delta
  static String greeting(CoachContext ctx) {
    final hasName = ctx.firstName.isNotEmpty;
    final salut = hasName ? 'Salut ${ctx.firstName}.' : 'Bonjour.';

    // Same-day return
    if (ctx.daysSinceLastVisit == 0) {
      return hasName ? 'Bon retour, ${ctx.firstName}.' : 'Bon retour.';
    }

    // Recent visit (< 7 days)
    if (ctx.daysSinceLastVisit < 7) {
      return hasName ? 'Content de te revoir, ${ctx.firstName}.' : 'Content de te revoir.';
    }

    // Fiscal season: 3a deadline (Oct-Dec)
    if (ctx.fiscalSeason == '3a_deadline') {
      return hasName
          ? '${ctx.firstName}, pense à ton 3a avant la fin de l\'année.'
          : 'Pense à ton 3a avant la fin de l\'année.';
    }

    // Fiscal season: tax declaration (Feb-Mar)
    if (ctx.fiscalSeason == 'tax_declaration') {
      return hasName
          ? '${ctx.firstName}, c\'est la saison de la déclaration fiscale.'
          : 'C\'est la saison de la déclaration fiscale.';
    }

    // Positive delta since last visit
    if (ctx.friDelta > 0) {
      return '$salut +${ctx.friDelta.toStringAsFixed(0)} points depuis ta dernière visite.';
    }

    // Negative delta
    if (ctx.friDelta < 0) {
      return '$salut Ton score a bougé de ${ctx.friDelta.toStringAsFixed(0)} points.';
    }

    // Default: show current score
    return '$salut Ton score de solidité : ${ctx.friTotal.toStringAsFixed(0)}/100.';
  }

  // ═══════════════════════════════════════════════════════════════
  // Score Summary — max 80 words (ComponentType.scoreSummary)
  // ═══════════════════════════════════════════════════════════════

  /// Generates a score summary with trend indication.
  static String scoreSummary(CoachContext ctx) {
    final trend = ctx.friDelta > 0
        ? 'En progression de ${ctx.friDelta.toStringAsFixed(0)} points.'
        : ctx.friDelta < 0
            ? 'En recul de ${ctx.friDelta.abs().toStringAsFixed(0)} points.'
            : 'Stable.';
    return 'Solidité financière : ${ctx.friTotal.toStringAsFixed(0)}/100. $trend';
  }

  // ═══════════════════════════════════════════════════════════════
  // Tip Narrative — max 120 words (ComponentType.tip)
  // ═══════════════════════════════════════════════════════════════

  /// Generates a personalized educational tip based on the user's
  /// most impactful financial lever.
  static String tipNarrative(CoachContext ctx) {
    final taxSaving = ctx.knownValues['tax_saving'] ?? 0;
    final liquidity = ctx.knownValues['months_liquidity'] ?? 6;
    final replacement = ctx.knownValues['replacement_ratio'] ?? 60;

    // Tax optimization lever (> CHF 1000 potential)
    if (taxSaving > 1000) {
      return '${ctx.firstName}, un versement 3a pourrait réduire ton impôt '
          'd\'environ CHF ${taxSaving.toStringAsFixed(0)} cette année. '
          'Simule l\'impact sur ton profil.';
    }

    // Liquidity alert (< 3 months of reserves)
    if (liquidity < 3) {
      return 'Ta réserve de liquidité couvre environ '
          '${liquidity.toStringAsFixed(1)} mois. '
          'Un objectif de 3 à 6 mois est souvent considéré comme une base solide.';
    }

    // Retirement gap (replacement ratio < 55%)
    if (replacement < 55) {
      return 'Ton taux de remplacement estimé à la retraite est de '
          '${replacement.toStringAsFixed(0)}%. '
          'Explore les options pour combler l\'écart dans le simulateur.';
    }

    // Default: encourage profile completion with specific enrichment action
    final enrichment = _topEnrichmentAction(ctx);
    if (enrichment != null) {
      return 'Ton score de solidité est de '
          '${ctx.friTotal.toStringAsFixed(0)}/100. $enrichment';
    }
    return 'Ton score de solidité est de '
        '${ctx.friTotal.toStringAsFixed(0)}/100. '
        'Continue à affiner ton profil pour des estimations plus précises.';
  }

  // ═══════════════════════════════════════════════════════════════
  // Chiffre Choc Reframe — max 100 words (ComponentType.chiffreChoc)
  // ═══════════════════════════════════════════════════════════════

  /// Contextualizes a shock figure with confidence level and
  /// encourages profile enrichment based on data reliability.
  static String chiffreChocReframe(CoachContext ctx) {
    final confidence = ctx.knownValues['confidence_score'] ?? 30;
    final hasCertifiedData = ctx.dataReliability.values
        .any((v) => v == 'certified');

    if (hasCertifiedData) {
      return 'Ce chiffre s\'appuie sur des données certifiées '
          '(confiance : ${confidence.toStringAsFixed(0)}%). '
          'Continue à enrichir ton profil pour affiner l\'estimation.';
    }
    final enrichment = _topEnrichmentAction(ctx);
    return 'Ce chiffre est basé sur '
        '${confidence.toStringAsFixed(0)}% de données concrètes. '
        '${enrichment ?? 'Plus tu précises ton profil, plus l\'estimation s\'affine.'}';
  }

  // ═══════════════════════════════════════════════════════════════
  // Enrichment Guide — max 150 words (ComponentType.enrichmentGuide)
  // ═══════════════════════════════════════════════════════════════

  /// Generates a conversational enrichment prompt for a data block.
  /// Used in DataBlockEnrichmentScreen "coach mode".
  static String enrichmentGuide(CoachContext ctx, String blockType) {
    final name = ctx.firstName;
    return switch (blockType) {
      'lpp' =>
        '$name, connais-tu ton avoir LPP actuel? '
        'Ton certificat de prevoyance (2e pilier) indique le montant exact. '
        'Avec ton salaire et ton age, l\'estimation pourrait varier '
        'significativement du reel. Un scan du certificat affinerait '
        'tes projections de +18 points de confiance.',
      'avs' =>
        '$name, as-tu deja demande ton extrait de compte AVS? '
        'Il confirme tes annees de cotisation effectives. '
        '${ctx.archetype.contains('expat') ? 'En tant qu\'expatrie, des lacunes sont probables. ' : ''}'
        'Commander un extrait est gratuit sur le site de ta caisse de compensation.',
      '3a' =>
        '$name, combien de comptes 3a as-tu et chez quel provider? '
        'Connaitre les soldes exacts permet de calculer ton avantage fiscal '
        'et de projeter ta prevoyance complete.',
      'patrimoine' =>
        '$name, as-tu de l\'epargne en dehors de la prevoyance? '
        'Comptes courants, investissements, immobilier — ces donnees '
        'completent ton Financial Resilience Index.',
      'fiscalite' =>
        '$name, dans quelle commune habites-tu? '
        'Le coefficient communal varie de 60% a 130% et impacte '
        'directement ton taux d\'imposition reel. '
        'Une declaration fiscale ou un avis de taxation donnerait un calcul precis.',
      'objectifRetraite' =>
        '$name, a quel age souhaiterais-tu arreter de travailler? '
        'Entre 58 et 70 ans, chaque annee change la donne : '
        'rente reduite avant 65 ans, majoree apres.',
      'compositionMenage' =>
        '$name, es-tu en couple? '
        'Si oui, les projections changent significativement : '
        'AVS plafonnee pour les maries, rente de survivant LPP, '
        'et possibilites d\'optimisation fiscale a deux.',
      _ =>
        '$name, continue a enrichir ton profil. '
        'Chaque donnee ajoutee ameliore la precision de tes projections.',
    };
  }

  // ═══════════════════════════════════════════════════════════════
  // FATCA Guidance — max 120 words (ComponentType.tip)
  // ═══════════════════════════════════════════════════════════════

  /// Generates educational content about FATCA obligations for US
  /// citizens/residents in Switzerland. Falls back to a generic
  /// nationality-awareness message for non-US archetypes.
  static String fatcaGuidance(CoachContext ctx) {
    if (ctx.archetype != 'expat_us') {
      return '${ctx.firstName}, certaines règles de prévoyance '
          'dépendent de ta nationalité et de ton parcours. '
          'Vérifie les conventions bilatérales qui pourraient '
          's\'appliquer à ta situation auprès d\'un·e spécialiste.';
    }

    return '${ctx.firstName}, en tant que contribuable US en Suisse, '
        'quelques points éducatifs à connaître. '
        'Le FATCA (Foreign Account Tax Compliance Act) impose '
        'une déclaration annuelle de tes comptes suisses à l\'IRS. '
        'Tes investissements en fonds suisses pourraient être '
        'classés PFIC, avec un traitement fiscal US spécifique. '
        'La convention de double imposition CH-US prévoit des '
        'mécanismes pour éviter une double taxation sur tes '
        'versements 3a et prestations LPP. '
        'Il serait utile de consulter un·e spécialiste '
        'en fiscalité transfrontalière CH-US. '
        'Réf. : Convention de double imposition CH-US, FATCA.';
  }

  // ═══════════════════════════════════════════════════════════════
  // Succession Planning — max 120 words (ComponentType.tip)
  // ═══════════════════════════════════════════════════════════════

  /// Generates educational content about Swiss succession law,
  /// pillar beneficiary rules, and cantonal tax implications.
  static String successionPlanning(CoachContext ctx) {
    final cantonNote = ctx.canton.isNotEmpty
        ? 'Dans le canton de ${ctx.canton}, les droits de succession '
            'varient selon le lien de parenté. '
        : '';

    return '${ctx.firstName}, le droit successoral suisse '
        '(CC art. 457 ss.) prévoit des réserves héréditaires '
        'pour le conjoint et les descendants. '
        'La quotité disponible dépend de ta situation familiale '
        'et de ton régime matrimonial (participation aux acquêts '
        'ou séparation de biens). '
        '$cantonNote'
        'En prévoyance, ton 2e pilier (LPP art. 20a) désigne '
        'un ordre de bénéficiaires : conjoint·e, puis enfants, '
        'puis parents. Le 3a suit un ordre similaire. '
        'Il serait utile d\'envisager une vérification '
        'de tes clauses bénéficiaires. '
        'Réf. : CC art. 457 ss., LPP art. 20a.';
  }

  // ═══════════════════════════════════════════════════════════════
  // Libre Passage Guide — max 120 words (ComponentType.tip)
  // ═══════════════════════════════════════════════════════════════

  /// Generates educational content about libre passage accounts
  /// after job change or unemployment.
  static String librePassageGuide(CoachContext ctx) {
    return '${ctx.firstName}, lors d\'un changement d\'emploi '
        'ou d\'une période sans activité, ton avoir LPP est '
        'transféré sur un compte de libre passage (LFLP art. 4). '
        'Tu peux choisir entre une fondation de libre passage '
        '(capital garanti) ou un compte bancaire avec options '
        'de placement. '
        'Un retrait anticipé (EPL) pourrait être possible pour '
        'l\'achat d\'un logement, le passage à l\'indépendance '
        'ou le départ définitif de Suisse (LPP art. 30c-30f). '
        'Attention : après un EPL, un rachat LPP n\'est possible '
        'qu\'une fois le retrait remboursé (blocage 3 ans). '
        'Réf. : LFLP art. 4, OLP art. 10, LPP art. 30c-30f.';
  }

  // ═══════════════════════════════════════════════════════════════
  // Disability Bridge — max 120 words (ComponentType.tip)
  // ═══════════════════════════════════════════════════════════════

  /// Generates educational content about disability insurance (AI),
  /// LPP disability benefits, and prevoyance gaps.
  static String disabilityBridge(CoachContext ctx) {
    final ageNote = ctx.age < 55
        ? 'À ${ctx.age} ans, une lacune de prévoyance en cas '
            'd\'invalidité pourrait être significative. '
        : '';

    return '${ctx.firstName}, l\'assurance invalidité (AI) prévoit '
        'une rente après un délai de carence d\'environ 1 an '
        '(LAI art. 28-28a). Le degré d\'invalidité détermine '
        'le montant : dès 40% pour une rente partielle. '
        'Ta caisse LPP verse aussi une rente d\'invalidité '
        '(LPP art. 23-26), coordonnée avec l\'AI. '
        '$ageNote'
        'Côté 3a, une invalidité pourrait donner droit à une '
        'libération des primes si ton contrat le prévoit. '
        'Il serait utile de vérifier ta couverture actuelle '
        'et d\'identifier d\'éventuelles lacunes. '
        'Réf. : LAI art. 28-28a, LPP art. 23-26.';
  }

  // ═══════════════════════════════════════════════════════════════
  // Helpers
  // ═══════════════════════════════════════════════════════════════

  /// Returns the single most impactful enrichment action based on
  /// which key data is still missing or estimated.
  static String? _topEnrichmentAction(CoachContext ctx) {
    final rel = ctx.dataReliability;
    // Priority 1: no certified LPP → suggest scan
    final hasLpp = rel.entries.any(
        (e) => e.key.contains('avoirLpp') && e.value == 'certified');
    if (!hasLpp) {
      return 'Scanne ton certificat LPP pour des projections plus fiables.';
    }
    // Priority 2: no certified AVS → suggest scan
    final hasAvs = rel.entries.any(
        (e) => e.key.contains('anneesContribuees') && e.value == 'certified');
    if (!hasAvs) {
      return 'Scanne ton extrait AVS pour affiner ta rente estimée.';
    }
    // Priority 3: no salary data
    final hasSalary = rel.containsKey('salaireBrutMensuel');
    if (!hasSalary) {
      return 'Renseigne ton salaire brut pour des projections personnalisées.';
    }
    return null;
  }
}
