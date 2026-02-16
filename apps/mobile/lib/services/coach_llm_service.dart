import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/financial_fitness_service.dart';
import 'package:mint_mobile/services/forecaster_service.dart';

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
// Pour l'instant : mock implementation (reponses pre-faites).
// Le vrai appel HTTP est structure mais commente (TODO).
// ────────────────────────────────────────────────────────────

/// Fournisseur LLM supporte
enum LlmProvider { openai, anthropic }

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
          'claude-3-sonnet-20240229',
          'claude-3-haiku-20240307',
          'claude-3-opus-20240229',
        ];
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

  const ChatMessage({
    required this.role,
    required this.content,
    required this.timestamp,
    this.suggestedActions,
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
  final bool wasFiltered;

  const CoachResponse({
    required this.message,
    this.suggestedActions,
    required this.disclaimer,
    this.wasFiltered = false,
  });
}

/// Service de chat LLM pour le Coach MINT
class CoachLlmService {
  /// Disclaimer standard
  static const _disclaimer =
      'Outil educatif — ne constitue pas un conseil financier. LSFin.';

  /// Termes bannis (jamais dans une reponse user-facing)
  static const _bannedTerms = [
    'garanti',
    'certain',
    'assuré',
    'assure',
    'sans risque',
    'optimal',
    'meilleur',
    'parfait',
  ];

  /// Envoie un message et recoit une reponse du coach
  ///
  /// Le service prepend le system prompt avec le contexte utilisateur,
  /// applique les guardrails, et retourne une CoachResponse.
  static Future<CoachResponse> chat({
    required String userMessage,
    required CoachProfile profile,
    required List<ChatMessage> history,
    required LlmConfig config,
  }) async {
    // Construire le system prompt avec le contexte
    // ignore: unused_local_variable
    final systemPrompt = buildSystemPrompt(profile);

    // TODO: Quand BYOK est configure, appeler le vrai LLM via
    // _callOpenAI(systemPrompt: systemPrompt, ...) ou _callAnthropic(...)
    // Pour l'instant, utiliser les reponses mock
    final rawResponse = _getMockResponse(
      userMessage: userMessage,
      profile: profile,
    );

    // Appliquer les guardrails
    final filtered = _applyGuardrails(rawResponse);

    return CoachResponse(
      message: filtered.message,
      suggestedActions: filtered.suggestedActions,
      disclaimer: _disclaimer,
      wasFiltered: filtered.wasFiltered,
    );
  }

  /// Construit le system prompt avec le contexte utilisateur
  static String buildSystemPrompt(CoachProfile profile) {
    // Calculer le score et la projection pour enrichir le contexte
    final score = FinancialFitnessService.calculate(profile: profile);
    final projection = ForecasterService.project(
      profile: profile,
      targetDate: profile.goalA.targetDate,
    );

    final firstName = profile.firstName ?? 'utilisateur';
    final age = profile.age;
    final canton = profile.canton;
    final globalScore = score.global;
    final budgetScore = score.budget.score;
    final prevoyanceScore = score.prevoyance.score;
    final patrimoineScore = score.patrimoine.score;
    final capitalBase = projection.base.capitalFinal.toStringAsFixed(0);
    final tauxRemplacement =
        (projection.tauxRemplacementBase * 100).toStringAsFixed(1);

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
        '- Tu NE dis JAMAIS : "garanti", "certain", "assure", "sans risque", "optimal", "meilleur", "parfait".');
    buffer.writeln(
        '- Tu ajoutes toujours un disclaimer si tu parles de projections.');
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
    final projection = ForecasterService.project(
      profile: profile,
      targetDate: profile.goalA.targetDate,
    );
    final tauxRemplacement =
        (projection.tauxRemplacementBase * 100).toStringAsFixed(1);

    if (lower.contains('3a')) {
      return _MockResult(
        message:
            'Ton plafond 3a est de 7\'258 CHF/an. Tu as encore de la marge pour optimiser. Pense a verser avant fin decembre !',
        suggestedActions: [
          'Simuler un versement 3a',
          'Voir mes comptes 3a',
        ],
      );
    }

    if (lower.contains('lpp') || lower.contains('rachat')) {
      return _MockResult(
        message:
            'Avec ta lacune LPP actuelle, un rachat pourrait te faire economiser sur tes impots. Simule l\'impact avec le simulateur rachat LPP.',
        suggestedActions: [
          'Simuler un rachat LPP',
          'Comprendre le rachat LPP',
        ],
      );
    }

    if (lower.contains('retraite')) {
      return _MockResult(
        message:
            'D\'apres ta trajectoire actuelle, ton taux de remplacement estime est de $tauxRemplacement%. La cible generalement recommandee est entre 60% et 80%.',
        suggestedActions: [
          'Voir ma trajectoire',
          'Explorer les scenarios',
        ],
      );
    }

    if (lower.contains('impot') || lower.contains('fiscal')) {
      return _MockResult(
        message:
            'La declaration d\'impots dans le canton ${profile.canton} — n\'oublie pas de deduire tes versements 3a et tes rachats LPP !',
        suggestedActions: [
          'Deductions fiscales possibles',
          'Simuler l\'impact fiscal',
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

  /// Applique les guardrails de filtrage
  static _FilterResult _applyGuardrails(_MockResult raw) {
    var message = raw.message;
    var wasFiltered = false;

    // Verifier les termes bannis
    for (final term in _bannedTerms) {
      if (message.toLowerCase().contains(term.toLowerCase())) {
        // Remplacer le terme banni par une alternative
        message = message.replaceAll(
          RegExp(term, caseSensitive: false),
          '[terme retire]',
        );
        wasFiltered = true;
      }
    }

    return _FilterResult(
      message: message,
      suggestedActions: raw.suggestedActions,
      wasFiltered: wasFiltered,
    );
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

  // TODO: Implementer le vrai appel HTTP quand BYOK est configure
  //
  // static Future<String> _callOpenAI({
  //   required String systemPrompt,
  //   required List<ChatMessage> messages,
  //   required LlmConfig config,
  // }) async {
  //   final uri = Uri.parse('https://api.openai.com/v1/chat/completions');
  //   final body = {
  //     'model': config.model,
  //     'messages': [
  //       {'role': 'system', 'content': systemPrompt},
  //       ...messages.map((m) => {'role': m.role, 'content': m.content}),
  //     ],
  //     'temperature': 0.7,
  //     'max_tokens': 500,
  //   };
  //   final response = await http.post(
  //     uri,
  //     headers: {
  //       'Authorization': 'Bearer ${config.apiKey}',
  //       'Content-Type': 'application/json',
  //     },
  //     body: jsonEncode(body),
  //   );
  //   if (response.statusCode != 200) {
  //     throw Exception('OpenAI API error: ${response.statusCode}');
  //   }
  //   final data = jsonDecode(response.body);
  //   return data['choices'][0]['message']['content'] as String;
  // }
  //
  // static Future<String> _callAnthropic({
  //   required String systemPrompt,
  //   required List<ChatMessage> messages,
  //   required LlmConfig config,
  // }) async {
  //   final uri = Uri.parse('https://api.anthropic.com/v1/messages');
  //   final body = {
  //     'model': config.model,
  //     'system': systemPrompt,
  //     'messages': messages.map((m) => {'role': m.role, 'content': m.content}).toList(),
  //     'max_tokens': 500,
  //   };
  //   final response = await http.post(
  //     uri,
  //     headers: {
  //       'x-api-key': config.apiKey,
  //       'anthropic-version': '2023-06-01',
  //       'Content-Type': 'application/json',
  //     },
  //     body: jsonEncode(body),
  //   );
  //   if (response.statusCode != 200) {
  //     throw Exception('Anthropic API error: ${response.statusCode}');
  //   }
  //   final data = jsonDecode(response.body);
  //   return data['content'][0]['text'] as String;
  // }
}

/// Resultat interne du mock (avant guardrails)
class _MockResult {
  final String message;
  final List<String>? suggestedActions;

  const _MockResult({
    required this.message,
    this.suggestedActions,
  });
}

/// Resultat du filtrage guardrails
class _FilterResult {
  final String message;
  final List<String>? suggestedActions;
  final bool wasFiltered;

  const _FilterResult({
    required this.message,
    this.suggestedActions,
    this.wasFiltered = false,
  });
}
