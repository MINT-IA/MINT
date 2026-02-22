import 'dart:convert';

import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/coach_llm_service.dart';
import 'package:mint_mobile/services/coaching_service.dart';
import 'package:mint_mobile/services/financial_fitness_service.dart';
import 'package:mint_mobile/services/forecaster_service.dart';
import 'package:mint_mobile/services/rag_service.dart';
import 'package:mint_mobile/services/streak_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ────────────────────────────────────────────────────────────
//  COACH NARRATIVE SERVICE — Coach AI Layer / T1
// ────────────────────────────────────────────────────────────
//
// Le cerveau du Coach Layer. Genere tout le contenu narratif
// du dashboard en un seul appel LLM (ou via templates statiques
// si pas de BYOK).
//
// DUAL MODE :
//   - BYOK configure → appel LLM via RagService
//   - Pas de BYOK  → templates statiques (zero regression)
//
// CACHE :
//   - SharedPreferences, cle "coach_narrative_{yyyy-MM-dd}"
//   - TTL 24h, invalide si nouveau check-in
//
// GUARDRAILS :
//   - Filtrage des termes bannis (identique a coach_llm_service.dart)
//   - Disclaimer obligatoire
//   - Fallback vers statique si le LLM echoue
//
// Aucun terme banni : garanti, certain, assure, sans risque,
//                     optimal, meilleur, parfait.
// ────────────────────────────────────────────────────────────

/// Resultat narratif du Coach Layer.
///
/// Contient tous les textes narratifs du dashboard,
/// generes soit par le LLM (BYOK) soit en mode statique.
class CoachNarrative {
  /// Salutation personnalisee ("Bonjour Julien")
  final String greeting;

  /// Resume du score avec contexte ("62/100 — Bien ! Tu es sur la bonne voie.")
  final String scoreSummary;

  /// Message de tendance enrichi ("En progression — continue comme ca")
  final String trendMessage;

  /// Tip principal enrichi (le top tip avec narration personnalisee)
  final String? topTipNarrative;

  /// Alerte urgente si applicable ("Il reste 28 jours pour ton 3a")
  final String? urgentAlert;

  /// Message milestone si nouveau ("Bravo ! Tu as atteint CHF 100k de patrimoine")
  final String? milestoneMessage;

  /// Narration des scenarios Forecaster (3 paragraphes)
  final List<String>? scenarioNarrations;

  /// Source (llm ou static) pour debug
  final bool isLlmGenerated;

  /// Timestamp de generation
  final DateTime generatedAt;

  const CoachNarrative({
    required this.greeting,
    required this.scoreSummary,
    required this.trendMessage,
    this.topTipNarrative,
    this.urgentAlert,
    this.milestoneMessage,
    this.scenarioNarrations,
    required this.isLlmGenerated,
    required this.generatedAt,
  });

  /// Serialise en JSON pour persistence dans SharedPreferences.
  Map<String, dynamic> toJson() => {
        'greeting': greeting,
        'scoreSummary': scoreSummary,
        'trendMessage': trendMessage,
        'topTipNarrative': topTipNarrative,
        'urgentAlert': urgentAlert,
        'milestoneMessage': milestoneMessage,
        'scenarioNarrations': scenarioNarrations,
        'isLlmGenerated': isLlmGenerated,
        'generatedAt': generatedAt.toIso8601String(),
      };

