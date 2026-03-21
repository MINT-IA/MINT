import 'package:mint_mobile/models/budget_snapshot.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/response_card.dart';
import 'package:mint_mobile/services/coach/coach_models.dart';
import 'package:mint_mobile/services/coach/coach_orchestrator.dart';
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

/// Which AI tier produced a coach message.
enum ChatTier {
  /// On-device SLM (Gemma 3n) — privacy-first, zero network.
  slm,

  /// Cloud BYOK LLM (OpenAI / Anthropic / Mistral).
  byok,

  /// Static fallback — no AI.
  fallback,

  /// Not applicable (user messages, system messages).
  none,
}

/// Message dans l'historique de conversation
class ChatMessage {
  final String role; // 'user', 'assistant', 'system'
  final String content;
  final DateTime timestamp;
  final List<String>? suggestedActions;
  final List<RagSource> sources;
  final List<String> disclaimers;
  final ChatTier tier;

  /// Response cards contextuelles (Phase 1).
  /// Affichees en strip horizontale scrollable dans le chat.
  final List<ResponseCard> responseCards;

  /// Original user message that triggered this assistant response (S56).
  /// Used to build rich inline widgets at render time.
  /// Null for user/system messages and greeting.
  final String? userQuery;

  /// Rich widget chosen by Claude via tool calling (S56).
  /// Rendered inline in the chat below the text response.
  final Map<String, dynamic>? widgetCall;

