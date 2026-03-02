import 'dart:convert';

import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/coach/compliance_guard.dart';
import 'package:mint_mobile/services/coach_llm_service.dart';
import 'package:mint_mobile/services/coaching_service.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/financial_fitness_service.dart';
import 'package:mint_mobile/services/forecaster_service.dart';
import 'package:mint_mobile/services/rag_service.dart';
import 'package:mint_mobile/services/slm/slm_engine.dart';
import 'package:mint_mobile/services/streak_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ────────────────────────────────────────────────────────────
//  COACH NARRATIVE SERVICE — Coach AI Layer / T1
// ────────────────────────────────────────────────────────────
//
// Le cerveau du Coach Layer. Genere tout le contenu narratif
// du dashboard via 3 modes (par priorite) :
//
// TRIPLE MODE (privacy-first) :
//   1. SLM on-device (Gemma 3n) → zero reseau, privacy totale
//   2. Templates enrichis       → toujours disponible, zero LLM
//   3. BYOK cloud LLM           → optionnel, opt-in explicite
//
// CACHE :
//   - SharedPreferences, cle "coach_narrative_{yyyy-MM-dd}"
//   - TTL 24h, invalide si nouveau check-in
//
// GUARDRAILS :
//   - ComplianceGuard (5 couches) sur TOUTE sortie LLM/SLM
//   - Filtrage des termes bannis
//   - Detection d'hallucinations
//   - Disclaimer obligatoire
//   - Fallback vers statique si echec
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

  /// Contextual narration for the chiffre-choc screen (max ~100 words).
  /// Example: "A 58 ans, tu as encore 7 ans pour combler un ecart de CHF 850/mois."
  final String? chiffreChocNarration;

  /// Retirement countdown phrase for 45-60 dashboard header.
  /// Example: "Plus que 84 mois avant ta retraite a 63 ans. Taux de remplacement : ~52%."
  final String? retirementCountdown;

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
    this.chiffreChocNarration,
    this.retirementCountdown,
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
        'chiffreChocNarration': chiffreChocNarration,
        'retirementCountdown': retirementCountdown,
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
      chiffreChocNarration: json['chiffreChocNarration'] as String?,
      retirementCountdown: json['retirementCountdown'] as String?,
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
  static const _cacheModeSignatureKey = '${_cacheKeyPrefix}_mode_signature';

  /// Disclaimer standard
  static const disclaimer =
      'Outil educatif — ne constitue pas un conseil financier. LSFin.';

  /// Termes bannis — delegue a ComplianceGuard (source unique).
  static List<String> get _bannedTerms => ComplianceGuard.bannedTerms;

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
  /// Priorite de generation (privacy-first) :
  ///   1. SLM on-device (Gemma 3n) — si modele telecharge
  ///   2. Templates enrichis — toujours disponible, zero LLM
  ///   3. BYOK cloud LLM — optionnel, opt-in explicite
  ///
  /// Le resultat est cache 24h dans SharedPreferences.
  static Future<CoachNarrative> generate({
    required CoachProfile profile,
    required List<Map<String, dynamic>>? scoreHistory,
    required List<CoachingTip> tips,
    LlmConfig? byokConfig,
  }) async {
    // 1. Verifier le cache (mode-aware: invalidation immediate des kill-switches)
    final cached = await _loadFromCache(profile);
    if (cached != null) return cached;

    // 2. Generer le narratif (priorite privacy-first : SLM > Templates > BYOK)
    //    Ref: BRIEFING_AUDIT_EXTERNE:170,231 — architecture cible adoptee.
    CoachNarrative narrative;

    if (FeatureFlags.safeModeDegraded) {
      // Emergency fallback mode: deterministic templates only.
      narrative = _generateStatic(
        profile: profile,
        scoreHistory: scoreHistory,
        tips: tips,
      );
    } else if (FeatureFlags.enableSlmNarratives &&
        SlmEngine.instance.isAvailable) {
      // Tier 1: SLM on-device (zero reseau, privacy totale)
      try {
        narrative = await _generateViaSlm(
          profile: profile,
          scoreHistory: scoreHistory,
          tips: tips,
        );
      } catch (_) {
        // Fallback vers templates enrichis si SLM echoue
        narrative = _generateStatic(
          profile: profile,
          scoreHistory: scoreHistory,
          tips: tips,
        );
      }
    } else if (!FeatureFlags.enableSlmNarratives) {
      // Server kill-switch: templates-only mode.
      narrative = _generateStatic(
        profile: profile,
        scoreHistory: scoreHistory,
        tips: tips,
      );
    } else {
      // Tier 2: Templates enrichis (zero LLM, toujours disponible)
      narrative = _generateStatic(
        profile: profile,
        scoreHistory: scoreHistory,
        tips: tips,
      );

      // Tier 3: BYOK cloud LLM (optionnel, opt-in explicite)
      // Tente d'ameliorer le narratif statique si BYOK est configure.
      // En cas d'echec, le narratif statique reste intact.
      if (byokConfig != null && byokConfig.hasApiKey) {
        try {
          narrative = await _generateViaLlm(
            profile: profile,
            scoreHistory: scoreHistory,
            tips: tips,
            config: byokConfig,
          );
        } catch (_) {
          // Resilience: garde le narratif statique deja genere
        }
      }
    }

    // 4. Appliquer les guardrails sur TOUS les modes (SLM, LLM et statique)
    narrative = _applyGuardrails(narrative);

    // 5. Sauvegarder en cache
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
    final firstName =
        (profile.firstName != null && profile.firstName!.isNotEmpty)
            ? profile.firstName!
            : 'toi';

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

    // ── urgentAlert: deadline-based alerts in static mode ──
    String? urgentAlert;
    final now = DateTime.now();

    // Oct-Dec: deadline 3a avant le 31 decembre (OPP3 art. 7)
    // Enhanced with personalized tax savings estimate (M6C)
    if (now.month >= 10 && now.month <= 12) {
      final plafond =
          profile.employmentStatus == 'independant' ? 36288.0 : 7258.0;
      final verseAnnuel = profile.total3aMensuel * 12;
      final marge = plafond - verseAnnuel;
      if (marge > 0) {
        final deadline = DateTime(now.year, 12, 31);
        final joursRestants = deadline.difference(now).inDays;
        // Estimate tax savings from the remaining 3a margin
        final tauxEstime = profile.canton.isNotEmpty ? 0.30 : 0.28;
        final economie = marge * tauxEstime;
        urgentAlert = 'Il te reste $joursRestants jours pour verser '
            'CHF ${marge.toStringAsFixed(0)} en 3a et economiser '
            '~CHF ${economie.toStringAsFixed(0)} d\'impots '
            '(canton ${profile.canton.isNotEmpty ? profile.canton : "CH"}). '
            '\u2014 OPP3 art. 7';
      }
    }

    // Feb-Mar: declaration fiscale avant le 31 mars (LIFD / LHID)
    if (urgentAlert == null && now.month >= 2 && now.month <= 3) {
      final deadline = DateTime(now.year, 3, 31);
      final joursRestants = deadline.difference(now).inDays;
      if (joursRestants >= 0) {
        urgentAlert = 'Declaration fiscale a rendre avant le 31 mars '
            '($joursRestants jours restants). '
            '\u2014 LIFD / LHID';
      }
    }

    // ── chiffreChocNarration + retirementCountdown (static fallback) ──
    String? chiffreChocNarration;
    String? retirementCountdown;
    if (profile.age >= 45) {
      final yearsLeft = profile.anneesAvantRetraite;
      final retAge = profile.effectiveRetirementAge;
      retirementCountdown = 'Plus que ${yearsLeft * 12} mois avant ta retraite '
          'a $retAge ans.';

      if (yearsLeft <= 10) {
        chiffreChocNarration = 'A ${profile.age} ans, tu as encore $yearsLeft '
            'ans pour optimiser ta prevoyance.';
      }
    }

    return CoachNarrative(
      greeting: greeting,
      scoreSummary: scoreSummary,
      trendMessage: trendMessage,
      topTipNarrative: topTipNarrative,
      urgentAlert: urgentAlert,
      milestoneMessage:
          null, // Milestones: async detection, handled in generate()
      scenarioNarrations: scenarioNarrations,
      chiffreChocNarration: chiffreChocNarration,
      retirementCountdown: retirementCountdown,
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
  //  SLM ON-DEVICE GENERATION (Gemma 3n)
  // ════════════════════════════════════════════════════════════════

  /// Genere un narratif via le SLM on-device (Gemma 3n).
  ///
  /// Avantages :
  ///   - Zero reseau → fonctionne hors-ligne
  ///   - Zero donnees envoyees → privacy totale
  ///   - Latence reduite (~2-4s sur device recent)
  ///
  /// Le ComplianceGuard valide la sortie avant affichage.
  static Future<CoachNarrative> _generateViaSlm({
    required CoachProfile profile,
    required List<Map<String, dynamic>>? scoreHistory,
    required List<CoachingTip> tips,
  }) async {
    final slm = SlmEngine.instance;
    final systemPrompt = _buildSystemPrompt(
      profile: profile,
      scoreHistory: scoreHistory,
      tips: tips,
    );

    final result = await slm.generate(
      systemPrompt: systemPrompt,
      userPrompt: 'Genere le JSON narratif complet du dashboard.',
      maxTokens: 512,
    );

    if (result == null || result.text.trim().isEmpty) {
      // SLM n'a pas genere de contenu → fallback
      return _generateStatic(
        profile: profile,
        scoreHistory: scoreHistory,
        tips: tips,
      );
    }

    // Valider via ComplianceGuard (5 couches)
    final compliance = ComplianceGuard.validate(result.text);
    if (compliance.useFallback) {
      // SLM output non conforme → fallback statique
      return _generateStatic(
        profile: profile,
        scoreHistory: scoreHistory,
        tips: tips,
      );
    }

    // Parser la reponse JSON
    try {
      final narrative = _parseLlmResponse(
        compliance.sanitizedText.isNotEmpty
            ? compliance.sanitizedText
            : result.text,
      );
      return CoachNarrative(
        greeting: narrative.greeting,
        scoreSummary: narrative.scoreSummary,
        trendMessage: narrative.trendMessage,
        topTipNarrative: narrative.topTipNarrative,
        urgentAlert: narrative.urgentAlert,
        milestoneMessage: narrative.milestoneMessage,
        scenarioNarrations: narrative.scenarioNarrations,
        isLlmGenerated: true, // SLM is a local LLM
        generatedAt: DateTime.now(),
      );
    } catch (_) {
      // Parsing JSON echoue → fallback statique
      return _generateStatic(
        profile: profile,
        scoreHistory: scoreHistory,
        tips: tips,
      );
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
    final firstName =
        (profile.firstName != null && profile.firstName!.isNotEmpty)
            ? profile.firstName!
            : 'toi';
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
    // Retirement context for 45-60 age group
    buffer.write(_buildRetirementContext(profile));

    // Educational snippets (pre-computed, factual)
    buffer.write(_buildEducationalSnippets(profile));

    buffer.writeln('CONSTANTES SUISSES (grounding — valeurs 2025) :');
    buffer.writeln(
        '- Rente AVS max individuelle : 2\'520 CHF/mois (LAVS art. 34)');
    buffer.writeln('- Taux conversion LPP min : 6.8% (LPP art. 14)');
    buffer.writeln(
        '- Reduction taux conversion par annee anticipee : ~0.2% (LPP art. 13 al. 2)');
    buffer.writeln('- Plafond 3a salarie : 7\'258 CHF/an (OPP3 art. 7)');
    buffer.writeln('- Seuil LPP : 22\'680 CHF/an (LPP art. 7)');
    buffer.writeln('- Reduction AVS par annee anticipee : 6.8% (LAVS art. 40)');
    buffer.writeln();

    buffer.writeln('TIPS ACTIFS (par priorite) :');
    buffer.writeln(tipsFormatted);
    buffer.writeln();
    buffer.writeln('INSTRUCTIONS :');
    buffer.writeln(
        '1. Genere un JSON avec les champs : greeting, scoreSummary, trendMessage, topTipNarrative, urgentAlert (null si aucune urgence), milestoneMessage (null si aucun nouveau milestone), scenarioNarrations (liste de 3 paragraphes: prudent, base, optimiste), chiffreChocNarration (null si age < 45, sinon max 100 mots contextualisant le chiffre-choc), retirementCountdown (null si age < 45, sinon phrase de countdown retraite)');
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

  /// Build retirement context block for the SLM prompt.
  ///
  /// Injects countdown, urgency level, and replacement rate estimate
  /// for users aged 45+. Returns empty string for younger users.
  static String _buildRetirementContext(CoachProfile profile) {
    if (profile.age < 45) return '';

    final buffer = StringBuffer();
    final retirementAge = profile.effectiveRetirementAge;
    final yearsLeft = profile.anneesAvantRetraite;
    final monthsLeft = yearsLeft * 12;

    final urgency = yearsLeft <= 5
        ? 'URGENT'
        : yearsLeft <= 10
            ? 'IMPORTANT'
            : 'NORMAL';

    // Quick replacement rate estimate (AVS + LPP rente / gross salary)
    double replacementRate = 0;
    if (profile.revenuBrutAnnuel > 0) {
      // AVS: ~roughly estimated monthly
      final avsEstimate = profile.revenuBrutAnnuel > 88200
          ? 2520.0
          : (profile.revenuBrutAnnuel / 88200 * 2520).clamp(1260.0, 2520.0);
      // LPP: rough estimate from existing balance + remaining bonifications
      final lppBalance = profile.prevoyance.avoirLppTotal ?? 0;
      final lppMonthlyEstimate = lppBalance * 0.068 / 12;
      final totalRetirement = avsEstimate + lppMonthlyEstimate;
      replacementRate = totalRetirement / (profile.revenuBrutAnnuel / 12);
    }

    buffer.writeln('CONTEXTE RETRAITE :');
    buffer.writeln('- Age de retraite cible : $retirementAge ans');
    buffer.writeln('- Countdown : Plus que $yearsLeft ans ($monthsLeft mois)');
    buffer.writeln('- Niveau d\'urgence : $urgency');
    if (replacementRate > 0) {
      buffer.writeln(
          '- Taux de remplacement estime : ~${(replacementRate * 100).toStringAsFixed(0)}%');
    }
    if (retirementAge < 65) {
      buffer.writeln(
          '- Retraite anticipee : penalite AVS de ${((65 - retirementAge) * 6.8).toStringAsFixed(1)}% '
          '+ taux conversion LPP reduit');
    }
    buffer.writeln();

    return buffer.toString();
  }

  /// Build pre-computed educational snippets relevant to the user's profile.
  ///
  /// Injected into the SLM system prompt so the LLM can reference factual
  /// snippets without hallucinating. Max 3-5 snippets.
  static String _buildEducationalSnippets(CoachProfile profile) {
    final snippets = <String>[];

    // 3a not maxed out
    final cotisation3a = profile.total3aMensuel * 12;
    if (cotisation3a < 7258 && profile.prevoyance.canContribute3a) {
      final marge = 7258 - cotisation3a;
      snippets.add(
          'SNIPPET 3A: Il reste CHF ${marge.toStringAsFixed(0)} de marge 3a '
          'cette annee (plafond 7\'258 CHF, OPP3 art. 7).');
    }

    // LPP buyback available
    final lacune = profile.prevoyance.lacuneRachatRestante;
    if (lacune > 5000) {
      snippets.add(
          'SNIPPET LPP: Lacune de rachat LPP de CHF ${lacune.toStringAsFixed(0)} '
          '— deductible a 100% du revenu imposable (LPP art. 79b).');
    }

    // AVS gaps
    final lacunesAvs = profile.prevoyance.lacunesAVS ?? 0;
    if (lacunesAvs > 0) {
      snippets
          .add('SNIPPET AVS: $lacunesAvs annee${lacunesAvs > 1 ? 's' : ''} de '
              'cotisation manquante${lacunesAvs > 1 ? 's' : ''}. Chaque annee '
              'manquante reduit la rente de 1/44 (LAVS art. 29ter).');
    }

    // Close to retirement — coordination reminder
    if (profile.age >= 55 && profile.anneesAvantRetraite <= 10) {
      snippets.add(
          'SNIPPET COORDINATION: A ${profile.anneesAvantRetraite} ans de la '
          'retraite, la coordination des retraits (3a echelonne, LPP '
          'rente/capital, AVS anticipation/ajournement) peut avoir un '
          'impact fiscal significatif.');
    }

    // Time Machine insight (M6A) — regret + hope
    if (profile.age >= 45) {
      final timeMachine = _buildTimeMachineInsight(profile);
      if (timeMachine != null) snippets.add(timeMachine);
    }

    if (snippets.isEmpty) return '';

    final buffer = StringBuffer();
    buffer.writeln('SNIPPETS EDUCATIFS (factuels, pre-calcules) :');
    for (final s in snippets) {
      buffer.writeln('- $s');
    }
    buffer.writeln();
    return buffer.toString();
  }

  /// Time Machine insight: backward (regret) + forward (hope) 3a projection.
  ///
  /// "If you had started at 30 → +X CHF. But contributing Y more years → +Z CHF."
  /// Pure compound interest: annual 7258 CHF at 2% average return.
  static String? _buildTimeMachineInsight(CoachProfile profile) {
    const plafond = 7258.0;
    const avgReturn = 0.02; // Conservative 3a average

    final retAge = profile.effectiveRetirementAge;
    final age = profile.age;

    // Backward: if started maxing 3a at age 30
    final yearsIfStarted30 = (age - 30).clamp(0, 40);
    double regretBalance = 0;
    for (int i = 0; i < yearsIfStarted30; i++) {
      regretBalance = (regretBalance + plafond) * (1 + avgReturn);
    }

    // Forward: from now to retirement
    final yearsForward = (retAge - age).clamp(0, 40);
    double hopeBalance = 0;
    for (int i = 0; i < yearsForward; i++) {
      hopeBalance = (hopeBalance + plafond) * (1 + avgReturn);
    }

    if (regretBalance <= 0 && hopeBalance <= 0) return null;

    final buffer = StringBuffer('TIME MACHINE 3A: ');
    if (yearsIfStarted30 > 0 && regretBalance > 10000) {
      buffer.write('Si tu avais verse 7\'258 CHF/an depuis 30 ans → '
          'CHF ${regretBalance.toStringAsFixed(0)} aujourd\'hui. ');
    }
    if (yearsForward > 0) {
      buffer.write('En versant le max pendant $yearsForward ans → '
          '+CHF ${hopeBalance.toStringAsFixed(0)} a la retraite.');
    }
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
      chiffreChocNarration: json['chiffreChocNarration'] as String?,
      retirementCountdown: json['retirementCountdown'] as String?,
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
      chiffreChocNarration: narrative.chiffreChocNarration != null
          ? _filterBannedTerms(narrative.chiffreChocNarration!)
          : null,
      retirementCountdown: narrative.retirementCountdown != null
          ? _filterBannedTerms(narrative.retirementCountdown!)
          : null,
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

  /// Signature du mode narratif courant.
  ///
  /// Permet d'invalider immediatement le cache si un kill-switch change
  /// (safe mode degrade, SLM on/off), meme avant expiration TTL.
  static String get _currentModeSignature =>
      'safe:${FeatureFlags.safeModeDegraded}|slm:${FeatureFlags.enableSlmNarratives}';

  /// Charge le narratif depuis le cache si valide (< 24h, meme nombre de check-ins).
  static Future<CoachNarrative?> _loadFromCache(CoachProfile profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedMode = prefs.getString(_cacheModeSignatureKey);
      if (cachedMode != _currentModeSignature) return null;

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
      await prefs.setString(_cacheModeSignatureKey, _currentModeSignature);
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
      await prefs.remove(_cacheModeSignatureKey);
    } catch (_) {
      // Silently fail
    }
  }
}
