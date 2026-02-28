import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/coach/coach_models.dart';
import 'package:mint_mobile/services/coach/compliance_guard.dart';
import 'package:mint_mobile/services/financial_fitness_service.dart';
import 'package:mint_mobile/services/forecaster_service.dart';
import 'package:mint_mobile/services/rag_service.dart';

// ────────────────────────────────────────────────────────────
//  COACH LLM SERVICE — Sprint C8 / MINT Coach
// ────────────────────────────────────────────────────────────
//
// Orchestrateur LLM pour le chat Coach MINT.
// BYOK (Bring Your Own Key) : l'utilisateur fournit sa propre
// cle API (OpenAI ou Anthropic).
//
// REGLES :
//  - Le LLM NE calcule JAMAIS → calculs via rules_engine/services
//  - Le LLM NE donne JAMAIS de conseil financier → educatif uniquement
//  - Guardrails : filtrage des termes bannis + disclaimer obligatoire
//  - Context-aware : profil CoachProfile injecte dans le system prompt
//
// Hybride : mock enrichi (sans cle) / RAG backend (avec BYOK).
// Les deux chemins retournent sources + disclaimers.
// ────────────────────────────────────────────────────────────

/// Fournisseur LLM supporte
enum LlmProvider { openai, anthropic, mistral }

/// Configuration de la connexion LLM (BYOK)
class LlmConfig {
  final String apiKey;
  final LlmProvider provider;
  final String model;

  const LlmConfig({
    required this.apiKey,
    required this.provider,
    this.model = 'gpt-4',
  });

  /// Configurations par defaut par provider
  static const defaultOpenAI = LlmConfig(
    apiKey: '',
    provider: LlmProvider.openai,
    model: 'gpt-4',
  );

  static const defaultAnthropic = LlmConfig(
    apiKey: '',
    provider: LlmProvider.anthropic,
    model: 'claude-3-sonnet-20240229',
  );

  /// Modeles disponibles par provider
  static List<String> modelsForProvider(LlmProvider provider) {
    switch (provider) {
      case LlmProvider.openai:
        return ['gpt-4', 'gpt-4-turbo', 'gpt-4o', 'gpt-3.5-turbo'];
      case LlmProvider.anthropic:
        return [
          'claude-sonnet-4-5-20250929',
          'claude-3-haiku-20240307',
          'claude-3-opus-20240229',
        ];
      case LlmProvider.mistral:
        return ['mistral-large-latest', 'mistral-medium-latest'];
    }
  }

  bool get hasApiKey => apiKey.isNotEmpty;

  LlmConfig copyWith({
    String? apiKey,
    LlmProvider? provider,
    String? model,
  }) {
    return LlmConfig(
      apiKey: apiKey ?? this.apiKey,
      provider: provider ?? this.provider,
      model: model ?? this.model,
    );
  }
}

/// Message dans l'historique de conversation
class ChatMessage {
  final String role; // 'user', 'assistant', 'system'
  final String content;
  final DateTime timestamp;
  final List<String>? suggestedActions;
  final List<RagSource> sources;
  final List<String> disclaimers;

  const ChatMessage({
    required this.role,
    required this.content,
    required this.timestamp,
    this.suggestedActions,
    this.sources = const [],
    this.disclaimers = const [],
  });

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';
  bool get isSystem => role == 'system';
}

/// Reponse du coach LLM
class CoachResponse {
  final String message;
  final List<String>? suggestedActions;
  final String disclaimer;
  final List<RagSource> sources;
  final List<String> disclaimers;
  final bool wasFiltered;

  const CoachResponse({
    required this.message,
    this.suggestedActions,
    required this.disclaimer,
    this.sources = const [],
    this.disclaimers = const [],
    this.wasFiltered = false,
  });
}

/// Service de chat LLM pour le Coach MINT
class CoachLlmService {
  /// Disclaimer standard
  static const _disclaimer =
      'Outil educatif — ne constitue pas un conseil financier. LSFin.';

