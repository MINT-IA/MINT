import 'package:flutter/foundation.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/response_card.dart';
import 'package:mint_mobile/models/sequence_message_payload.dart';
import 'package:mint_mobile/services/coach/coach_models.dart';
// FIX-P1-7: Removed direct import of coach_orchestrator.dart to break
// circular dependency (coach_llm ↔ orchestrator). The orchestrator is
// now resolved lazily at call time via _resolveOrchestrator().
import 'package:mint_mobile/services/financial_fitness_service.dart';
import 'package:mint_mobile/services/forecaster_service.dart';
import 'package:mint_mobile/services/rag_service.dart' show RagSource, RagToolCall;

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

// ────────────────────────────────────────────────────────────
//  ROUTE TOOL PAYLOAD — S58 route_to_screen tool_use
// ────────────────────────────────────────────────────────────

/// Payload from a `route_to_screen` tool_use block returned by Claude.
///
/// Produced by [_parseRouteToolUse] in CoachChatScreen when the LLM response
/// contains a structured `[ROUTE_TO_SCREEN:{...}]` marker.
///
/// The [RoutePlanner] processes [intent] + [confidence] to produce a
/// [RouteDecision]. The [contextMessage] is shown in the [RouteSuggestionCard].
class RouteToolPayload {
  /// The semantic intent tag (e.g. 'retirement_choice').
  final String intent;

  /// LLM confidence in the intent (0.0–1.0).
  final double confidence;

  /// The coach's narrative message explaining why this screen is relevant.
  /// Shown verbatim in the RouteSuggestionCard.
  final String contextMessage;

  const RouteToolPayload({
    required this.intent,
    required this.confidence,
    required this.contextMessage,
  });
}

// ────────────────────────────────────────────────────────────
//  DOCUMENT TOOL PAYLOAD — generate_document tool_use
// ────────────────────────────────────────────────────────────

/// Payload from a `generate_document` tool_use block returned by Claude.
///
/// Produced by [_parseDocumentToolUse] in CoachChatScreen when the LLM response
/// contains a structured `[GENERATE_DOCUMENT:{...}]` marker.
///
/// The Flutter app calls [FormPrefillService] or [LetterGenerationService]
/// based on [documentType], validates via [AgentValidationGate], then renders
/// the result as a downloadable card in the chat.
class DocumentToolPayload {
  /// The type of document to generate.
  ///
  /// One of: 'fiscal_declaration', 'pension_fund_letter', 'lpp_buyback_request'.
  final String documentType;

  /// Brief context from the LLM about what the user asked for.
  final String context;

  const DocumentToolPayload({
    required this.documentType,
    required this.context,
  });
}

/// Message dans l'historique de conversation
class ChatMessage {
  /// Schema version for migration support.
  /// Increment when breaking changes are made to serialization format.
  static const int schemaVersion = 1;

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

  /// Route suggestion payload from a `route_to_screen` tool_use block (S58).
  ///
  /// Non-null when the message carries a RouteSuggestionCard to render.
  /// The card is rendered in CoachChatScreen._buildCoachBubble.
  final RouteToolPayload? routePayload;

  /// Document generation payload from a `generate_document` tool_use block.
  ///
  /// Non-null when the message carries a generated document card to render.
  /// The card is rendered in CoachChatScreen._buildDocumentCard.
  final DocumentToolPayload? documentPayload;

  /// Rich tool calls to render inline via [WidgetRenderer].
  /// These are display tools like show_fact_card, show_budget_snapshot,
  /// show_score_gauge, ask_user_input, etc.
  final List<RagToolCall> richToolCalls;

  /// Sequence progress payload for rendering a SequenceProgressCard.
  /// Non-null when the message carries a guided sequence step transition.
  final SequenceMessagePayload? sequencePayload;

  const ChatMessage({
    required this.role,
    required this.content,
    required this.timestamp,
    this.suggestedActions,
    this.sources = const [],
    this.disclaimers = const [],
    this.tier = ChatTier.none,
    this.responseCards = const [],
    this.routePayload,
    this.documentPayload,
    this.richToolCalls = const [],
    this.sequencePayload,
  });

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';
  bool get isSystem => role == 'system';

  /// Whether this message carries a route suggestion card.
  bool get hasRoutePayload => routePayload != null;

  /// Whether this message carries a generated document card.
  bool get hasDocumentPayload => documentPayload != null;

  /// Whether this message carries rich tool calls for inline rendering.
  bool get hasRichToolCalls => richToolCalls.isNotEmpty;

  /// Whether this message carries a sequence progress card.
  bool get hasSequencePayload => sequencePayload != null;
}

/// Reponse du coach LLM
class CoachResponse {
  final String message;
  final List<String>? suggestedActions;
  final String disclaimer;
  final List<RagSource> sources;
  final List<String> disclaimers;
  final bool wasFiltered;

  /// Structured tool_calls from the backend LLM (e.g. show_fact_card, set_goal).
  final List<RagToolCall> toolCalls;

