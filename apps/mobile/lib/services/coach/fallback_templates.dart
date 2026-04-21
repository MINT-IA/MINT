/// Fallback Templates — Sprint S35 (Coach Narrative).
///
/// Enhanced templates that use [CoachContext] for personalization
/// WITHOUT requiring an LLM call. These serve as the minimum quality
/// bar: if the LLM is unavailable or fails compliance, these are used.
///
/// All text in French (informal "tu"). No banned terms.
/// References: LSFin, LAVS, LPP, OPP3, LIFD.
library;

import 'package:mint_mobile/utils/chf_formatter.dart';

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

    // Default: observation + lever, not a bare score
    final enrichment = _topEnrichmentAction(ctx);
    if (enrichment != null) {
      return '$salut $enrichment';
    }
    return '$salut Tes chiffres sont là. Par où veux-tu commencer\u00a0?';
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
    return '${ctx.friTotal.toStringAsFixed(0)}/100. $trend';
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
          'd\'environ ${formatChfWithPrefix(taxSaving)} cette année. '
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
      return '${ctx.firstName}, ton taux de remplacement est à '
          '${replacement.toStringAsFixed(0)}\u00a0%. '
          'Un rachat LPP ou un versement 3a change le calcul.';
    }

    // Default: specific enrichment action, not generic score
    final enrichment = _topEnrichmentAction(ctx);
    if (enrichment != null) {
      return '${ctx.firstName}, $enrichment';
    }
    return '${ctx.firstName}, tes projections sont prêtes. '
        'Pose une question ou explore un sujet.';
  }

  // ═══════════════════════════════════════════════════════════════
  // Premier Éclairage Reframe — max 100 words (ComponentType.premierEclairage)
  // ═══════════════════════════════════════════════════════════════

  /// Contextualizes a shock figure with confidence level and
  /// encourages profile enrichment based on data reliability.
  static String premierEclairageReframe(CoachContext ctx) {
    final confidence = ctx.knownValues['confidence_score'] ?? 30;
    final hasCertifiedData = ctx.dataReliability.values
        .any((v) => v == 'certificate');

    if (hasCertifiedData) {
      return 'Données certifiées — confiance ${confidence.toStringAsFixed(0)}\u00a0%. '
          'Estimation basée sur des données vérifiées.';
    }
    final enrichment = _topEnrichmentAction(ctx);
    return 'Confiance ${confidence.toStringAsFixed(0)}\u00a0%. '
        '${enrichment ?? 'Un certificat LPP ou un extrait AVS affinerait cette estimation.'}';
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
        '$name, connais-tu ton avoir LPP actuel ? '
        'Ton certificat de prévoyance (2e pilier) indique le montant exact. '
        'Avec ton salaire et ton âge, l\'estimation pourrait varier '
        'significativement du réel. Un scan du certificat affinerait '
        'tes projections de +18 points de confiance.',
      'avs' =>
        '$name, as-tu déjà demandé ton extrait de compte AVS ? '
        'Il confirme tes années de cotisation effectives. '
        '${ctx.archetype.contains('expat') ? 'En tant qu\'expatrié, des lacunes sont probables. ' : ''}'
        'Commander un extrait est gratuit sur le site de ta caisse de compensation.',
      '3a' =>
        '$name, combien de comptes 3a as-tu et chez quel provider ? '
        'Connaître les soldes exacts permet de calculer ton avantage fiscal '
        'et de projeter ta prévoyance complète.',
      'patrimoine' =>
        '$name, as-tu de l\'épargne en dehors de la prévoyance ? '
        'Comptes courants, investissements, immobilier — ces données '
        'complètent ton Financial Resilience Index.',
      'fiscalite' =>
        '$name, dans quelle commune habites-tu ? '
        'Le coefficient communal varie de 60% à 130% et impacte '
        'directement ton taux d\'imposition réel. '
        'Une déclaration fiscale ou un avis de taxation donnerait un calcul précis.',
      'objectifRetraite' =>
        '$name, à quel âge souhaiterais-tu arrêter de travailler ? '
        'Entre 58 et 70 ans, chaque année change la donne : '
        'rente réduite avant 65 ans, majorée après.',
      'compositionMenage' =>
        '$name, es-tu en couple ? '
        'Si oui, les projections changent significativement : '
        'AVS plafonnée pour les mariés, rente de survivant LPP, '
        'et possibilités d\'optimisation fiscale à deux.',
      _ =>
        '$name, chaque donnée ajoutée affine tes projections '
        'et révèle des leviers concrets.',
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
        'De plus, si la somme de tes comptes étrangers dépasse '
        '\$10\u00a0000 à tout moment de l\'année, tu es tenu·e de '
        'déposer un FBAR (FinCEN Form 114) avant le 15 avril. '
        'L\'amende pour non-déclaration peut atteindre \$12\u00a0500 '
        'par compte (voire plus en cas de faute intentionnelle). '
        'Tes investissements en fonds suisses pourraient être '
        'classés PFIC, avec un traitement fiscal US spécifique. '
        'La convention de double imposition CH-US prévoit des '
        'mécanismes pour éviter une double taxation sur tes '
        'versements 3a et prestations LPP. '
        'Il serait utile de consulter un·e spécialiste '
        'en fiscalité transfrontalière CH-US. '
        'Réf. : Convention de double imposition CH-US, FATCA, '
        'FBAR (FinCEN Form 114, 31 USC 5314).';
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
  // Life event templates (all 18 events from definitive enum)
  // ═══════════════════════════════════════════════════════════════

  /// Marriage: AVS couple cap, LPP beneficiary, fiscal impact.
  static String marriageGuidance(CoachContext ctx) =>
      '${ctx.firstName}, le mariage a un impact direct sur ta prévoyance. '
      'L\'AVS prévoit un plafonnement des rentes de couple à '
      '150\u00a0% d\'une rente maximale (LAVS art. 35). Côté LPP, '
      'ton conjoint devient bénéficiaire prioritaire (LPP art. 19-20). '
      'L\'imposition commune pourrait modifier ta charge fiscale. '
      'Il serait utile de simuler l\'impact sur ta trajectoire.\n\n'
      '_Outil éducatif — ne constitue pas un conseil financier (LSFin)._';

  /// Divorce: LPP splitting, AVS credits, fiscal separation.
  static String divorceGuidance(CoachContext ctx) =>
      '${ctx.firstName}, en cas de divorce, la prévoyance accumulée '
      'pendant le mariage est partagée (CC art. 122-124). Les '
      'bonifications AVS sont réparties (LAVS art. 29sexies). '
      'Le retour à l\'imposition individuelle modifie les barèmes. '
      'Vérifie ton certificat LPP et simule l\'impact sur ta retraite.\n\n'
      '_Outil éducatif — ne constitue pas un conseil financier (LSFin)._';

  /// Birth: child bonifications AVS, family allowances, budget.
  static String birthGuidance(CoachContext ctx) =>
      '${ctx.firstName}, l\'arrivée d\'un enfant ouvre droit à des '
      'bonifications pour tâches éducatives AVS (LAVS art. 29sexies). '
      'Tu as droit aux allocations familiales (min. 200\u00a0CHF/mois). '
      'Côté budget, les frais augmentent d\'env. 1\u00a0000-1\u00a0500\u00a0CHF/mois. '
      'Pense à inscrire le nouveau-né à la LAMal dans les 30 jours.\n\n'
      '_Outil éducatif — ne constitue pas un conseil financier (LSFin)._';

  /// Concubinage: no legal protection, testament needed.
  static String concubinageGuidance(CoachContext ctx) =>
      '${ctx.firstName}, le concubinage n\'offre aucune protection légale '
      'automatique en Suisse. Ton partenaire n\'a PAS droit à la rente '
      'de survivant AVS (LAVS art. 23). La LPP ne couvre le concubin '
      'que si le règlement le prévoit (LPP art. 20a). Sans testament, '
      'l\'héritage va aux héritiers légaux (CC art. 457). Un contrat '
      'de concubinage et un testament pourraient être utiles.\n\n'
      '_Outil éducatif — ne constitue pas un conseil financier (LSFin)._';

  /// Death of relative: survivor benefits, succession.
  static String deathOfRelativeGuidance(CoachContext ctx) =>
      '${ctx.firstName}, le décès d\'un proche peut ouvrir droit à '
      'une rente de survivant AVS (LAVS art. 23-24) et LPP '
      '(LPP art. 18-22). La succession suit les parts réservataires '
      '(CC art. 470-471). L\'impôt sur les successions varie selon '
      'le canton de ${ctx.canton}.\n\n'
      '_Outil éducatif — ne constitue pas un conseil financier (LSFin)._';

  /// Housing purchase: mortgage, EPL, tax impact.
  static String housingPurchaseGuidance(CoachContext ctx) =>
      '${ctx.firstName}, un achat immobilier mobilise plusieurs piliers. '
      'Tu peux retirer ton 2e pilier via EPL (LPP art. 30c, min. '
      '20\u00a0000\u00a0CHF). Fonds propres min. 20\u00a0% (max 10\u00a0% '
      'du 2e pilier). Le taux théorique de 5\u00a0% + 1\u00a0% amort. + '
      '1\u00a0% frais ne doit pas dépasser 1/3 du revenu brut. '
      'Simule l\'impact complet.\n\n'
      '_Outil éducatif — ne constitue pas un conseil financier (LSFin)._';

  /// Housing sale: capital gains tax, EPL reimbursement.
  static String housingSaleGuidance(CoachContext ctx) =>
      '${ctx.firstName}, la vente d\'un bien déclenche l\'impôt sur '
      'les gains immobiliers (taux selon ${ctx.canton} et durée de '
      'détention). Si tu avais retiré du 2e pilier via EPL, tu '
      'pourrais devoir le rembourser (LPP art. 30d).\n\n'
      '_Outil éducatif — ne constitue pas un conseil financier (LSFin)._';

  /// Inheritance: succession rules, tax, réserves.
  static String inheritanceGuidance(CoachContext ctx) =>
      '${ctx.firstName}, un héritage suit les règles des parts '
      'réservataires (CC art. 470-471). L\'impôt sur les successions '
      'varie selon ${ctx.canton} et le lien de parenté. Le 2e pilier '
      'du défunt suit des règles spécifiques (LPP art. 18-22).\n\n'
      '_Outil éducatif — ne constitue pas un conseil financier (LSFin)._';

  /// Donation: inter vivos, tax, réserves.
  static String donationGuidance(CoachContext ctx) =>
      '${ctx.firstName}, une donation entre vifs est soumise à l\'impôt '
      'selon ${ctx.canton}. Les parts réservataires doivent être '
      'respectées (CC art. 470-471). Le rapport des donations '
      '(CC art. 626-632) pourrait s\'appliquer à la succession.\n\n'
      '_Outil éducatif — ne constitue pas un conseil financier (LSFin)._';

  /// Canton move: fiscal impact, LAMal change.
  static String cantonMoveGuidance(CoachContext ctx) =>
      '${ctx.firstName}, un déménagement cantonal a un impact fiscal '
      'significatif. Le barème d\'impôt, la valeur locative et l\'impôt '
      'sur le retrait du capital varient entre cantons. Ta LPP reste '
      'inchangée. Par contre, ta LAMal doit être adaptée.\n\n'
      '_Outil éducatif — ne constitue pas un conseil financier (LSFin)._';

  /// Country move: pillar export, bilateral agreements.
  static String countryMoveGuidance(CoachContext ctx) =>
      '${ctx.firstName}, un départ de Suisse impacte les 3 piliers. '
      'Le 2e pilier est transféré en libre passage (LFLP art. 2). '
      'Le retrait est possible si tu quittes l\'UE/AELE (partie '
      'obligatoire). Le 3a peut être retiré au départ définitif. '
      'L\'AVS verse la rente à l\'étranger (conventions bilatérales).\n\n'
      '_Outil éducatif — ne constitue pas un conseil financier (LSFin)._';

  /// Debt crisis: priority mode, no optimization, orientation.
  static String debtCrisisGuidance(CoachContext ctx) =>
      '${ctx.firstName}, si tu fais face à des difficultés financières, '
      'consulte gratuitement : Caritas Suisse, Dettes Conseils Suisse '
      '(www.dettes.ch), ou La Main Tendue (143). La priorité est de '
      'protéger ton minimum vital (LP art. 93). Les optimisations '
      '(3a, rachat LPP) ne sont PAS adaptées tant que la dette n\'est '
      'pas stabilisée.\n\n'
      '_Outil éducatif — ne constitue pas un conseil financier (LSFin)._';

  /// First job: starting pillar contributions.
  static String firstJobGuidance(CoachContext ctx) =>
      '${ctx.firstName}, ton premier emploi lance ta prévoyance. '
      'Tu cotises à l\'AVS dès le 1er janvier après tes 17 ans '
      '(LAVS art. 3). La LPP commence dès 22\u00a0680\u00a0CHF/an '
      '(LPP art. 7). Tu peux ouvrir un 3a (max 7\u00a0258\u00a0CHF/an) '
      'pour réduire tes impôts dès la première année.\n\n'
      '_Outil éducatif — ne constitue pas un conseil financier (LSFin)._';

  /// Self-employment: LPP optional, 3a max higher.
  static String selfEmploymentGuidance(CoachContext ctx) =>
      '${ctx.firstName}, en tant qu\'indépendant·e, la LPP est '
      'facultative mais tu peux t\'affilier (LPP art. 4). Sans LPP, '
      'ton plafond 3a monte à 36\u00a0288\u00a0CHF/an (20\u00a0% du '
      'revenu net). La cotisation AVS est à ta charge (min. '
      '530\u00a0CHF/an, LAVS art. 8).\n\n'
      '_Outil éducatif — ne constitue pas un conseil financier (LSFin)._';

  /// Retirement: withdrawal options, timing, fiscal.
  static String retirementGuidance(CoachContext ctx) =>
      '${ctx.firstName}, la retraite approche. Tu peux partir entre '
      '63 et 70 ans (LAVS art. 40). Le retrait anticipé réduit la '
      'rente de ~6.8\u00a0%/an. Rente, capital, ou mixte ? Le capital '
      'est taxé séparément (LIFD art. 38), la rente est un revenu '
      'imposable. L\'échelonnement des retraits pourrait optimiser '
      'la fiscalité.\n\n'
      '_Outil éducatif — ne constitue pas un conseil financier (LSFin)._';

  // ═══════════════════════════════════════════════════════════════
  // Helpers
  // ═══════════════════════════════════════════════════════════════

  /// Returns the single most impactful enrichment action based on
  /// which key data is still missing or estimated.
  static String? _topEnrichmentAction(CoachContext ctx) {
    final rel = ctx.dataReliability;
    // Priority 1: no certified LPP → suggest scan.
    // Value string matches ProfileDataSource enum name — `'certificate'`,
    // NOT `'certified'`. The typo made every greeting say "Scanne ton
    // certificat LPP" even right after the user scanned one.
    final hasLpp = rel.entries.any(
        (e) => e.key.contains('avoirLpp') && e.value == 'certificate');
    if (!hasLpp) {
      return 'Scanne ton certificat LPP pour des projections plus fiables.';
    }
    // Priority 2: no certified AVS → suggest scan (same enum typo).
    final hasAvs = rel.entries.any(
        (e) => e.key.contains('anneesContribuees') && e.value == 'certificate');
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