  const ChatMessage({
    required this.role,
    required this.content,
    required this.timestamp,
    this.suggestedActions,
    this.sources = const [],
    this.disclaimers = const [],
    this.tier = ChatTier.none,
    this.responseCards = const [],
    this.userQuery,
    this.widgetCall,
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
  /// Délègue à [CoachOrchestrator] pour la chaîne SLM → BYOK → mock.
  /// ComplianceGuard est appliqué centralement dans l'orchestrateur.
  ///
  /// Si BYOK est configure (config.hasApiKey), route via le backend RAG
  /// pour obtenir des reponses groundees avec sources verifiables.
  /// Sinon, utilise les reponses mock enrichies de references legales.
  static Future<CoachResponse> chat({
    required String userMessage,
    required CoachProfile profile,
    required List<ChatMessage> history,
    required LlmConfig config,
    String? memoryBlock,
  }) async {
    final coachCtx = _buildCoachContext(profile);

    // Delegate to CoachOrchestrator (SLM → BYOK → fallback chain).
    // If SLM is available, it will be tried first (zero-network, privacy-first).
    // BYOK is passed when config.hasApiKey, otherwise skipped.
    // memoryBlock (S58) provides lifecycle, goals, and conversation history context.
    final orchestratorResponse = await CoachOrchestrator.generateChat(
      userMessage: userMessage,
      history: history,
      ctx: coachCtx,
      byokConfig: config.hasApiKey ? config : null,
      memoryBlock: memoryBlock,
    );

    // If orchestrator returned a non-fallback response (SLM or BYOK succeeded),
    // return it directly.
    // The mock path is used as the final fallback by CoachOrchestrator itself,
    // but we check here to add suggested actions via _inferSuggestedActions.
    return CoachResponse(
      message: orchestratorResponse.message,
      suggestedActions: orchestratorResponse.wasFiltered
          ? null
          : _inferSuggestedActions(userMessage),
      disclaimer: orchestratorResponse.disclaimer,
      sources: orchestratorResponse.sources,
      disclaimers: orchestratorResponse.disclaimers,
      wasFiltered: orchestratorResponse.wasFiltered,
    );
  }

  /// Mode RAG direct (BYOK configure) — conservé pour compatibilité.
  ///
  /// Appelé par l'orchestrateur via [CoachOrchestrator._tryByokChat].
  /// Reste accessible pour les tests unitaires de la couche RAG.
  @Deprecated('Utilise CoachOrchestrator.generateChat() à la place.')
  static Future<CoachResponse> chatViaRagDirect({
    required String userMessage,
    required CoachProfile profile,
    required LlmConfig config,
    required List<ChatMessage> history,
  }) async {
    return _chatViaRag(
      userMessage: userMessage,
      profile: profile,
      config: config,
      history: history,
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
    final relevant = history.where((m) => m.isUser || m.isAssistant).toList();

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

  /// Converts an exact CHF amount to a privacy-safe range string.
  ///
  /// CoachContext MUST NEVER contain exact salary, savings, debts, NPA,
  /// or employer (CLAUDE.md § 6). This helper rounds values to broad
  /// ranges so the LLM receives only approximate magnitudes.
  static String _toRange(double value) {
    if (value <= 0) return '0 CHF';
    final abs = value.abs();
    final int rounded;
    if (abs < 1000) {
      rounded = ((abs / 500).round() * 500).clamp(500, 999).toInt();
    } else if (abs < 10000) {
      rounded = (abs / 1000).round() * 1000;
    } else if (abs < 100000) {
      rounded = (abs / 5000).round() * 5000;
    } else if (abs < 1000000) {
      rounded = (abs / 25000).round() * 25000;
    } else {
      rounded = (abs / 100000).round() * 100000;
    }
    // Format with apostrophe thousands separator
    final str = rounded.toString();
    final buf = StringBuffer();
    for (var i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buf.write("'");
      buf.write(str[i]);
    }
    return '~$buf CHF';
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
      parts.add('Salaire brut : ${_toRange(profile.salaireBrutMensuel)}/mois');
    }

    // Prevoyance
    final prev = profile.prevoyance;
    if (prev.totalEpargne3a > 0) {
      parts.add('Avoir 3a : ${_toRange(prev.totalEpargne3a)}');
    }
    if (prev.nombre3a > 0) {
      parts.add('Nombre de comptes 3a : ${prev.nombre3a}');
    }
    if (prev.avoirLppTotal != null && prev.avoirLppTotal! > 0) {
      parts.add('Avoir LPP : ${_toRange(prev.avoirLppTotal!)}');
    }
    if (prev.lacuneRachatRestante > 0) {
      parts.add('Lacune rachat LPP : ${_toRange(prev.lacuneRachatRestante)}');
    }

    // Patrimoine + dettes
    final pat = profile.patrimoine;
    if (pat.totalPatrimoine > 0) {
      parts.add('Patrimoine : ${_toRange(pat.totalPatrimoine)}');
    }
    if (profile.dettes.totalDettes > 0) {
      parts.add('Dettes : ${_toRange(profile.dettes.totalDettes)}');
    }

    // Depenses
    final dep = profile.depenses;
    if (dep.loyer > 0) {
      parts.add('Loyer : ${_toRange(dep.loyer)}/mois');
    }
    if (dep.assuranceMaladie > 0) {
      parts.add('Assurance maladie : ${_toRange(dep.assuranceMaladie)}/mois');
    }

    // Versements planifies
    if (profile.plannedContributions.isNotEmpty) {
      final contribs = profile.plannedContributions
          .map((c) => '${c.label} (${_toRange(c.amount)}/mois)')
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
        return '$month: ${_toRange(ci.totalVersements)}';
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
          'Capital projete retraite : ${_toRange(proj.base.capitalFinal)}');
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
  /// Prompt constructed here — see prompt_registry.dart for base prompts.
  /// This prompt uses CoachProfile + FinancialFitnessService + ForecasterService
  /// which differ from PromptRegistry's CoachContext model.
  ///
  /// CRIT #6: wrapped in try-catch to prevent crash on incomplete profiles.
  static String buildSystemPrompt(
    CoachProfile profile, {
    BudgetSnapshot? budgetSnapshot,
  }) {
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
      capitalBase = _toRange(projection.base.capitalFinal);
      tauxRemplacement = projection.tauxRemplacementBase.toStringAsFixed(1);
    } catch (_) {}

    final buffer = StringBuffer();
    buffer.writeln(
        'Tu es le coach financier MINT. Tu aides $firstName a comprendre sa situation financiere suisse.');
    buffer.writeln();

    // ── VOICE SYSTEM (5 pillars: Calme, Precis, Fin, Rassurant, Net) ──
    buffer.writeln('VOIX MINT (les 5 piliers) :');
    buffer.writeln(
        '- CALME : Tu parles calmement, jamais dans l\'urgence. Le ton ne monte pas, meme quand le chiffre est mauvais.');
    buffer.writeln(
        '- PRECIS : Chaque mot est choisi. Pas de remplissage, pas de tournure vide. Nette et precise, sans jargon inutile.');
    buffer.writeln(
        '- FIN : Un sourire en coin, jamais un rire gras. L\'esprit nait de l\'observation du quotidien suisse, pas de la blague. Understatement romand.');
    buffer.writeln(
        '- RASSURANT : "On va y arriver, voici par ou commencer." Accompagne sans porter. Jamais infantilisant, jamais condescendant.');
    buffer.writeln(
        '- NET : Dis la verite, meme inconfortable, avec tact. Pas de promesse, pas de flou.');
    buffer.writeln();

    buffer.writeln('REGLES ABSOLUES :');
    buffer.writeln(
        '- Tu NE calcules JAMAIS. Tu utilises uniquement les donnees fournies par le systeme.');
    buffer
        .writeln('- Tu NE donnes JAMAIS de conseil financier. Tu es educatif.');
    buffer.writeln(
        '- Tu dis toujours "consulte un·e specialiste" pour les decisions importantes.');
    buffer.writeln('- Tu parles en francais, tu tutoies.');
    buffer.writeln(
        '- Tu cites TOUJOURS tes sources legales (LPP art. X, OPP3 art. Y, LIFD art. Z, etc.).');
    buffer.writeln(
        '- Tu NE dis JAMAIS : "garanti", "certain", "assure", "sans risque", "optimal", "meilleur", "parfait".');
    buffer.writeln(
        '- Tu NE dis JAMAIS : "Voici ta situation", "N\'hesite pas", "Excellent travail", "Bravo", "Felicitations".');
    buffer.writeln(
        '- Tu ajoutes toujours un disclaimer si tu parles de projections.');
    buffer.writeln();

    // ── FINANCIAL LITERACY ADAPTATION ──
    final literacy = profile.financialLiteracyLevel;
    buffer.writeln('ADAPTATION AU NIVEAU :');
    switch (literacy) {
      case FinancialLiteracyLevel.beginner:
        buffer.writeln(
            '- Niveau NOVICE : phrases courtes, pas de sigle sans explication, metaphores concretes.');
        buffer.writeln(
            '- Exemple : "Le 2e pilier, c\'est l\'argent que ton employeur et toi mettez de cote chaque mois."');
        buffer.writeln(
            '- Evite les references legales brutes. Explique d\'abord, cite ensuite.');
      case FinancialLiteracyLevel.intermediate:
        buffer.writeln(
            '- Niveau AUTONOME : sigles OK, chiffres directs, moins de contexte.');
        buffer.writeln(
            '- Exemple : "Ton taux LPP : 6.8%. Rachat possible : ${_toRange(profile.prevoyance.rachatMaximum?.toDouble() ?? 0)}."');
      case FinancialLiteracyLevel.advanced:
        buffer.writeln(
            '- Niveau EXPERT : references legales directes, scenarios avances, hypotheses editables.');
        buffer.writeln(
            '- Exemple : "LAVS art. 35 : cap 150% en couple. Sensibilite : ±2% rendement inverse le resultat."');
        buffer.writeln(
            '- Tu peux aller plus en profondeur technique. L\'utilisateur comprend les mecanismes.');
    }
    buffer.writeln();

    buffer.writeln('STRUCTURE DE TA REPONSE :');
    buffer.writeln('- Commence par le chiffre ou le fait. Explique apres.');
    buffer
        .writeln('- Si pertinent, liste les options avec leur impact en CHF.');
    buffer.writeln(
        '- Propose 1-3 actions concretes et prioritaires que l\'utilisateur peut faire cette semaine.');
    buffer.writeln('- Mentionne les risques et points d\'attention.');
    buffer
        .writeln('- Cite tes sources legales (LPP art. X, LIFD art. Y, etc.).');
    buffer.writeln(
        '- Termine par un disclaimer : "Ceci est un outil educatif, ne constitue pas un conseil financier."');
    buffer.writeln();
    buffer.writeln('CONTEXTE UTILISATEUR :');
    buffer.writeln('- Prenom : $firstName, Age : $age, Canton : $canton');
    buffer.writeln(
        '- Score Fitness : $globalScore/100 (Budget: $budgetScore, Prevoyance: $prevoyanceScore, Patrimoine: $patrimoineScore)');
    buffer.writeln('- Capital projete base : $capitalBase');
    buffer.writeln('- Taux de remplacement estime : $tauxRemplacement%');

    // Ajouter le contexte conjoint si applicable
    if (profile.isCouple && profile.conjoint != null) {
      final conj = profile.conjoint!;
      final conjFirstName = conj.firstName ?? 'conjoint·e';
      final conjAge = conj.age ?? 0;
      buffer.writeln('- Conjoint·e : $conjFirstName, $conjAge ans');
      if (conj.nationality != null) {
        buffer.write('- Nationalite conjoint·e : ${conj.nationality}');
        if (conj.isFatcaResident) {
          buffer.write(' (FATCA)');
        }
        buffer.writeln();
      }
    }

    // ── BUDGET VIVANT (from BudgetSnapshot) ──
    if (budgetSnapshot != null) {
      buffer.writeln();
      buffer.writeln('BUDGET VIVANT :');
      buffer.writeln(
          '- Libre aujourd\'hui : CHF ${budgetSnapshot.present.monthlyFree.round()}/mois');
      if (budgetSnapshot.retirement != null) {
        buffer.writeln(
            '- Libre retraite : CHF ${budgetSnapshot.retirement!.monthlyFree.round()}/mois');
      }
      if (budgetSnapshot.gap != null) {
        buffer.writeln(
            '- Ecart : CHF ${budgetSnapshot.gap!.monthlyGap.round()}/mois');
      }
      buffer.writeln('- Confiance : ${budgetSnapshot.confidenceScore}%');
      if (budgetSnapshot.capImpact != null) {
        if (budgetSnapshot.capImpact!.now != null) {
          buffer.writeln(
              '- Impact court terme : ${budgetSnapshot.capImpact!.now}');
        }
        if (budgetSnapshot.capImpact!.later != null) {
          buffer.writeln(
              '- Impact long terme : ${budgetSnapshot.capImpact!.later}');
        }
      }
      buffer.writeln(
          'Parle en CHF/mois de marge, pas en pourcentages abstraits.');
    }

    return buffer.toString();
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
    return 'Je préfère rester net sur celle-ci. '
        'Reformule ta question, ou passe par un simulateur pour un chiffre plus direct.\n\n'
        '_${ComplianceGuard.standardDisclaimer}_';
  }

  /// Message d'accueil initial du coach
  static String initialGreeting(CoachProfile profile) {
    final firstName = profile.firstName ?? 'utilisateur';
    return 'Salut $firstName. '
        'Pose ta question, je regarde ce que tes chiffres racontent.';
  }

  /// Suggestions initiales
  static List<String> get initialSuggestions => [
        'Ma retraite, concrètement',
        'Où alléger mes impôts',
        'Simuler un versement 3a',
        'Voir où j\'en suis',
      ];
}