  /// Deserialise depuis JSON (cache SharedPreferences).
  factory CoachNarrative.fromJson(Map<String, dynamic> json) {
    return CoachNarrative(
      greeting: json['greeting'] as String? ?? '',
      scoreSummary: json['scoreSummary'] as String? ?? '',
      trendMessage: json['trendMessage'] as String? ?? '',
      topTipNarrative: json['topTipNarrative'] as String?,
      urgentAlert: json['urgentAlert'] as String?,
      milestoneMessage: json['milestoneMessage'] as String?,
      scenarioNarrations: (json['scenarioNarrations'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      isLlmGenerated: json['isLlmGenerated'] as bool? ?? false,
      generatedAt: json['generatedAt'] != null
          ? DateTime.parse(json['generatedAt'] as String)
          : DateTime.now(),
    );
  }
}

/// Mode de rendu des narrations coach dans l'UI.
enum CoachNarrativeMode { concise, detailed }

/// Le Coach Layer central. Genere tout le contenu narratif du dashboard
/// en un seul appel LLM (ou via templates statiques si pas de BYOK).
///
/// Usage :
/// ```dart
/// final narrative = await CoachNarrativeService.generate(
///   profile: profile,
///   scoreHistory: scoreHistory,
///   tips: tips,
///   byokConfig: config, // null si pas BYOK
/// );
/// // narrative.greeting, narrative.scoreSummary, etc.
/// ```
class CoachNarrativeService {
  CoachNarrativeService._();

  // ════════════════════════════════════════════════════════════════
  //  CONSTANTS
  // ════════════════════════════════════════════════════════════════

  static const _cacheKeyPrefix = 'coach_narrative';
  static const _cacheTtlHours = 24;

  /// Disclaimer standard
  static const disclaimer =
      'Outil educatif — ne constitue pas un conseil financier. LSFin.';

  /// Termes bannis (identique a coach_llm_service.dart)
  static const _bannedTerms = [
    'garanti',
    'certain',
    'assuré',
    'assure',
    'sans risque',
    'optimal',
    'optimale',
    'meilleur',
    'parfait',
  ];

  /// Applique un mode de rendu a un texte narratif.
  /// - detailed: texte complet
  /// - concise: premiere phrase utile (ou coupe a ~120 chars)
  static String applyDetailMode(
    String text,
    CoachNarrativeMode mode,
  ) {
    final clean = text.trim();
    if (mode == CoachNarrativeMode.detailed || clean.isEmpty) {
      return clean;
    }
    final parts = clean.split(RegExp(r'(?<=[.!?])\s+'));
    if (parts.isNotEmpty && parts.first.trim().isNotEmpty) {
      final first = parts.first.trim();
      if (first.length <= 140) return first;
    }
    if (clean.length <= 120) return clean;
    return '${clean.substring(0, 117).trim()}...';
  }

  // ════════════════════════════════════════════════════════════════
  //  PUBLIC API
  // ════════════════════════════════════════════════════════════════

  /// Genere le narratif complet du dashboard.
  ///
  /// Si [byokConfig] != null et hasApiKey, utilise le LLM.
  /// Sinon, retourne des templates statiques (comportement actuel).
  /// Le resultat est cache 24h dans SharedPreferences.
  static Future<CoachNarrative> generate({
    required CoachProfile profile,
    required List<Map<String, dynamic>>? scoreHistory,
    required List<CoachingTip> tips,
    LlmConfig? byokConfig,
  }) async {
    // 1. Verifier le cache
    final cached = await _loadFromCache(profile);
    if (cached != null) return cached;

    // 2. Generer le narratif
    CoachNarrative narrative;

    if (byokConfig != null && byokConfig.hasApiKey) {
      // 3. BYOK configure → appel LLM
      try {
        narrative = await _generateViaLlm(
          profile: profile,
          scoreHistory: scoreHistory,
          tips: tips,
          config: byokConfig,
        );
      } catch (_) {
        // 4. Fallback vers statique si LLM echoue (resilience)
        narrative = _generateStatic(
          profile: profile,
          scoreHistory: scoreHistory,
          tips: tips,
        );
      }
    } else {
      // 5. Pas de BYOK → templates statiques
      narrative = _generateStatic(
        profile: profile,
        scoreHistory: scoreHistory,
        tips: tips,
      );
    }

    // 6. Appliquer les guardrails sur TOUS les modes (LLM et statique)
    narrative = _applyGuardrails(narrative);

    // 7. Sauvegarder en cache
    await _saveToCache(narrative, profile);

    return narrative;
  }

  // ════════════════════════════════════════════════════════════════
  //  STATIC GENERATION (zero regression)
  // ════════════════════════════════════════════════════════════════

  /// Genere un narratif statique reproduisant EXACTEMENT
  /// le comportement actuel du dashboard.
  ///
  /// Visible en interne pour les tests.
  static CoachNarrative generateStatic({
    required CoachProfile profile,
    required List<Map<String, dynamic>>? scoreHistory,
    required List<CoachingTip> tips,
  }) {
    return _generateStatic(
      profile: profile,
      scoreHistory: scoreHistory,
      tips: tips,
    );
  }

  static CoachNarrative _generateStatic({
    required CoachProfile profile,
    required List<Map<String, dynamic>>? scoreHistory,
    required List<CoachingTip> tips,
  }) {
    final firstName = profile.firstName ?? 'utilisateur';

    // Score calculation
    FinancialFitnessScore? score;
    try {
      score = FinancialFitnessService.calculate(profile: profile);
    } catch (_) {
      // Graceful fallback if score calculation fails
    }

    // Greeting — reproduit le texte exact du SliverAppBar
    final greeting = 'Bonjour $firstName';

    // Score summary — reproduit le format "{score}/100 — {level.label}"
    final String scoreSummary;
    if (score != null) {
      scoreSummary = '${score.global}/100 — ${score.level.label}';
    } else {
      scoreSummary = 'Score en cours de calcul...';
    }

    // Trend message — reproduit la logique exacte de _buildScoreTrendText()
    final trendMessage = _computeStaticTrendMessage(scoreHistory);

    // Top tip narrative — premier tip si disponible
    final String? topTipNarrative;
    if (tips.isNotEmpty) {
      topTipNarrative = tips.first.message;
    } else {
      topTipNarrative = null;
    }

    // Scenario narrations — fallback statique (T7 sans BYOK)
    List<String>? scenarioNarrations;
    try {
      final projection = ForecasterService.project(profile: profile);
      scenarioNarrations = _buildStaticScenarioNarrations(
        projection: projection,
      );
    } catch (_) {
      // Optional block: keep null if projection cannot be built
      scenarioNarrations = null;
    }

    return CoachNarrative(
      greeting: greeting,
      scoreSummary: scoreSummary,
      trendMessage: trendMessage,
      topTipNarrative: topTipNarrative,
      urgentAlert: null, // Pas d'alerte dans le mode statique actuel
      milestoneMessage: null, // Pas de milestone dans le mode statique actuel
      scenarioNarrations: scenarioNarrations,
      isLlmGenerated: false,
      generatedAt: DateTime.now(),
    );
  }

  static List<String> _buildStaticScenarioNarrations({
    required ProjectionResult projection,
  }) {
    String buildLine(ProjectionScenario s) {
      final monthly = (s.revenuAnnuelRetraite / 12).isFinite
          ? (s.revenuAnnuelRetraite / 12)
          : 0.0;
      return '${s.label}: capital projete ${ForecasterService.formatChf(s.capitalFinal)}. '
          'Revenu retraite estime ${ForecasterService.formatChf(monthly)}/mois.';
    }

    return [
      buildLine(projection.prudent),
      buildLine(projection.base),
      buildLine(projection.optimiste),
    ];
  }

  /// Reproduit la logique exacte de _buildScoreTrendText() du dashboard.
  ///
  /// Calcule la tendance sur les 3 derniers scores historiques.
  static String _computeStaticTrendMessage(
    List<Map<String, dynamic>>? scoreHistory,
  ) {
    if (scoreHistory == null || scoreHistory.length < 2) {
      return 'Pas encore assez de donnees pour calculer une tendance.';
    }

    final history = scoreHistory;
    final recent =
        history.length >= 3 ? history.sublist(history.length - 3) : history;
    final firstScore = (recent.first['score'] as num?)?.toDouble() ?? 0;
    final lastScore = (recent.last['score'] as num?)?.toDouble() ?? 0;
    final trend = lastScore - firstScore;

    if (trend > 3) {
      return 'En progression — continue comme ca';
    } else if (trend < -3) {
      return 'Attention — ton score baisse. Verifie tes actions.';
    } else {
      return 'Stable — tes efforts maintiennent le cap.';
    }
  }

  // ════════════════════════════════════════════════════════════════
  //  LLM GENERATION (BYOK)
  // ════════════════════════════════════════════════════════════════

  /// Genere un narratif via le LLM en utilisant le RagService.
  static Future<CoachNarrative> _generateViaLlm({
    required CoachProfile profile,
    required List<Map<String, dynamic>>? scoreHistory,
    required List<CoachingTip> tips,
    required LlmConfig config,
  }) async {
    final systemPrompt = _buildSystemPrompt(
      profile: profile,
      scoreHistory: scoreHistory,
      tips: tips,
    );

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

    final ragResponse = await ragService.query(
      question: systemPrompt,
      apiKey: config.apiKey,
      provider: provider,
      model: config.model,
      profileContext: profileContext,
    );

    // Parser la reponse JSON du LLM
    // Note: les guardrails sont appliques dans generate() apres generation
    return _parseLlmResponse(ragResponse.answer);
  }

  /// Construit le system prompt avec le contexte complet de l'utilisateur.
  static String _buildSystemPrompt({
    required CoachProfile profile,
    required List<Map<String, dynamic>>? scoreHistory,
    required List<CoachingTip> tips,
  }) {
    final firstName = profile.firstName ?? 'utilisateur';
    final age = profile.age;
    final etatCivil = profile.etatCivil.name;
    final employmentStatus = profile.employmentStatus;
    final canton = profile.canton;

    // Score + tendance
    FinancialFitnessScore? score;
    try {
      score = FinancialFitnessService.calculate(profile: profile);
    } catch (_) {}
    final scoreValue = score?.global ?? 0;
    final trendText = _computeStaticTrendMessage(scoreHistory);

    // Prevoyance
    final montant3a = profile.prevoyance.totalEpargne3a;
    final plafond3a =
        profile.employmentStatus == 'independant' ? 36288.0 : 7258.0;
    final nombre3a = profile.prevoyance.nombre3a;
    final avoirLpp = profile.prevoyance.avoirLppTotal ?? 0;
    final lacuneLpp = profile.prevoyance.lacuneRachatRestante;

    // Patrimoine
    final patrimoine = profile.patrimoine.totalPatrimoine;
    final depensesMensuelles = profile.totalDepensesMensuelles;
    final epargneLiquide = profile.patrimoine.epargneLiquide;
    final moisCouverts =
        depensesMensuelles > 0 ? epargneLiquide / depensesMensuelles : 0.0;
    final dettes = profile.dettes.totalDettes;

    // Streak
    final streak = StreakService.compute(profile);
    final dernierCheckIn = profile.checkIns.isNotEmpty
        ? '${profile.checkIns.last.month.month}/${profile.checkIns.last.month.year}'
        : 'aucun';

    // Tips formates
    final tipsFormatted = tips.asMap().entries.map((entry) {
      final i = entry.key + 1;
      final tip = entry.value;
      return '#$i [${tip.priority.name}] ${tip.title}: ${tip.message} '
          '(Impact: ${tip.estimatedImpactChf?.toStringAsFixed(0) ?? "N/A"} CHF, '
          'Source: ${tip.source})';
    }).join('\n');

    final buffer = StringBuffer();
    buffer.writeln(
        'Tu es le coach financier MINT. Tu parles a $firstName, $age ans, $etatCivil,');
    buffer.writeln('$employmentStatus dans le canton de $canton.');
    buffer.writeln();
    buffer.writeln('DONNEES FINANCIERES :');
    buffer.writeln(
        '- Score Financial Fitness : $scoreValue/100 (tendance : $trendText)');
    buffer.writeln(
        '- Revenu brut annuel : CHF ${profile.revenuBrutAnnuel.toStringAsFixed(0)}');
    buffer.writeln(
        '- 3a : ${montant3a.toStringAsFixed(0)}/${plafond3a.toStringAsFixed(0)} CHF (nombre comptes : $nombre3a)');
    buffer.writeln(
        '- LPP : avoir CHF ${avoirLpp.toStringAsFixed(0)}, lacune rachat CHF ${lacuneLpp.toStringAsFixed(0)}');
    buffer.writeln('- Patrimoine total : CHF ${patrimoine.toStringAsFixed(0)}');
    buffer.writeln(
        '- Fonds urgence : ${moisCouverts.toStringAsFixed(1)} mois (objectif : 3-6 mois)');
    buffer.writeln('- Dettes : CHF ${dettes.toStringAsFixed(0)}');
    buffer.writeln(
        '- Streak check-in : ${streak.currentStreak} mois consecutifs');
    buffer.writeln('- Dernier check-in : $dernierCheckIn');
    buffer.writeln();
    buffer.writeln('TIPS ACTIFS (par priorite) :');
    buffer.writeln(tipsFormatted);
    buffer.writeln();
    buffer.writeln('INSTRUCTIONS :');
    buffer.writeln(
        '1. Genere un JSON avec les champs : greeting, scoreSummary, trendMessage, topTipNarrative, urgentAlert (null si aucune urgence), milestoneMessage (null si aucun nouveau milestone), scenarioNarrations (liste de 3 paragraphes: prudent, base, optimiste)');
    buffer.writeln(
        '2. Le greeting doit etre personnel et chaleureux (max 2 phrases)');
    buffer.writeln(
        '3. Le scoreSummary doit expliquer le score avec les chiffres de l\'utilisateur (max 3 phrases)');
    buffer.writeln(
        '4. Le trendMessage doit etre contextuel a la trajectoire (max 2 phrases)');
    buffer.writeln(
        '5. Le topTipNarrative doit transformer le tip #1 en conseil emotionnel avec impact CHF (max 4 phrases)');
    buffer.writeln('6. Utilise le tutoiement ("tu")');
    buffer.writeln(
        '7. JAMAIS de termes : garanti, certain, assure, sans risque, optimal, meilleur, parfait');
    buffer.writeln(
        '8. Cite les sources legales quand pertinent (LPP art. X, LIFD art. Y)');
    buffer.writeln(
        '9. Ton educatif, jamais prescriptif. "Tu pourrais" et non "Tu dois"');
    buffer.writeln('10. Reponds UNIQUEMENT en JSON valide');

    return buffer.toString();
  }

  /// Construit le contexte profil pour le RAG backend
  /// (reprend le pattern de CoachLlmService._buildProfileContext).
  static Map<String, dynamic> _buildProfileContext(CoachProfile profile) {
    final parts = <String>[];
    parts.add('Age : ${profile.age} ans');
    parts.add('Canton : ${profile.canton}');
    parts.add('Statut : ${profile.etatCivil.name}');

    if (profile.salaireBrutMensuel > 0) {
      parts.add(
          'Salaire brut : ${profile.salaireBrutMensuel.toStringAsFixed(0)} CHF/mois');
    }

    final prev = profile.prevoyance;
    if (prev.totalEpargne3a > 0) {
      parts.add('Avoir 3a : ${prev.totalEpargne3a.toStringAsFixed(0)} CHF');
    }
    if (prev.nombre3a > 0) {
      parts.add('Nombre de comptes 3a : ${prev.nombre3a}');
    }
    if (prev.avoirLppTotal != null && prev.avoirLppTotal! > 0) {
      parts.add('Avoir LPP : ${prev.avoirLppTotal!.toStringAsFixed(0)} CHF');
    }

    final pat = profile.patrimoine;
    if (pat.totalPatrimoine > 0) {
      parts.add('Patrimoine : ${pat.totalPatrimoine.toStringAsFixed(0)} CHF');
    }
    if (profile.dettes.totalDettes > 0) {
      parts
          .add('Dettes : ${profile.dettes.totalDettes.toStringAsFixed(0)} CHF');
    }

    // Score fitness
    try {
      final score = FinancialFitnessService.calculate(profile: profile);
      parts.add('Score fitness : ${score.global}/100');
    } catch (_) {}

    return {
      'canton': profile.canton,
      'age': profile.age,
      'civil_status': profile.etatCivil.name,
      if (profile.firstName != null) 'first_name': profile.firstName,
      'financial_summary': parts.join('\n'),
    };
  }

  /// Parse la reponse JSON du LLM en CoachNarrative.
  ///
  /// Le LLM doit retourner un JSON avec les champs :
  /// greeting, scoreSummary, trendMessage, topTipNarrative,
  /// urgentAlert, milestoneMessage.
  static CoachNarrative _parseLlmResponse(String rawResponse) {
    // Tenter d'extraire le JSON de la reponse
    // Le LLM peut envelopper le JSON dans des backticks markdown
    var cleaned = rawResponse.trim();

    // Supprimer les backticks markdown si presents
    if (cleaned.startsWith('```json')) {
      cleaned = cleaned.substring(7);
    } else if (cleaned.startsWith('```')) {
      cleaned = cleaned.substring(3);
    }
    if (cleaned.endsWith('```')) {
      cleaned = cleaned.substring(0, cleaned.length - 3);
    }
    cleaned = cleaned.trim();

    final json = jsonDecode(cleaned) as Map<String, dynamic>;

    return CoachNarrative(
      greeting: json['greeting'] as String? ?? '',
      scoreSummary: json['scoreSummary'] as String? ?? '',
      trendMessage: json['trendMessage'] as String? ?? '',
      topTipNarrative: json['topTipNarrative'] as String?,
      urgentAlert: json['urgentAlert'] as String?,
      milestoneMessage: json['milestoneMessage'] as String?,
      scenarioNarrations: (json['scenarioNarrations'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      isLlmGenerated: true,
      generatedAt: DateTime.now(),
    );
  }

  /// Applique les guardrails de filtrage sur un CoachNarrative.
  ///
  /// Filtre les termes bannis de tous les champs textuels.
  static CoachNarrative _applyGuardrails(CoachNarrative narrative) {
    return CoachNarrative(
      greeting: _filterBannedTerms(narrative.greeting),
      scoreSummary: _filterBannedTerms(narrative.scoreSummary),
      trendMessage: _filterBannedTerms(narrative.trendMessage),
      topTipNarrative: narrative.topTipNarrative != null
          ? _filterBannedTerms(narrative.topTipNarrative!)
          : null,
      urgentAlert: narrative.urgentAlert != null
          ? _filterBannedTerms(narrative.urgentAlert!)
          : null,
      milestoneMessage: narrative.milestoneMessage != null
          ? _filterBannedTerms(narrative.milestoneMessage!)
          : null,
      scenarioNarrations: narrative.scenarioNarrations
          ?.map((s) => _filterBannedTerms(s))
          .toList(),
      isLlmGenerated: narrative.isLlmGenerated,
      generatedAt: narrative.generatedAt,
    );
  }

  /// Filtre les termes bannis d'un texte.
  ///
  /// Utilise des word boundaries (\b) pour eviter les faux positifs
  /// sur les mots composes (ex: "incertain" ne doit pas matcher "certain").
  static String _filterBannedTerms(String text) {
    var filtered = text;
    for (final term in _bannedTerms) {
      final pattern = '\\b${RegExp.escape(term)}\\b';
      filtered = filtered.replaceAll(
        RegExp(pattern, caseSensitive: false),
        '[terme retire]',
      );
    }
    return filtered;
  }

  /// Verifie si un texte contient des termes bannis.
  ///
  /// Utilise des word boundaries (\b) pour eviter les faux positifs
  /// sur les mots composes (ex: "incertain" ne matche pas "certain").
  ///
  /// Visible pour les tests.
  static bool containsBannedTerms(String text) {
    for (final term in _bannedTerms) {
      final pattern = '\\b${RegExp.escape(term)}\\b';
      if (RegExp(pattern, caseSensitive: false).hasMatch(text)) return true;
    }
    return false;
  }

  // ════════════════════════════════════════════════════════════════
  //  CACHE
  // ════════════════════════════════════════════════════════════════

  /// Cle de cache : "coach_narrative_{name}_{yyyy-MM-dd}"
  ///
  /// Inclut le prenom du profil pour eviter les collisions
  /// multi-profils sur le meme device.
  static String _cacheKey(CoachProfile profile) {
    final name = profile.firstName ?? 'default';
    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return '${_cacheKeyPrefix}_${name}_$dateStr';
  }

  /// Cle secondaire pour invalider si nouveau check-in.
  static String get _cacheCheckInCountKey => '${_cacheKeyPrefix}_checkin_count';

  /// Charge le narratif depuis le cache si valide (< 24h, meme nombre de check-ins).
  static Future<CoachNarrative?> _loadFromCache(CoachProfile profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _cacheKey(profile);
      final jsonStr = prefs.getString(key);
      if (jsonStr == null) return null;

      // Verifier le TTL
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      final generatedAt = json['generatedAt'] as String?;
      if (generatedAt != null) {
        final generatedDate = DateTime.parse(generatedAt);
        final age = DateTime.now().difference(generatedDate);
        if (age.inHours >= _cacheTtlHours) return null;
      }

      // Verifier si nouveau check-in depuis la derniere generation
      final cachedCheckInCount = prefs.getInt(_cacheCheckInCountKey) ?? 0;
      if (profile.checkIns.length != cachedCheckInCount) return null;

      return CoachNarrative.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// Sauvegarde le narratif dans le cache.
  static Future<void> _saveToCache(
    CoachNarrative narrative,
    CoachProfile profile,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _cacheKey(profile);
      final jsonStr = jsonEncode(narrative.toJson());
      await prefs.setString(key, jsonStr);
      await prefs.setInt(_cacheCheckInCountKey, profile.checkIns.length);
    } catch (_) {
      // Silently fail — cache is optional
    }
  }

  /// Invalide le cache (utile apres resume de l'app depuis un long background).
  ///
  /// Si [profile] est fourni, invalide uniquement le cache de ce profil.
  /// Sinon, supprime tous les caches narratifs (toutes les cles commencant
  /// par le prefix).
  static Future<void> invalidateCache({CoachProfile? profile}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (profile != null) {
        final key = _cacheKey(profile);
        await prefs.remove(key);
      } else {
        // Sans profil, supprimer toutes les cles commencant par le prefix
        final allKeys = prefs.getKeys();
        for (final key in allKeys) {
          if (key.startsWith(_cacheKeyPrefix)) {
            await prefs.remove(key);
          }
        }
      }
      await prefs.remove(_cacheCheckInCountKey);
    } catch (_) {
      // Silently fail
    }
  }
}
