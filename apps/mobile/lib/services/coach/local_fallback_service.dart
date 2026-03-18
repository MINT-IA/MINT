/// Local Fallback Service — Sprint S64 (Multi-LLM Redundancy).
///
/// Template-based fallback when all cloud LLMs are unavailable.
/// Generates compliant French responses using keyword matching
/// against the 10 most common Swiss financial topics.
///
/// Guarantees:
///   - Zero network dependency
///   - Every response is compliant (no banned terms, educational tone)
///   - Every response ends with a disclaimer
///   - Every response suggests retrying later for personalized guidance
///
/// References:
///   - LSFin art. 3/8 (quality of financial information)
///   - LAVS, LPP, OPP3, LIFD (Swiss law references in templates)
library;

import 'package:mint_mobile/services/coach/compliance_guard.dart';

/// Template-based local fallback for when all LLMs are down.
///
/// Uses keyword matching to select pre-written French responses.
/// Covers the 10 most common financial topics.
class LocalFallbackService {
  LocalFallbackService._();

  /// Generate a template-based response from keyword matching.
  ///
  /// [userMessage] — the user's question (used for topic detection).
  /// [lifecyclePhase] — optional lifecycle phase for context.
  /// [detectedTopics] — optional pre-detected topics (overrides keyword matching).
  static String generateFallback({
    required String userMessage,
    String? lifecyclePhase,
    List<String>? detectedTopics,
  }) {
    final topics = detectedTopics ?? _detectTopics(userMessage);

    // Try to find a matching template.
    for (final topic in topics) {
      final template = _templates[topic];
      if (template != null) {
        return '$template\n\n$_retryMessage\n\n_${ComplianceGuard.standardDisclaimer}_';
      }
    }

    // No topic matched — generic educational response.
    return '$_genericResponse\n\n$_retryMessage\n\n_${ComplianceGuard.standardDisclaimer}_';
  }

  // ══════════════════════════════════════════════════════════════
  //  TOPIC DETECTION
  // ══════════════════════════════════════════════════════════════

  /// Detect topics from user message via keyword matching.
  static List<String> _detectTopics(String message) {
    final lower = message.toLowerCase();
    final matched = <String>[];

    for (final entry in _topicKeywords.entries) {
      for (final keyword in entry.value) {
        if (lower.contains(keyword)) {
          matched.add(entry.key);
          break; // One match per topic is enough.
        }
      }
    }

    return matched;
  }

  /// Keywords for each of the 10 supported topics.
  static const Map<String, List<String>> _topicKeywords = {
    '3a': ['3a', 'troisième pilier', '3ème pilier', 'pilier 3a'],
    'lpp': ['lpp', '2e pilier', 'deuxième pilier', 'caisse de pension', 'rachat'],
    'avs': ['avs', '1er pilier', 'premier pilier', 'rente avs', 'ahv'],
    'impots': ['impôt', 'impot', 'fiscal', 'déduction', 'deduction', 'déclaration'],
    'budget': ['budget', 'dépense', 'depense', 'épargne', 'epargne', 'économie'],
    'immobilier': ['immobilier', 'hypothèque', 'hypotheque', 'maison', 'appartement', 'loyer', 'epl'],
    'retraite': ['retraite', 'pension', 'rente', 'capital vs rente'],
    'assurances': ['assurance', 'lamal', 'maladie', 'complémentaire', 'complementaire'],
    'succession': ['succession', 'héritage', 'heritage', 'testament', 'bénéficiaire'],
    'dette': ['dette', 'crédit', 'credit', 'leasing', 'endettement', 'remboursement'],
  };

  // ══════════════════════════════════════════════════════════════
  //  TEMPLATES (10 topics)
  // ══════════════════════════════════════════════════════════════