  /// Envoie un message et recoit une reponse du coach
  ///
  /// Le service prepend le system prompt avec le contexte utilisateur,
  /// applique les guardrails, et retourne une CoachResponse.
  ///
  /// Si BYOK est configure (config.hasApiKey), route via le backend RAG
  /// pour obtenir des reponses groundees avec sources verifiables.
  /// Sinon, utilise les reponses mock enrichies de references legales.
  static Future<CoachResponse> chat({
    required String userMessage,
    required CoachProfile profile,
    required List<ChatMessage> history,
    required LlmConfig config,
  }) async {
    // ── Mode RAG (BYOK configure) ──────────────────────────
    if (config.hasApiKey) {
      return _chatViaRag(
        userMessage: userMessage,
        profile: profile,
        config: config,
        history: history,
      );
    }

    // ── Mode mock (pas de cle API) ─────────────────────────
    final rawResponse = _getMockResponse(
      userMessage: userMessage,
      profile: profile,
    );

    // CRIT #6: try-catch around validate() to prevent crashes on edge cases.
    ComplianceResult result;
    try {
      final coachCtx = _buildCoachContext(profile);
      result = ComplianceGuard.validate(
        rawResponse.message,
        context: coachCtx,
        componentType: ComponentType.general,
      );
    } catch (_) {
      // If validation crashes, use fallback — never show unvalidated LLM output.
      return CoachResponse(
        message: _safeChatFallback(),
        disclaimer: _disclaimer,
        wasFiltered: true,
      );
    }

    final isFallback = result.useFallback;
    final message = isFallback ? _safeChatFallback() : result.sanitizedText;

    return CoachResponse(
      message: message,
      // HIGH fix: clear sources/actions when using fallback (orphaned metadata).
      suggestedActions: isFallback ? null : rawResponse.suggestedActions,
      disclaimer: _disclaimer,
      sources: isFallback ? const [] : rawResponse.sources,
      disclaimers: const [],
      wasFiltered: !result.isCompliant,
    );
  }

  /// Appel reel via le backend RAG (BYOK)
  static Future<CoachResponse> _chatViaRag({
    required String userMessage,
    required CoachProfile profile,
    required LlmConfig config,
    required List<ChatMessage> history,
  }) async {
    final ragService = RagService();
    final String provider;
    switch (config.provider) {
      case LlmProvider.anthropic:
        provider = 'claude';
        break;
      case LlmProvider.mistral:
        provider = 'mistral';
        break;
      case LlmProvider.openai:
        provider = 'openai';
        break;
    }
    final profileContext = _buildProfileContext(profile);

    // Injecter le contexte conversationnel dans la question
    final augmentedQuestion = _buildConversationContext(history, userMessage);

    final ragResponse = await ragService.query(
      question: augmentedQuestion,
      apiKey: config.apiKey,
      provider: provider,
      model: config.model,
      profileContext: profileContext,
    );

    // Validate through ComplianceGuard (5-layer) in addition to backend filtering.
    // CRIT #6: try-catch to prevent crashes on edge cases.
    ComplianceResult result;
    try {
      final coachCtx = _buildCoachContext(profile);
      result = ComplianceGuard.validate(
        ragResponse.answer,
        context: coachCtx,
        componentType: ComponentType.general,
      );
    } catch (_) {
      return CoachResponse(
        message: _safeChatFallback(),
        disclaimer: _disclaimer,
        wasFiltered: true,
      );
    }

    final isFallback = result.useFallback;
    final message = isFallback ? _safeChatFallback() : result.sanitizedText;

    return CoachResponse(
      message: message,
      // HIGH fix: clear sources/actions when using fallback.
      suggestedActions: isFallback ? null : _inferSuggestedActions(userMessage),
      disclaimer: _disclaimer,
      sources: isFallback ? const [] : ragResponse.sources,
      disclaimers: isFallback ? const [] : ragResponse.disclaimers,
      wasFiltered: !result.isCompliant,
    );
  }