  /// Backend-piloted follow-up question chips (max 2).
  ///
  /// Populated by the LLM via the `suggest_followups` internal tool on the
  /// authenticated path, or by the `<followups>` JSON block on the
  /// anonymous path. Never inferred client-side. See
  /// feedback_chat_must_be_silent.md.
  final List<String> followUpQuestions;

  const CoachResponse({
    required this.message,
    this.suggestedActions,
    required this.disclaimer,
    this.sources = const [],
    this.disclaimers = const [],
    this.wasFiltered = false,
    this.toolCalls = const [],
    this.followUpQuestions = const [],
  });
}

/// Signature for the orchestrator's generateChat, used to break the
/// circular dependency between coach_llm_service ↔ coach_orchestrator.
typedef OrchestratorChatFn = Future<CoachResponse> Function({
  required String userMessage,
  required List<ChatMessage> history,
  required CoachContext ctx,
  LlmConfig? byokConfig,
  String? memoryBlock,
  String language,
  int cashLevel,
});

/// Service de chat LLM pour le Coach MINT
class CoachLlmService {
  /// FIX-P1-7: Late-bound orchestrator function to break circular import.
  /// Set once at app init by [CoachOrchestrator.init()] or by tests.
  static OrchestratorChatFn? _orchestratorChatFn;

  /// Register the orchestrator's generateChat function.
  /// Called once at startup (e.g. from main.dart or CoachOrchestrator.init).
  static void registerOrchestrator(OrchestratorChatFn fn) {
    _orchestratorChatFn = fn;
  }

  /// Envoie un message et recoit une reponse du coach
  ///
  /// Delegates to the registered orchestrator for the SLM → BYOK → mock chain.
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
    Map<String, dynamic>? enrichedContext,
    String language = 'fr',
    int cashLevel = 3,
  }) async {
    final coachCtx = _buildCoachContext(profile);

    // FIX-P1-7: Use late-bound orchestrator instead of direct import.
    if (_orchestratorChatFn == null) {
      // Graceful fallback if orchestrator not yet registered.
      return const CoachResponse(
        message: 'Service en cours d\'initialisation. Reessaie dans un instant.',
        disclaimer: 'Outil educatif — ne constitue pas un conseil financier. LSFin.',
      );
    }

    final orchestratorResponse = await _orchestratorChatFn!(
      userMessage: userMessage,
      history: history,
      ctx: coachCtx,
      byokConfig: config.hasApiKey ? config : null,
      memoryBlock: memoryBlock,
      language: language,
      cashLevel: cashLevel,
    );

    // suggestedActions are now backend-piloted: populated from the coach's
    // `suggest_followups` tool (coach/chat) or `<followups>` JSON block
    // (anonymous/chat). Never inferred client-side — see Phase D.
    //
    // STAB-03 / STAB-04: re-expose `toolCalls` on the return so the chat
    // screen can dispatch structured tool_use blocks (generate_financial_plan,
    // record_check_in, route_to_screen, generate_document) to WidgetRenderer.
    // Before this fix, the orchestrator populated toolCalls but this rebuild
    // silently dropped them — the canonical "facade sans cablage" symptom.
    return CoachResponse(
      message: orchestratorResponse.message,
      suggestedActions: null,
      disclaimer: orchestratorResponse.disclaimer,
      sources: orchestratorResponse.sources,
      disclaimers: orchestratorResponse.disclaimers,
      wasFiltered: orchestratorResponse.wasFiltered,
      toolCalls: orchestratorResponse.toolCalls,
      followUpQuestions: orchestratorResponse.followUpQuestions,
    );
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

  /// Construit le system prompt avec le contexte utilisateur.
  ///
  /// Prompt constructed here — see prompt_registry.dart for base prompts.
  /// This prompt uses CoachProfile + FinancialFitnessService + ForecasterService
  /// which differ from PromptRegistry's CoachContext model.
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
    } catch (e) {
      debugPrint('[CoachLLM] System prompt FRI error: $e');
    }

    try {
      final projection = ForecasterService.project(
        profile: profile,
        targetDate: profile.goalA.targetDate,
      );
      capitalBase = _toRange(projection.base.capitalFinal);
      tauxRemplacement = projection.tauxRemplacementBase.toStringAsFixed(1);
    } catch (e) {
      debugPrint('[CoachLLM] System prompt projection error: $e');
    }

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
    } catch (e) {
      debugPrint('[CoachLLM] CoachContext FRI error: $e');
    }

    try {
      final proj = ForecasterService.project(
        profile: profile,
        targetDate: profile.goalA.targetDate,
      );
      final cap = proj.base.capitalFinal;
      final taux = proj.tauxRemplacementBase;
      if (cap.isFinite && cap > 0) knownValues['capital_final'] = cap;
      if (taux.isFinite && taux > 0) knownValues['replacement_ratio'] = taux;
    } catch (e) {
      debugPrint('[CoachLLM] CoachContext projection error: $e');
    }

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

  /// Message d'accueil initial du coach.
  ///
  /// Requires [S] localizations — callers must pass the context's [S] instance.
  static String initialGreeting(CoachProfile profile, S l) {
    final firstName = profile.firstName ?? l.coachFallbackName;
    return l.coachGreetingDefault(firstName, '');
  }

}