  static const Map<String, String> _templates = {
    '3a': 'Le 3e pilier (pilier 3a) est un outil d\'épargne-retraite '
        'avec avantage fiscal. En 2025, le plafond annuel est de '
        '7\u00a0258\u00a0CHF pour les salarié\u00b7e\u00b7s affilié\u00b7e\u00b7s '
        'à une caisse de pension (LPP). Pour les indépendant\u00b7e\u00b7s '
        'sans LPP, le plafond est de 20\u00a0% du revenu net, '
        'max. 36\u00a0288\u00a0CHF/an.\n\n'
        'Un versement 3a est déductible du revenu imposable '
        '(OPP3 art. 7). Tu pourrais explorer le simulateur 3a '
        'dans l\'app pour estimer l\'impact sur tes impôts.\n\n'
        'Réf.\u00a0: OPP3 art. 7, LIFD art. 33 al. 1 let. e.',

    'lpp': 'Le 2e pilier (LPP) est la prévoyance professionnelle '
        'obligatoire. Le taux de conversion minimal est de 6,8\u00a0% '
        '(LPP art. 14). Les bonifications d\'épargne augmentent '
        'avec l\'âge\u00a0: 7\u00a0% (25-34 ans), 10\u00a0% (35-44), '
        '15\u00a0% (45-54), 18\u00a0% (55-65).\n\n'
        'Un rachat LPP pourrait être intéressant '
        'fiscalement, car le montant est déductible '
        '(LPP art. 79b). Attention au blocage de 3 ans '
        'si tu retires ensuite en capital.\n\n'
        'Réf.\u00a0: LPP art. 14, 79b\u00a0; OPP2 art. 5.',

    'avs': 'L\'AVS (1er pilier) est la base de la prévoyance suisse. '
        'La rente maximale individuelle est de 2\u00a0520\u00a0CHF/mois '
        '(30\u00a0240\u00a0CHF/an). Pour les couples mariés, le plafond '
        'est de 150\u00a0% d\'une rente maximale (LAVS art. 35).\n\n'
        'La rente dépend des années de cotisation et du revenu moyen. '
        'Chaque année manquante réduit la rente d\'environ 1/44e. '
        'Tu pourrais demander un extrait de compte AVS gratuit '
        'pour vérifier tes lacunes.\n\n'
        'Réf.\u00a0: LAVS art. 21-40, art. 35.',

    'impots': 'En Suisse, l\'imposition varie selon le canton et la commune. '
        'Les déductions courantes incluent\u00a0: versements 3a (OPP3 art. 7), '
        'rachats LPP (LPP art. 79b), frais professionnels, '
        'et assurance maladie.\n\n'
        'Le retrait en capital du 2e pilier est taxé séparément '
        'à un taux réduit (LIFD art. 38). Les retraits SWR '
        '(consommation de patrimoine) ne sont pas imposables.\n\n'
        'Tu pourrais utiliser le simulateur fiscal dans l\'app '
        'pour estimer ton économie d\'impôt.\n\n'
        'Réf.\u00a0: LIFD art. 33, 38\u00a0; LHID.',

    'budget': 'Un budget solide est la base de la santé financière. '
        'La règle 50/30/20 suggère\u00a0: 50\u00a0% pour les besoins '
        'essentiels, 30\u00a0% pour les envies, 20\u00a0% pour l\'épargne.\n\n'
        'En Suisse, les charges fixes typiques incluent\u00a0: '
        'loyer, assurance maladie (LAMal), impôts, transports. '
        'Un fonds d\'urgence de 3 à 6 mois de charges fixes '
        'est souvent considéré comme une base prudente.\n\n'
        'Tu pourrais utiliser l\'outil budget dans l\'app '
        'pour analyser tes flux.\n\n'
        'Réf.\u00a0: recommandations Budget-conseil Suisse.',

    'immobilier': 'Pour l\'achat immobilier en Suisse, les règles FINMA/ASB '
        'prévoient\u00a0: taux théorique de 5\u00a0%, amortissement 1\u00a0%/an, '
        'frais 1\u00a0%/an. Les charges ne doivent pas dépasser '
        '1/3 du revenu brut.\n\n'
        'Les fonds propres minimaux sont de 20\u00a0%, dont max. 10\u00a0% '
        'du 2e pilier (EPL). Un retrait EPL est possible '
        'sous conditions (LPP art. 30c), avec un montant minimum '
        'de 20\u00a0000\u00a0CHF.\n\n'
        'Tu pourrais utiliser le simulateur hypothécaire '
        'pour évaluer ta capacité d\'emprunt.\n\n'
        'Réf.\u00a0: LPP art. 30c\u00a0; OPP2 art. 5\u00a0; FINMA.',

    'retraite': 'La retraite en Suisse repose sur 3 piliers\u00a0: '
        'AVS (1er), LPP (2e) et épargne privée (3e). '
        'L\'âge de référence est de 65 ans.\n\n'
        'Le choix entre rente et capital au 2e pilier '
        'dépend de ta situation\u00a0: la rente offre une sécurité '
        'à vie (LPP art. 37), le capital offre de la flexibilité '
        'mais nécessite une gestion active.\n\n'
        'Tu pourrais comparer les deux options dans le simulateur '
        'rente vs capital. Les hypothèses (rendement, inflation, '
        'espérance de vie) sont déterminantes.\n\n'
        'Réf.\u00a0: LPP art. 37\u00a0; LAVS art. 21.',

    'assurances': 'En Suisse, l\'assurance maladie de base (LAMal) '
        'est obligatoire. Les primes varient selon le canton, '
        'le modèle et la franchise choisie (300 à 2\u00a0500\u00a0CHF).\n\n'
        'Des subsides sont disponibles pour les revenus modestes '
        '(LAMal art. 65). Les assurances complémentaires (LCA) '
        'couvrent des prestations supplémentaires mais ne sont pas '
        'obligatoires.\n\n'
        'Tu pourrais comparer les primes sur priminfo.admin.ch '
        'pour ta commune.\n\n'
        'Réf.\u00a0: LAMal art. 3, 65\u00a0; OAMal.',

    'succession': 'Le droit successoral suisse (CC art. 457 ss.) '
        'prévoit des réserves héréditaires pour le conjoint '
        'et les descendants. La quotité disponible dépend '
        'de la situation familiale.\n\n'
        'En prévoyance, le 2e pilier (LPP art. 20a) désigne '
        'un ordre de bénéficiaires\u00a0: conjoint\u00b7e, puis enfants, '
        'puis parents. Le 3a suit un ordre similaire (OPP3 art. 2).\n\n'
        'Un testament ou un pacte successoral pourrait permettre '
        'd\'organiser la transmission selon tes souhaits.\n\n'
        'Réf.\u00a0: CC art. 457 ss.\u00a0; LPP art. 20a\u00a0; OPP3 art. 2.',

    'dette': 'Si tu as des dettes, la priorité est de stabiliser '
        'la situation avant toute optimisation (3a, rachat LPP).\n\n'
        'Les étapes possibles\u00a0:\n'
        '1. Identifier toutes les dettes et leurs taux d\'intérêt.\n'
        '2. Prioriser le remboursement par taux décroissant.\n'
        '3. Constituer un fonds d\'urgence minimal (1 mois de charges).\n'
        '4. Envisager un conseil en désendettement gratuit.\n\n'
        'Services gratuits\u00a0: Caritas (caritas.ch), '
        'Dettes Conseils Suisse (dettes.ch), '
        'La Main Tendue (143, 24h/24).\n\n'
        'Réf.\u00a0: LP, SchKG.',
  };

  // ══════════════════════════════════════════════════════════════
  //  FALLBACK & RETRY MESSAGES
  // ══════════════════════════════════════════════════════════════

  static const String _genericResponse =
      'Je ne suis pas en mesure de fournir une réponse personnalisée '
      'pour le moment. En attendant, voici quelques pistes\u00a0:\n\n'
      '\u2022 Explore les simulateurs (3a, LPP, retraite) pour des estimations chiffrées.\n'
      '\u2022 Consulte les fiches éducatives pour comprendre les mécanismes.\n'
      '\u2022 Enrichis ton profil pour des projections plus précises.';

  static const String _retryMessage =
      'Pour une réponse plus personnalisée, réessaie dans quelques instants '
      'lorsque le coach IA sera à nouveau disponible.';
}