  /// Construit le contexte conversationnel pour le RAG (multi-turn client-side).
  ///
  /// Le backend /rag/query est single-turn par design (stateless, privacy).
  /// On resume les derniers echanges dans la question elle-meme.
  static String _buildConversationContext(
      List<ChatMessage> history, String currentMessage) {
    // Filtrer les messages systeme et ne garder que user/assistant
    final relevant =
        history.where((m) => m.isUser || m.isAssistant).toList();

    // Si pas d'historique significatif, retourner le message tel quel
    if (relevant.length <= 1) return currentMessage;

    // Prendre les 4 derniers echanges (8 messages max)
    final tail =
        relevant.length > 8 ? relevant.sublist(relevant.length - 8) : relevant;

    final buf = StringBuffer('Contexte de la conversation :\n');
    for (final msg in tail) {
      buf.writeln('${msg.isUser ? "Utilisateur" : "Coach"}: ${msg.content}');
    }
    buf.writeln('\nNouvelle question :\n$currentMessage');
    return buf.toString();
  }

  /// Convertit le profil coach en contexte riche pour le backend RAG.
  ///
  /// Le champ `financial_summary` est injecte dans le system prompt
  /// du backend (guardrails.py) pour personnaliser les reponses LLM.
  static Map<String, dynamic> _buildProfileContext(CoachProfile profile) {
    final parts = <String>[];
    parts.add('Age : ${profile.age} ans');
    parts.add('Canton : ${profile.canton}');
    parts.add('Statut : ${profile.etatCivil.name}');

    // Revenus
    if (profile.salaireBrutMensuel > 0) {
      parts.add(
          'Salaire brut : ${profile.salaireBrutMensuel.toStringAsFixed(0)} CHF/mois');
    }

    // Prevoyance
    final prev = profile.prevoyance;
    if (prev.totalEpargne3a > 0) {
      parts.add(
          'Avoir 3a : ${prev.totalEpargne3a.toStringAsFixed(0)} CHF');
    }
    if (prev.nombre3a > 0) {
      parts.add('Nombre de comptes 3a : ${prev.nombre3a}');
    }
    if (prev.avoirLppTotal != null && prev.avoirLppTotal! > 0) {
      parts.add(
          'Avoir LPP : ${prev.avoirLppTotal!.toStringAsFixed(0)} CHF');
    }
    if (prev.lacuneRachatRestante > 0) {
      parts.add(
          'Lacune rachat LPP : ${prev.lacuneRachatRestante.toStringAsFixed(0)} CHF');
    }

    // Patrimoine + dettes
    final pat = profile.patrimoine;
    if (pat.totalPatrimoine > 0) {
      parts.add(
          'Patrimoine : ${pat.totalPatrimoine.toStringAsFixed(0)} CHF');
    }
    if (profile.dettes.totalDettes > 0) {
      parts.add(
          'Dettes : ${profile.dettes.totalDettes.toStringAsFixed(0)} CHF');
    }

    // Depenses
    final dep = profile.depenses;
    if (dep.loyer > 0) {
      parts.add('Loyer : ${dep.loyer.toStringAsFixed(0)} CHF/mois');
    }
    if (dep.assuranceMaladie > 0) {
      parts.add(
          'Assurance maladie : ${dep.assuranceMaladie.toStringAsFixed(0)} CHF/mois');
    }

    // Versements planifies
    if (profile.plannedContributions.isNotEmpty) {
      final contribs = profile.plannedContributions
          .map((c) =>
              '${c.label} (${c.amount.toStringAsFixed(0)} CHF/mois)')
          .join(', ');
      parts.add('Versements : $contribs');
    }

    // Check-ins recents
    if (profile.checkIns.isNotEmpty) {
      final recent = profile.checkIns.length > 3
          ? profile.checkIns.sublist(profile.checkIns.length - 3)
          : profile.checkIns;
      final summary = recent.map((ci) {
        final month = '${ci.month.month}/${ci.month.year}';
        return '$month: ${ci.totalVersements.toStringAsFixed(0)} CHF';
      }).join(', ');
      parts.add('Derniers check-ins : $summary');
    }

    // Score fitness (wrapped in try-catch)
    try {
      final score = FinancialFitnessService.calculate(profile: profile);
      parts.add('Score fitness : ${score.global}/100 '
          '(Budget ${score.budget.score}, '
          'Prevoyance ${score.prevoyance.score}, '
          'Patrimoine ${score.patrimoine.score})');
    } catch (_) {}

    // Projection retraite (wrapped in try-catch)
    try {
      final proj = ForecasterService.project(
        profile: profile,
        targetDate: profile.goalA.targetDate,
      );
      parts.add(
          'Capital projete retraite : ${proj.base.capitalFinal.toStringAsFixed(0)} CHF');
      parts.add(
          'Taux de remplacement : ${proj.tauxRemplacementBase.toStringAsFixed(1)}%');
    } catch (_) {}

    // Conjoint
    if (profile.isCouple && profile.conjoint != null) {
      final c = profile.conjoint!;
      parts.add(
          'Conjoint·e : ${c.firstName ?? "conjoint·e"}, ${c.age ?? 0} ans');
      if (c.isFatcaResident) parts.add('Conjoint·e FATCA');
    }

    // Objectif
    parts.add('Objectif : ${profile.goalA.label}');

    // Instructions de structure pour le LLM (injectees via le system prompt backend)
    parts.add('');
    parts.add('STRUCTURE DE TA REPONSE :');
    parts.add('- Commence par une synthese en 1-2 phrases.');
    parts.add('- Si pertinent, liste les options avec leur impact en CHF.');
    parts.add('- Mentionne les risques et points d\'attention.');
    parts.add('- Cite tes sources legales (LPP art. X, LIFD art. Y, etc.).');

    return {
      'canton': profile.canton,
      'age': profile.age,
      'civil_status': profile.etatCivil.name,
      if (profile.firstName != null) 'first_name': profile.firstName,
      'financial_summary': parts.join('\n'),
    };
  }

