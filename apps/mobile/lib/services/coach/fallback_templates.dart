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
    final score = ctx.friTotal;
    final interpretation = score >= 70
        ? 'Tu as une bonne visibilité sur ta situation.'
        : score >= 40
            ? 'Il y a encore des zones floues dans ta situation financière.'
            : 'On manque de données pour te donner des chiffres fiables.';
    final trend = ctx.friDelta > 0
        ? ' +${ctx.friDelta.toStringAsFixed(0)} pts depuis ta dernière visite.'
        : ctx.friDelta < 0
            ? ' ${ctx.friDelta.toStringAsFixed(0)} pts depuis ta dernière visite.'
            : '';
    return '$interpretation$trend';
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
      return '${ctx.firstName}, chaque année sans versement 3a, '
          'c\'est ~${taxSaving.toStringAsFixed(0)} CHF offerts au fisc. '
          'Un virement prend 2 minutes depuis ton app bancaire.';
    }

    // Liquidity alert (< 3 months of reserves)
    if (liquidity < 3) {
      return '${ctx.firstName}, si un imprévu arrive demain '
          '(panne, frais médicaux, perte de revenu), ta réserve tient '
          '${liquidity.toStringAsFixed(0)} mois. '
          'Objectif\u00a0: 3 mois minimum pour dormir tranquille.';
    }

    // Retirement gap (replacement ratio < 55%)
    if (replacement < 55) {
      return '${ctx.firstName}, à la retraite, tu vivras avec '
          '~${replacement.toStringAsFixed(0)}\u00a0% de ton revenu actuel. '
          'Concrètement, chaque sortie resto ou vacances devra être repensée. '
          'Il y a des leviers pour améliorer ça.';
    }

    // Default: encourage profile completion with specific enrichment action
    final enrichment = _topEnrichmentAction(ctx);
    if (enrichment != null) {
      return '${ctx.firstName}, plus MINT te connaît, plus les chiffres '
          'sont fiables. $enrichment';
    }
    return '${ctx.firstName}, tes projections reposent encore sur '
        'des estimations. Ajoute tes vrais chiffres pour voir ta '
        'situation réelle — pas une moyenne suisse.';
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
      return 'Ce chiffre s\'appuie sur tes vrais documents — '
          'c\'est proche de ta réalité. '
          'Chaque donnée ajoutée affine encore la précision.';
    }
    final enrichment = _topEnrichmentAction(ctx);
    if (confidence < 40) {
      return 'Attention\u00a0: ce chiffre est une estimation large. '
          'On travaille avec ${confidence.toStringAsFixed(0)}\u00a0% de données réelles. '
          '${enrichment ?? 'Ajoute tes vrais chiffres pour un résultat fiable.'}';
    }
    return 'Ce chiffre repose sur ${confidence.toStringAsFixed(0)}\u00a0% de données réelles. '
        '${enrichment ?? 'Plus tu précises, plus c\'est fiable.'}';
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
        '$name, l\'argent que ton employeur met de côté pour ta retraite '
        '(ton 2e pilier), c\'est souvent le plus gros montant de ta vie — '
        'et la plupart des gens ne savent pas combien ils ont. '
        'Ton certificat de prévoyance (reçu en janvier) donne le chiffre exact. '
        'Un scan prend 30 secondes.',
      'avs' =>
        '$name, ta rente AVS dépend du nombre d\'années où tu as cotisé. '
        '${ctx.archetype.contains('expat') ? 'Si tu n\'as pas toujours travaillé en Suisse, il te manque probablement des années. ' : ''}'
        'Ton extrait de compte (gratuit) te dit exactement où tu en es. '
        'Commande-le sur le site de ta caisse de compensation.',
      '3a' =>
        '$name, ton 3a c\'est de l\'argent que tu mets de côté pour toi — '
        'et qui réduit tes impôts chaque année. '
        'Note tes soldes exacts pour voir ce que ça change concrètement.',
      'patrimoine' =>
        '$name, en dehors de ta prévoyance, combien as-tu de côté\u00a0? '
        'Compte courant, investissements, immobilier — '
        'c\'est ton filet de sécurité si la vie te réserve une surprise.',
      'fiscalite' =>
        '$name, ta commune change tout pour tes impôts. '
        'Entre deux communes du même canton, la différence peut dépasser 30\u00a0%. '
        'Regarde ton dernier avis de taxation — le taux effectif y figure.',
      'objectifRetraite' =>
        '$name, à quel âge voudrais-tu décrocher\u00a0? '
        'Partir à 62 au lieu de 65, c\'est 3 ans de rente en moins — '
        'mais aussi 3 ans de liberté en plus. Tout est une question d\'arbitrage.',
      'compositionMenage' =>
        '$name, en couple, tout change\u00a0: '
        'les impôts, la rente AVS (plafonnée pour les mariés), '
        'la protection en cas de décès. '
        'Ajoute les infos de ton ou ta partenaire pour voir la vraie image.',
      _ =>
        '$name, chaque info que tu ajoutes remplace une estimation par un fait. '
        'Tes projections passent du flou au concret.',
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
        '(capital préservé) ou un compte bancaire avec options '
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
      return 'Prends ton certificat de prévoyance (tu l\'as reçu en janvier) '
          'et scanne-le — ça prend 30 secondes.';
    }
    // Priority 2: no certified AVS → suggest scan
    final hasAvs = rel.entries.any(
        (e) => e.key.contains('anneesContribuees') && e.value == 'certified');
    if (!hasAvs) {
      return 'Commande ton extrait AVS sur le site de ta caisse de compensation — '
          'c\'est gratuit et ça arrive en quelques jours.';
    }
    // Priority 3: no salary data
    final hasSalary = rel.containsKey('salaireBrutMensuel');
    if (!hasSalary) {
      return 'Ouvre ta dernière fiche de paie et note ton salaire brut — '
          'ça change tout pour les projections.';
    }
    return null;
  }
}