  /// Infere les actions suggerees a partir du message utilisateur
  static List<String> _inferSuggestedActions(String userMessage) {
    final lower = userMessage.toLowerCase();
    if (lower.contains('3a')) {
      return ['Simuler un versement 3a', 'Voir mes comptes 3a'];
    }
    if (lower.contains('lpp') || lower.contains('rachat')) {
      return ['Simuler un rachat LPP', 'Comprendre le rachat LPP'];
    }
    if (lower.contains('retraite')) {
      return ['Voir ma trajectoire', 'Explorer les scenarios'];
    }
    if (lower.contains('impot') || lower.contains('fiscal')) {
      return ['Deductions fiscales possibles', 'Simuler l\'impact fiscal'];
    }
    return ['Mon score Fitness', 'Ma trajectoire retraite'];
  }

  /// Construit le system prompt avec le contexte utilisateur.
  ///
  /// CRIT #6: wrapped in try-catch to prevent crash on incomplete profiles.
  static String buildSystemPrompt(CoachProfile profile) {
    final firstName = profile.firstName ?? 'utilisateur';
    final age = profile.age;
    final canton = profile.canton;

    // Calculate score and projection — may fail on incomplete profiles.
    int globalScore = 0;
    int budgetScore = 0;
    int prevoyanceScore = 0;
    int patrimoineScore = 0;
    String capitalBase = '—';
    String tauxRemplacement = '—';

    try {
      final score = FinancialFitnessService.calculate(profile: profile);
      globalScore = score.global;
      budgetScore = score.budget.score;
      prevoyanceScore = score.prevoyance.score;
      patrimoineScore = score.patrimoine.score;
    } catch (_) {}

    try {
      final projection = ForecasterService.project(
        profile: profile,
        targetDate: profile.goalA.targetDate,
      );
      capitalBase = projection.base.capitalFinal.toStringAsFixed(0);
      tauxRemplacement = projection.tauxRemplacementBase.toStringAsFixed(1);
    } catch (_) {}

    final buffer = StringBuffer();
    buffer.writeln(
        'Tu es le coach financier MINT. Tu aides $firstName a comprendre sa situation financiere suisse.');
    buffer.writeln();
    buffer.writeln('REGLES ABSOLUES :');
    buffer.writeln(
        '- Tu NE calcules JAMAIS. Tu utilises uniquement les donnees fournies par le systeme.');
    buffer.writeln(
        '- Tu NE donnes JAMAIS de conseil financier. Tu es educatif.');
    buffer.writeln(
        '- Tu dis toujours "consulte un·e specialiste" pour les decisions importantes.');
    buffer.writeln('- Tu parles en francais, tu tutoies.');
    buffer.writeln(
        '- Tu cites TOUJOURS tes sources legales (LPP art. X, OPP3 art. Y, LIFD art. Z, etc.).');
    buffer.writeln(
        '- Tu NE dis JAMAIS : "garanti", "certain", "assure", "sans risque", "optimal", "meilleur", "parfait".');
    buffer.writeln(
        '- Tu ajoutes toujours un disclaimer si tu parles de projections.');
    buffer.writeln();
    buffer.writeln('STRUCTURE DE TA REPONSE :');
    buffer.writeln(
        '- Commence par une synthese en 1-2 phrases.');
    buffer.writeln(
        '- Si pertinent, liste les options avec leur impact en CHF.');
    buffer.writeln(
        '- Mentionne les risques et points d\'attention.');
    buffer.writeln(
        '- Cite tes sources legales (LPP art. X, LIFD art. Y, etc.).');
    buffer.writeln();
    buffer.writeln('CONTEXTE UTILISATEUR :');
    buffer.writeln(
        '- Prenom : $firstName, Age : $age, Canton : $canton');
    buffer.writeln(
        '- Score Fitness : $globalScore/100 (Budget: $budgetScore, Prevoyance: $prevoyanceScore, Patrimoine: $patrimoineScore)');
    buffer.writeln('- Capital projete base : $capitalBase CHF');
    buffer.writeln('- Taux de remplacement estime : $tauxRemplacement%');

    // Ajouter le contexte conjoint si applicable
    if (profile.isCouple && profile.conjoint != null) {
      final conj = profile.conjoint!;
      final conjFirstName = conj.firstName ?? 'conjoint·e';
      final conjAge = conj.age ?? 0;
      buffer.writeln(
          '- Conjoint·e : $conjFirstName, $conjAge ans');
      if (conj.nationality != null) {
        buffer.write(
            '- Nationalite conjoint·e : ${conj.nationality}');
        if (conj.isFatcaResident) {
          buffer.write(' (FATCA)');
        }
        buffer.writeln();
      }
    }

    return buffer.toString();
  }

  /// Reponses mock basees sur des mots-cles
  static _MockResult _getMockResponse({
    required String userMessage,
    required CoachProfile profile,
  }) {
    final lower = userMessage.toLowerCase();

    // Calculer la projection pour enrichir les reponses
    String tauxRemplacement = '—';
    try {
      final projection = ForecasterService.project(
        profile: profile,
        targetDate: profile.goalA.targetDate,
      );
      tauxRemplacement = projection.tauxRemplacementBase.toStringAsFixed(1);
    } catch (_) {
      // Incomplete profile or missing targetDate — degrade gracefully.
    }

    if (lower.contains('3a')) {
      return _MockResult(
        message:
            'Ton plafond 3a est de 7\'258 CHF/an (OPP3 art. 7). Tu as encore de la marge pour optimiser. Pense a verser avant fin decembre !',
        suggestedActions: [
          'Simuler un versement 3a',
          'Voir mes comptes 3a',
        ],
        sources: const [
          RagSource(
              title: 'Pilier 3a', file: 'opp3', section: 'OPP3 art. 7'),
        ],
      );
    }

    if (lower.contains('lpp') || lower.contains('rachat')) {
      return _MockResult(
        message:
            'Avec ta lacune LPP actuelle, un rachat pourrait te faire economiser sur tes impots (LPP art. 79b). Simule l\'impact avec le simulateur rachat LPP.',
        suggestedActions: [
          'Simuler un rachat LPP',
          'Comprendre le rachat LPP',
        ],
        sources: const [
          RagSource(
              title: 'Prevoyance professionnelle',
              file: 'lpp',
              section: 'LPP art. 79b'),
        ],
      );
    }

    if (lower.contains('retraite')) {
      return _MockResult(
        message:
            'D\'apres ta trajectoire actuelle, ton taux de remplacement estime est de $tauxRemplacement%. La cible generalement recommandee est entre 60% et 80% (LAVS art. 21).',
        suggestedActions: [
          'Voir ma trajectoire',
          'Explorer les scenarios',
        ],
        sources: const [
          RagSource(
              title: 'Prevoyance vieillesse',
              file: 'lavs_lpp',
              section: 'LAVS art. 21 / LPP art. 13'),
        ],
      );
    }

    if (lower.contains('impot') || lower.contains('fiscal')) {
      return _MockResult(
        message:
            'La declaration d\'impots dans le canton ${profile.canton} — n\'oublie pas de deduire tes versements 3a et tes rachats LPP (LIFD art. 33) !',
        suggestedActions: [
          'Deductions fiscales possibles',
          'Simuler l\'impact fiscal',
        ],
        sources: const [
          RagSource(
              title: 'Fiscalite',
              file: 'lifd',
              section: 'LIFD art. 33 / LHID'),
        ],
      );
    }

    if (lower.contains('lauren') || lower.contains('conjoint')) {
      return _MockResult(
        message:
            'Lauren a un profil particulier en tant que citoyenne americaine (FATCA). Certains produits 3a ne sont pas accessibles. Consulte un·e specialiste pour evaluer les alternatives.',
        suggestedActions: [
          'En savoir plus sur FATCA',
          'Trouver un·e specialiste',
        ],
        sources: const [
          RagSource(
              title: 'FATCA',
              file: 'fatca',
              section: 'Foreign Account Tax Compliance Act'),
        ],
      );
    }

    // Reponse par defaut
    return _MockResult(
      message:
          'Je suis la pour t\'aider a comprendre ta situation financiere. Tu peux me poser des questions sur ton 3a, ta LPP, tes impots, ou ta trajectoire retraite.',
      suggestedActions: [
        'Mon score Fitness',
        'Ma trajectoire retraite',
        'Mes deductions fiscales',
      ],
    );
  }

  /// Build a [CoachContext] from profile data for compliance validation.
  ///
  /// Extracts known numeric values from financial_core so
  /// [HallucinationDetector] can verify LLM output.
  /// HIGH fix: guards against infinity/NaN with `.isFinite` before injection.
  static CoachContext _buildCoachContext(CoachProfile profile) {
    final knownValues = <String, double>{};

    try {
      final score = FinancialFitnessService.calculate(profile: profile);
      final g = score.global.toDouble();
      if (g.isFinite && g > 0) knownValues['fri_total'] = g;
    } catch (_) {}

    try {
      final proj = ForecasterService.project(
        profile: profile,
        targetDate: profile.goalA.targetDate,
      );
      final cap = proj.base.capitalFinal;
      final taux = proj.tauxRemplacementBase;
      if (cap.isFinite && cap > 0) knownValues['capital_final'] = cap;
      if (taux.isFinite && taux > 0) knownValues['replacement_ratio'] = taux;
    } catch (_) {}

    final epargne3a = profile.prevoyance.totalEpargne3a;
    if (epargne3a.isFinite && epargne3a > 0) {
      knownValues['epargne_3a'] = epargne3a;
    }
    final avoirLpp = profile.prevoyance.avoirLppTotal;
    if (avoirLpp != null && avoirLpp.isFinite && avoirLpp > 0) {
      knownValues['avoir_lpp'] = avoirLpp;
    }

    return CoachContext(
      firstName: profile.firstName ?? 'utilisateur',
      age: profile.age,
      canton: profile.canton,
      knownValues: knownValues,
    );
  }

  /// Safe fallback when ComplianceGuard rejects LLM output.
  static String _safeChatFallback() {
    return 'Je suis là pour t\'aider à comprendre ta situation financière. '
        'N\'hésite pas à reformuler ta question, ou explore les simulateurs '
        'pour des estimations chiffrées.\n\n'
        '_${ComplianceGuard.standardDisclaimer}_';
  }

  /// Message d'accueil initial du coach
  static String initialGreeting(CoachProfile profile) {
    final firstName = profile.firstName ?? 'utilisateur';
    return 'Bonjour $firstName ! Je suis ton coach financier MINT. '
        'Je peux t\'aider a comprendre ta prevoyance, tes impots, ou ta trajectoire. '
        'Que veux-tu explorer ?';
  }

  /// Suggestions initiales
  static List<String> get initialSuggestions => [
        'Mon score Fitness',
        'Ma trajectoire retraite',
        'Mes deductions fiscales',
        'Mon 3a',
      ];

}

/// Resultat interne du mock (avant guardrails)
class _MockResult {
  final String message;
  final List<String>? suggestedActions;
  final List<RagSource> sources;

  const _MockResult({
    required this.message,
    this.suggestedActions,
    this.sources = const [],
  });
}

