import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/financial_core/avs_calculator.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';
import 'package:mint_mobile/services/forecaster_service.dart';
import 'package:mint_mobile/services/financial_fitness_service.dart';
import 'package:mint_mobile/widgets/coach/mint_score_gauge.dart';
import 'package:mint_mobile/widgets/coach/mint_trajectory_chart.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/services/coach_llm_service.dart';
import 'package:mint_mobile/services/coach_narrative_service.dart';
import 'package:mint_mobile/services/coaching_service.dart';
import 'package:mint_mobile/services/rag_service.dart';
import 'package:mint_mobile/services/benchmark_service.dart';
import 'package:mint_mobile/services/tax_estimator_service.dart';
import 'package:mint_mobile/services/analytics_service.dart';
import 'package:mint_mobile/services/streak_service.dart';
import 'package:mint_mobile/services/subscription_service.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/widgets/coach/chiffre_choc_section.dart';
import 'package:mint_mobile/widgets/coach/explore_hub.dart';
import 'package:mint_mobile/widgets/coach/low_confidence_card.dart';
import 'package:mint_mobile/widgets/coach/trajectory_card.dart';
import 'package:mint_mobile/widgets/coach/early_retirement_comparison.dart';
import 'package:mint_mobile/widgets/coach/benchmark_card.dart';
import 'package:mint_mobile/widgets/coach/coach_helpers.dart';
import 'package:mint_mobile/providers/user_activity_provider.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

// ────────────────────────────────────────────────────────────
//  COACH DASHBOARD SCREEN — Sprint C5 / MINT Coach
// ────────────────────────────────────────────────────────────
//
// Ecran principal du MINT Coach — premiere chose que l'utilisateur voit.
//
// DEUX ETATS :
//
// A) Profil existe (wizard complete) — dashboard complet :
//   1. SliverAppBar — "Bonjour {firstName}"
//   2. Coach Alert Card — message contextuel du coach
//   3. MintScoreGauge — Financial Fitness Score
//   4. MintTrajectoryChart — projection a 3 scenarios
//   5. Quick Actions — check-in, 3a, rachat LPP
//   + Disclaimer legal en bas
//
// B) Pas de profil (utilisateur curieux, "Je veux juste explorer") :
//   1. SliverAppBar — "Bienvenue"
//   2. Empty Score Card — jauge grisee avec "?"
//   3. Teaser Trajectory — graphique floute avec overlay
//   4. Quick Win Cards — faits educatifs avec liens
//   5. Motivation banner — incitation a completer le diagnostic
//   + Disclaimer legal en bas
//
// Toutes les donnees sont calculees localement via les services.
// Aucun appel reseau.
// Tous les textes en francais (informel "tu").
// Aucun terme banni (pas de "garanti", "certain", "optimal", etc.).
// ────────────────────────────────────────────────────────────

class CoachDashboardScreen extends StatefulWidget {
  const CoachDashboardScreen({super.key});

  @override
  State<CoachDashboardScreen> createState() => _CoachDashboardScreenState();
}

enum _DashboardResetAction { resetHistory, resetDiagnostic }

/// Urgency level for coach alert card.
enum _AlertUrgency { urgent, active, info }

class _CoachDashboardScreenState extends State<CoachDashboardScreen>
    with SingleTickerProviderStateMixin {
  CoachProfile? _profile;
  FinancialFitnessScore? _score;
  ProjectionResult? _projection;
  ProjectionResult? _baselineProjection; // projection sans contributions
  double _confidenceScore = 0; // 0-100, from ConfidenceScorer
  List<CoachingTip> _coachingTips = [];
  List<Map<String, dynamic>>? _scoreHistory;
  StreakResult? _streak;
  Map<String, dynamic> _onboarding30PlanState = const {};
  bool _onboarding30PlanLoaded = false;
  bool _showRefreshBanner = false;
  bool _coachUxPrefsLoaded = false;
  CoachNarrativeMode _narrativeMode = CoachNarrativeMode.detailed;
  String? _lastScoreDeltaReason;
  int? _lastScoreDeltaPersisted;
  bool _compactMode = true;

  // Chiffre choc emotional narratives (LLM-generated via BYOK)
  Map<String, String> _chiffreChocNarratives = {};
  bool _didTrackDashboardView = false;

  // T7: Coach narrative (LLM or static fallback)
  CoachNarrative? _narrative;

  // Generation counters to prevent stale async results from overwriting newer ones
  int _narrativeGeneration = 0;
  int _chiffreChocGeneration = 0;

  // "Et si..." state
  bool _etSiExpanded = false;
  double _etSiLppReturn = 0.02; // base default
  double _etSiThreeAReturn = 0.045; // base default
  double _etSiInvestReturn = 0.06; // base default
  double _etSiInflation = 0.015; // base default
  ProjectionResult? _etSiProjection;

  // Animation controller for the empty state pulsing glow
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );
    // Note: _loadOnboarding30PlanState() is called in didChangeDependencies()
    // which runs automatically after initState(). No need to call it here.
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    unawaited(_loadOnboarding30PlanState());
    if (!_coachUxPrefsLoaded) {
      unawaited(_loadCoachUxPreferences());
    }
    final coachProvider = context.watch<CoachProfileProvider>();

    // BUG FIX: Ne plus utiliser CoachProfile.buildDemo() comme fallback.
    // Si le wizard n'a pas ete complete, on affiche l'etat vide
    // (utilisateur curieux) au lieu de fausses donnees demo.
    if (coachProvider.hasProfile) {
      final newProfile = coachProvider.profile!;
      if (_profile != newProfile) {
        _profile = newProfile;
        _etSiProjection = null; // Reset "Et si..." on profile change
        _score = FinancialFitnessService.calculate(
          profile: _profile!,
          previousScore: coachProvider.previousScore,
        );
        _projection = ForecasterService.project(
          profile: _profile!,
          targetDate: _profile!.goalA.targetDate,
        );

        // Projection baseline (sans contributions) pour "Now vs With MINT"
        if (_profile!.plannedContributions.isNotEmpty) {
          final profileSans = _profile!.copyWithContributions(const []);
          _baselineProjection = ForecasterService.project(
            profile: profileSans,
            targetDate: _profile!.goalA.targetDate,
          );
        } else {
          _baselineProjection = null;
        }

        // Confidence score (guards projection display)
        _confidenceScore = ConfidenceScorer.score(_profile!).score;

        // Streak computation (cached as state for badge display)
        _streak = StreakService.compute(_profile!);

        // Coaching tips caches (evite le recalcul a chaque rebuild)
        _coachingTips = CoachingService.generateTips(
          profile: _profile!.toCoachingProfile(),
        );

        // Capture provider synchronously before async calls (BUG 3 fix)
        final byokProvider = context.read<ByokProvider>();

        // Charge la couche Coach IA en flux unique pour limiter la latence
        // et eviter les appels LLM redondants.
        unawaited(_loadCoachAiLayer(byokProvider));
      }

      // Filtrer les tips dont le simulateur a ete explore (inter-tab sync)
      final activity = context.watch<UserActivityProvider>();
      if (activity.isLoaded && activity.exploredSimulators.isNotEmpty) {
        // Tips explores sont deprioritises (mis en fin de liste)
        final explored = <CoachingTip>[];
        final notExplored = <CoachingTip>[];
        for (final tip in _coachingTips) {
          final simId = _simulatorIdForTip(tip);
          if (simId != null && activity.isSimulatorExplored(simId)) {
            explored.add(tip);
          } else {
            notExplored.add(tip);
          }
        }
        _coachingTips = [...notExplored, ...explored];
      }
      // Charger l'historique des scores depuis le provider
      _scoreHistory = coachProvider.scoreHistory;

      // Detect if profile needs annual refresh (~11 months)
      final daysSinceUpdate =
          DateTime.now().difference(_profile!.updatedAt).inDays;
      _showRefreshBanner = daysSinceUpdate >= 330;
    } else {
      _profile = null;
      _score = null;
      _projection = null;
      _baselineProjection = null;
      _coachingTips = [];
      _scoreHistory = null;
    }
  }

  /// Mappe un coaching tip a un ID de simulateur pour le feedback loop.
  String? _simulatorIdForTip(CoachingTip tip) {
    switch (tip.category) {
      case 'fiscalite':
        return '3a';
      case 'prevoyance':
        if (tip.id.contains('lpp')) return 'lpp_deep';
        if (tip.id.contains('3a')) return '3a';
        return null;
      case 'retraite':
        if (tip.id.contains('rente') || tip.id.contains('capital')) {
          return 'rente_capital';
        }
        return 'retirement_projection';
      case 'budget':
        return 'budget';
      default:
        return null;
    }
  }

  Future<void> _loadOnboarding30PlanState() async {
    final state = await ReportPersistenceService.loadOnboarding30PlanState();
    if (!mounted) return;
    setState(() {
      _onboarding30PlanState = state;
      _onboarding30PlanLoaded = true;
    });
  }

  Future<void> _loadCoachUxPreferences() async {
    final mode = await ReportPersistenceService.loadCoachNarrativeMode();
    final attribution =
        await ReportPersistenceService.loadLastScoreAttribution();
    if (!mounted) return;
    setState(() {
      _coachUxPrefsLoaded = true;
      _narrativeMode = mode == 'concise'
          ? CoachNarrativeMode.concise
          : CoachNarrativeMode.detailed;
      _lastScoreDeltaReason = attribution?['reason'] as String?;
      _lastScoreDeltaPersisted = attribution?['delta'] as int?;
    });
  }

  Future<void> _setNarrativeMode(CoachNarrativeMode mode) async {
    if (_narrativeMode == mode) return;
    setState(() => _narrativeMode = mode);
    await ReportPersistenceService.saveCoachNarrativeMode(
      mode == CoachNarrativeMode.concise ? 'concise' : 'detailed',
    );
  }

  // ── Chiffre Choc Emotional Narratives (T3 — Coach AI Layer) ──

  /// Enrich top 3 coaching tips via LLM if BYOK is configured.
  /// Falls back to original tips (no enrichment) on error.
  Future<void> _loadEnrichedTips(ByokProvider byok) async {
    if (!byok.isConfigured || _profile == null) return;
    if (_coachingTips.isEmpty) return;

    try {
      final enriched = await CoachingService.enrichTips(
        tips: _coachingTips.take(3).toList(),
        profile: _profile!.toCoachingProfile(),
        firstName: _profile!.firstName ?? 'utilisateur',
        apiKey: byok.apiKey,
        provider: byok.provider ?? 'openai',
      );
      if (!mounted) return;
      setState(() {
        // Replace top tips with enriched versions
        _coachingTips = [...enriched, ..._coachingTips.skip(enriched.length)];
      });
    } catch (_) {
      // Fallback: use original tips without enrichment
    }
  }

  /// Generate emotional narratives for chiffre choc cards via BYOK LLM.
  /// Returns a map of category -> narrative message.
  /// Falls back to empty map (use static message) if no BYOK or LLM fails.
  Future<void> _loadChiffreChocNarratives(ByokProvider byok) async {
    final gen = ++_chiffreChocGeneration;
    if (!byok.isConfigured || _profile == null) return;

    // Check 24h cache
    final prefs = await SharedPreferences.getInstance();
    if (gen != _chiffreChocGeneration) return; // stale — abort
    final profileScope = [
      _profile!.birthYear,
      _profile!.canton,
      _profile!.firstName ?? '',
      _profile!.createdAt.toIso8601String(),
    ].join('_');
    final cacheKey =
        'chiffre_choc_narratives_${profileScope}_${DateTime.now().toIso8601String().substring(0, 10)}';
    final cached = prefs.getString(cacheKey);
    if (cached != null) {
      try {
        final map = Map<String, String>.from(
          (jsonDecode(cached) as Map).map(
            (k, v) => MapEntry(k.toString(), v.toString()),
          ),
        );
        if (map.isNotEmpty && mounted && gen == _chiffreChocGeneration) {
          setState(() => _chiffreChocNarratives = map);
        }
        return;
      } catch (_) {
        // Cache corrupted — regenerate
      }
    }

    // Generate via LLM
    try {
      final ragService = RagService();
      final prompt = '''
Tu es le coach MINT. Transforme ces chiffres choc en impact emotionnel pour ${_profile!.firstName ?? 'utilisateur'} :

${_buildChiffreChocContext()}

Pour CHAQUE chiffre, genere une phrase qui :
- Traduit le montant en impact de vie quotidien (vacances, loyer, creche, etc.)
- Utilise des comparaisons concretes et tangibles
- Tutoiement, ton chaleureux
- JAMAIS : garanti, certain, assure, sans risque, optimal, meilleur, parfait

Reponds UNIQUEMENT en JSON valide : {"fiscalite": "...", "prevoyance": "...", "avs": "..."}
Si une categorie ne s'applique pas, omets-la.
''';
      final response = await ragService.query(
        question: prompt,
        apiKey: byok.apiKey!,
        provider: byok.provider ?? 'openai',
        profileContext: {
          'financial_summary':
              '${_profile!.firstName ?? 'utilisateur'}, ${_profile!.age} ans',
        },
      );

      // Parse JSON from LLM response (may be wrapped in markdown backticks)
      var rawAnswer = response.answer.trim();
      if (rawAnswer.startsWith('```json')) {
        rawAnswer = rawAnswer.substring(7);
      } else if (rawAnswer.startsWith('```')) {
        rawAnswer = rawAnswer.substring(3);
      }
      if (rawAnswer.endsWith('```')) {
        rawAnswer = rawAnswer.substring(0, rawAnswer.length - 3);
      }
      rawAnswer = rawAnswer.trim();

      final parsed = jsonDecode(rawAnswer) as Map;
      final result = parsed.map((k, v) => MapEntry(k.toString(), v.toString()));

      // Filter banned terms from each narrative
      final filtered = result.map((k, v) => MapEntry(k, _filterBannedTerms(v)));

      if (gen != _chiffreChocGeneration) return; // stale — abort

      // Cache for 24h
      await prefs.setString(cacheKey, jsonEncode(filtered));

      if (mounted && gen == _chiffreChocGeneration) {
        setState(
            () => _chiffreChocNarratives = Map<String, String>.from(filtered));
      }
    } catch (_) {
      // Fallback: use static messages (empty map = no narrative)
    }
  }

  /// Build context string describing the user's current chiffre choc values.
  String _buildChiffreChocContext() {
    final buffer = StringBuffer();
    final revenuBrutAnnuel = _profile!.revenuBrutAnnuel;

    // 3a tax savings
    final cotisation3aAnnuelle = _profile!.total3aMensuel * 12;
    const plafond3a = pilier3aPlafondAvecLpp;
    if (cotisation3aAnnuelle < plafond3a &&
        _profile!.prevoyance.canContribute3a) {
      final tauxMarginal =
          RetirementTaxCalculator.estimateMarginalRate(revenuBrutAnnuel, _profile!.canton);
      final economiePotentielle =
          (plafond3a - cotisation3aAnnuelle) * tauxMarginal;
      final anneesRestantes = _profile!.anneesAvantRetraite;
      final economieTotale = economiePotentielle * anneesRestantes;
      if (economieTotale > 500) {
        buffer.writeln(
            'FISCALITE: CHF ${economieTotale.toStringAsFixed(0)} d\'economies d\'impots potentielles d\'ici la retraite en maximisant le 3a.');
      }
    }

    // LPP buyback
    final lacuneLpp = _profile!.prevoyance.lacuneRachatRestante;
    if (lacuneLpp > 5000) {
      final tauxMarginal =
          RetirementTaxCalculator.estimateMarginalRate(revenuBrutAnnuel, _profile!.canton);
      final economieRachat = lacuneLpp * tauxMarginal;
      buffer.writeln(
          'PREVOYANCE: CHF ${economieRachat.toStringAsFixed(0)} de deduction fiscale potentielle en rachetant la lacune LPP de CHF ${lacuneLpp.toStringAsFixed(0)}.');
    }

    // AVS gap
    final lacunesAVS = _profile!.prevoyance.lacunesAVS ?? 0;
    if (lacunesAVS > 0) {
      final perteTotaleAnnuelle =
          AvsCalculator.monthlyLossFromGap(lacunesAVS) * 12;
      final perteTotaleRetraite = perteTotaleAnnuelle * 20;
      buffer.writeln(
          'AVS: CHF ${perteTotaleRetraite.toStringAsFixed(0)} de rente AVS perdue sur 20 ans de retraite avec $lacunesAVS annee(s) de cotisation manquante(s).');
    }

    if (buffer.isEmpty) {
      buffer.writeln('Pas de chiffre choc specifique pour cet utilisateur.');
    }

    return buffer.toString();
  }

  /// Filter banned terms from a narrative string (compliance guardrail).
  static String _filterBannedTerms(String text) {
    const bannedTerms = [
      'garanti',
      'certain',
      'assuré',
      'assure',
      'sans risque',
      'optimal',
      'meilleur',
      'parfait',
    ];
    var filtered = text;
    for (final term in bannedTerms) {
      if (filtered.toLowerCase().contains(term.toLowerCase())) {
        filtered = filtered.replaceAll(
          RegExp(term, caseSensitive: false),
          '[terme retire]',
        );
      }
    }
    return filtered;
  }

  // ── Coach Narrative (T7 — Coach AI Layer) ──

  /// Charge la couche Coach IA pour le dashboard.
  ///
  /// Sequence:
  /// 1) Narrative globale (BYOK ou fallback statique)
  /// 2) Enrichissements complementaires uniquement si la narrative n'a pas ete
  ///    produite par le LLM (fallback/erreur), afin de reduire les appels.
  Future<void> _loadCoachAiLayer(ByokProvider byok) async {
    await _loadCoachNarrative(byok);
    if (!mounted) return;

    // Si la narrative vient deja du LLM, on evite 2 appels supplementaires
    // (tips enrichis + chiffre choc) pour limiter cout et latence.
    if (_narrative?.isLlmGenerated == true) return;

    await Future.wait<void>([
      _loadEnrichedTips(byok),
      _loadChiffreChocNarratives(byok),
    ]);
  }

  /// Load full coach narrative via BYOK LLM or static fallback.
  /// Populates _narrative which is used across the dashboard.
  Future<void> _loadCoachNarrative(ByokProvider byok) async {
    final gen = ++_narrativeGeneration;
    if (_profile == null) return;

    LlmConfig? byokConfig;
    if (byok.isConfigured) {
      final LlmProvider llmProvider;
      switch (byok.provider) {
        case 'claude':
        case 'anthropic':
          llmProvider = LlmProvider.anthropic;
        case 'mistral':
          llmProvider = LlmProvider.mistral;
        default:
          llmProvider = LlmProvider.openai;
      }
      byokConfig = LlmConfig(
        apiKey: byok.apiKey!,
        provider: llmProvider,
      );
    }

    final narrative = await CoachNarrativeService.generate(
      profile: _profile!,
      scoreHistory: _scoreHistory,
      tips: _coachingTips,
      byokConfig: byokConfig,
    );

    if (mounted && gen == _narrativeGeneration) {
      setState(() => _narrative = narrative);
    }
  }

  bool _hasOnboarding30PlanToResume() {
    if (!_onboarding30PlanLoaded) return false;
    final startedAt = _onboarding30PlanState['started_at'];
    final completed = _onboarding30PlanState['completed'] == true;
    return startedAt != null && !completed;
  }

  int _onboarding30OpenedCount() {
    final opened = _onboarding30PlanState['opened_routes'];
    if (opened is List) return opened.length;
    return 0;
  }

  String _onboarding30ResumeRoute() {
    final lastRoute = _onboarding30PlanState['last_route'];
    if (lastRoute is String && lastRoute.isNotEmpty) return lastRoute;
    return '/advisor/plan-30-days';
  }

  // ── Check-in state helpers ──

  bool _isCheckInDoneThisMonth() {
    if (_profile == null) return false;
    final now = DateTime.now();
    return _profile!.checkIns.any(
      (ci) => ci.month.year == now.year && ci.month.month == now.month,
    );
  }

  Widget _buildCheckInReminderCard() {
    if (_isCheckInDoneThisMonth()) return const SizedBox.shrink();

    final streakResult = StreakService.compute(_profile!);
    final streak = streakResult.currentStreak;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: GestureDetector(
        onTap: () {
          AnalyticsService().trackCTAClick(
            'checkin_card',
            screenName: 'coach_dashboard',
          );
          context.push('/coach/checkin');
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF10B981), Color(0xFF059669)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.calendar_today_outlined,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Check-in mensuel disponible',
                      style: GoogleFonts.montserrat(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Confirme tes versements du mois en 2 min',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    if (streak > 0) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.local_fire_department,
                            color: Color(0xFFFFD54F),
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Serie : $streak mois consecutifs',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFFFD54F),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRefreshBanner() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              MintColors.coachAccent.withAlpha(25),
              Colors.white,
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: MintColors.coachAccent.withAlpha(75),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.update, color: MintColors.coachAccent),
                const SizedBox(width: 8),
                Text(
                  'Check-up annuel',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: MintColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Ton profil date de plus de 11 mois. Quelques questions rapides pour mettre tes donnees a jour.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: MintColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.push('/coach/refresh'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: MintColors.coachAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Mettre a jour',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResumePlan30Card() {
    if (!_hasOnboarding30PlanToResume()) return const SizedBox.shrink();
    final openedCount = _onboarding30OpenedCount();
    final progress = (openedCount / 3).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MintColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: MintColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.event_repeat_rounded,
                  size: 18,
                  color: MintColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Reprendre mon plan 30 jours',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: MintColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: MintColors.lightBorder,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(MintColors.primary),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$openedCount/3 etapes ouvertes',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: MintColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () async {
                final route = _onboarding30ResumeRoute();
                await context.push(route);
                if (!mounted) return;
                await _loadOnboarding30PlanState();
              },
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: const Text('Continuer'),
              style: FilledButton.styleFrom(
                backgroundColor: MintColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final coachProvider = context.watch<CoachProfileProvider>();

    // Loading state — provider hasn't finished loading yet
    if (coachProvider.isLoading || !coachProvider.isLoaded) {
      return const Scaffold(
        backgroundColor: MintColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // ── ETAT C : Utilisateur curieux (pas de profil) ──
    if (!coachProvider.hasProfile) {
      if (!_didTrackDashboardView) {
        _didTrackDashboardView = true;
        AnalyticsService().trackEvent(
          'dashboard_viewed',
          category: 'engagement',
          data: {'state': 'empty'},
          screenName: 'coach_dashboard',
        );
      }
      return _buildEmptyDashboard();
    }

    // ── ETAT B : Profil partiel (mini-onboarding) ──
    if (coachProvider.isPartialProfile) {
      if (!_didTrackDashboardView) {
        _didTrackDashboardView = true;
        AnalyticsService().trackEvent(
          'dashboard_viewed',
          category: 'engagement',
          data: {'state': 'partial'},
          screenName: 'coach_dashboard',
        );
      }
      return _buildPartialDashboard();
    }

    // ── ETAT A : Dashboard complet (profil existe) ──
    if (_profile == null || _score == null || _projection == null) {
      return const Scaffold(
        backgroundColor: MintColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_didTrackDashboardView) {
      _didTrackDashboardView = true;
      AnalyticsService().trackEvent(
        'dashboard_viewed',
        category: 'engagement',
        data: {
          'state': 'full',
          'score': _score!.global,
          'scenario_count': 3,
        },
        screenName: 'coach_dashboard',
      );
    }

    return Scaffold(
      backgroundColor: MintColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildCoachPulseCard(),
                const SizedBox(height: 10),
                _buildNarrativeModeControl(),
                const SizedBox(height: 16),
                _buildCoachAlertCard(),
                _buildMilestoneNarrativeChip(),
                const SizedBox(height: 24),
                _buildCheckInReminderCard(),
                if (_showRefreshBanner) _buildRefreshBanner(),
                _buildResumePlan30Card(),
                if (_hasOnboarding30PlanToResume()) const SizedBox(height: 24),
                const ExploreHub(),
                const SizedBox(height: 24),
                _buildScoreSection(),
                const SizedBox(height: 24),
                ChiffreChocSection(
                  profile: _profile!,
                  narratives: _chiffreChocNarratives,
                ),
                const SizedBox(height: 24),
                // Guard rail: only show trajectory if confidence >= threshold
                if (_confidenceScore >= ConfidenceScorer.minConfidenceForProjection) ...[
                  TrajectoryCard(
                    profile: _profile!,
                    projection: _projection!,
                    etSiProjection: _etSiProjection,
                  ),
                  const SizedBox(height: 24),
                ] else ...[
                  LowConfidenceCard(profile: _profile!),
                  const SizedBox(height: 24),
                ],
                // Early retirement comparison for 45+ users
                if (_profile!.age >= 45) ...[
                  EarlyRetirementComparison(profile: _profile!),
                  const SizedBox(height: 24),
                ],
                _buildQuickActions(),
                const SizedBox(height: 12),
                _buildDashboardDensityToggle(),
                if (!_compactMode) ...[
                  const SizedBox(height: 24),
                  _buildScoreAttribution(),
                  _buildStreakBadge(),
                  _buildScoreTrendText(),
                  _buildScoreHistorySection(),
                  const SizedBox(height: 24),
                  if (_confidenceScore >= ConfidenceScorer.minConfidenceForProjection) ...[
                    _buildNowVsWithCard(),
                    _buildScenarioNarrations(),
                    const SizedBox(height: 12),
                    _buildEtSiPanel(),
                  ],
                  const SizedBox(height: 24),
                  _buildBenchmarkSection(),
                  const SizedBox(height: 24),
                  _buildStreakMilestoneSection(),
                ],
                const SizedBox(height: 24),
                _buildAskMintCard(),
                const SizedBox(height: 32),
                _buildDisclaimer(),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardDensityToggle() {
    final label = _compactMode
        ? 'Afficher le dashboard complet'
        : 'Revenir au mode focus';
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => setState(() => _compactMode = !_compactMode),
        icon: Icon(
          _compactMode ? Icons.unfold_more : Icons.unfold_less,
          size: 18,
        ),
        label: Text(label),
      ),
    );
  }

  Widget _buildResetMenuButton() {
    return PopupMenuButton<_DashboardResetAction>(
      tooltip: 'Réinitialiser',
      icon: const Icon(Icons.tune, color: Colors.white),
      onSelected: (value) => _handleResetAction(value),
      itemBuilder: (_) => const [
        PopupMenuItem<_DashboardResetAction>(
          value: _DashboardResetAction.resetHistory,
          child: Text('Réinitialiser mon historique coach'),
        ),
        PopupMenuItem<_DashboardResetAction>(
          value: _DashboardResetAction.resetDiagnostic,
          child: Text('Recommencer mon diagnostic'),
        ),
      ],
    );
  }

  Future<void> _handleResetAction(_DashboardResetAction action) async {
    if (action == _DashboardResetAction.resetHistory) {
      final confirmed = await _confirmResetDialog(
        title: 'Réinitialiser ton historique coach ?',
        message:
            'Cela supprime tes check-ins, ton historique de score et la progression des simulateurs.',
        cta: 'Réinitialiser',
      );
      if (confirmed != true || !mounted) return;

      await ReportPersistenceService.clearCoachHistory();
      if (!mounted) return;
      await context.read<CoachProfileProvider>().loadFromWizard();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Historique coach réinitialisé.')),
      );
      return;
    }

    final confirmed = await _confirmResetDialog(
      title: 'Recommencer ton diagnostic ?',
      message:
          'Cela supprime ton diagnostic actuel et tes réponses mini-onboarding.',
      cta: 'Recommencer',
    );
    if (confirmed != true || !mounted) return;

    await ReportPersistenceService.clearDiagnostic();
    await ReportPersistenceService.clearCoachHistory();
    if (!mounted) return;
    context.read<CoachProfileProvider>().clear();
    context.go('/advisor');
  }

  Future<bool?> _confirmResetDialog({
    required String title,
    required String message,
    required String cta,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(cta),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  ETAT B : PARTIAL DASHBOARD (mini-onboarding complete)
  // ════════════════════════════════════════════════════════════════
  //
  // Affiche un chiffre choc personnalise + score estimatif
  // avec un badge precision + CTA "Enrichir" vers le wizard.
  // ════════════════════════════════════════════════════════════════

  Widget _buildPartialDashboard() {
    final provider = context.watch<CoachProfileProvider>();
    final completeness = provider.profileCompleteness;
    final dataPoints = provider.dataPointsCount;
    final qualityScore = (provider.onboardingQualityScore * 100).round();

    return Scaffold(
      backgroundColor: MintColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Precision badge
                _buildPrecisionBadge(completeness, dataPoints),
                const SizedBox(height: 12),
                _buildDataQualityTrustCard(
                  completeness: completeness,
                  dataPoints: dataPoints,
                ),
                const SizedBox(height: 10),
                _buildPersonaGuidanceCard(provider, qualityScore),
                const SizedBox(height: 12),
                _buildCoachPulseCard(),
                _buildMilestoneNarrativeChip(),
                const SizedBox(height: 20),
                _buildResumePlan30Card(),
                if (_hasOnboarding30PlanToResume()) const SizedBox(height: 20),
                const ExploreHub(),
                const SizedBox(height: 20),
                // Chiffre choc (main value proposition)
                if (_profile != null)
                  ChiffreChocSection(
                    profile: _profile!,
                    narratives: _chiffreChocNarratives,
                  ),
                if (_profile != null) const SizedBox(height: 24),
                // Estimated score with "enrichir" prompt
                _buildPartialScoreCard(provider),
                const SizedBox(height: 24),
                // Teaser trajectory (blurred, but less aggressive)
                _buildTeaserTrajectory(),
                const SizedBox(height: 24),
                // Quick win cards
                _buildQuickWinCards(),
                const SizedBox(height: 24),
                // Enrichir CTA
                _buildEnrichirBanner(provider),
                const SizedBox(height: 24),
                // Ask MINT
                _buildAskMintCard(),
                const SizedBox(height: 32),
                _buildDisclaimer(),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _openRecommendedWizardSection(CoachProfileProvider provider) {
    final section = provider.recommendedWizardSection;
    context.push('/advisor/wizard?section=$section');
  }

  String _personaGuidanceTitle(CoachProfileProvider provider) {
    final s = S.of(context);
    switch (provider.personaKey) {
      case 'couple':
        return s?.coachPersonaPriorityCouple ?? 'Priorite couple';
      case 'family':
        return s?.coachPersonaPriorityFamily ?? 'Priorite famille';
      case 'single_parent':
        return s?.coachPersonaPrioritySingleParent ?? 'Priorite parent solo';
      default:
        return s?.coachPersonaPrioritySingle ?? 'Priorite personnelle';
    }
  }

  String _personaGuidanceBody(CoachProfileProvider provider) {
    final s = S.of(context);
    final section = provider.recommendedWizardSection;
    final sectionLabel = switch (section) {
      'identity' => s?.coachWizardSectionIdentity ?? 'Identite & foyer',
      'income' => s?.coachWizardSectionIncome ?? 'Revenu & foyer',
      'pension' => s?.coachWizardSectionPension ?? 'Prevoyance',
      'property' => s?.coachWizardSectionProperty ?? 'Immobilier & dettes',
      _ => s?.advisorMiniFullDiagnostic ?? 'Diagnostic',
    };
    switch (provider.personaKey) {
      case 'couple':
      case 'family':
        return s?.coachPersonaGuidanceCouple(sectionLabel) ??
            'Pour fiabiliser tes projections foyer, complete maintenant la section $sectionLabel.';
      case 'single_parent':
        return s?.coachPersonaGuidanceSingleParent(sectionLabel) ??
            'Ton plan depend de la protection du foyer. Complete maintenant la section $sectionLabel.';
      default:
        return s?.coachPersonaGuidanceSingle(sectionLabel) ??
            'Pour personnaliser ton plan coach, complete maintenant la section $sectionLabel.';
    }
  }

  String _enrichBannerTitle(CoachProfileProvider provider) {
    final s = S.of(context);
    final pct = (provider.onboardingQualityScore * 100).round();
    return s?.coachEnrichTargetTitle('$pct', '60') ??
        'Passe de $pct% a 60% de precision';
  }

  String _enrichBannerBody(CoachProfileProvider provider) {
    final s = S.of(context);
    final section = provider.recommendedWizardSection;
    switch (section) {
      case 'identity':
        return s?.coachEnrichBodyIdentity ??
            'Ajoute les bases identite/foyer pour activer des calculs fiables des aujourd hui.';
      case 'income':
        return s?.coachEnrichBodyIncome ??
            'Complete revenus et structure du foyer pour des recommandations vraiment personnalisees.';
      case 'pension':
        return s?.coachEnrichBodyPension ??
            'Renseigne AVS/LPP/3a pour une projection retraite exploitable.';
      case 'property':
        return s?.coachEnrichBodyProperty ??
            'Ajoute immobilier et dettes pour calibrer ton budget et ton risque reel.';
      default:
        return s?.coachEnrichBodyDefault ??
            'Le diagnostic complet prend 10 minutes et deverrouille ta trajectoire personnalisee.';
    }
  }

  String _enrichButtonLabel(CoachProfileProvider provider) {
    final s = S.of(context);
    return switch (provider.recommendedWizardSection) {
      'identity' =>
        s?.coachEnrichActionIdentity ?? 'Completer Identite & foyer',
      'income' => s?.coachEnrichActionIncome ?? 'Completer Revenu & foyer',
      'pension' => s?.coachEnrichActionPension ?? 'Completer Prevoyance',
      'property' =>
        s?.coachEnrichActionProperty ?? 'Completer Immobilier & dettes',
      _ => s?.coachEnrichActionDefault ?? 'Completer mon diagnostic',
    };
  }

  Widget _buildPersonaGuidanceCard(
    CoachProfileProvider provider,
    int qualityScore,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MintColors.appleSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: MintColors.info.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.radar, color: MintColors.info, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_personaGuidanceTitle(provider)} · $qualityScore%',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _personaGuidanceBody(provider),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: MintColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  //  B.1 PRECISION BADGE
  // ────────────────────────────────────────────────────────────

  Widget _buildPrecisionBadge(double completeness, int dataPoints) {
    final percentage = (completeness * 100).round();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: MintColors.coachBubble,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: MintColors.scoreAttention.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.tune,
              color: MintColors.scoreAttention,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Precision : $percentage%',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Base sur $dataPoints donnees — enrichis ton profil pour plus de precision',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: MintColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Mini progress ring
          SizedBox(
            width: 36,
            height: 36,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: completeness,
                  strokeWidth: 3,
                  backgroundColor: MintColors.lightBorder,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      MintColors.scoreAttention),
                ),
                Text(
                  '$percentage',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: MintColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataQualityTrustCard({
    required double completeness,
    required int dataPoints,
  }) {
    final l10n = S.of(context);
    final percentage = (completeness * 100).round();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MintColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.verified_user_outlined,
                size: 16,
                color: MintColors.info,
              ),
              const SizedBox(width: 8),
              Text(
                l10n?.coachDataQualityTitle ?? 'Qualite des donnees',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n?.coachDataQualityBody('$dataPoints', '$percentage') ??
                'Calcul actuel: $dataPoints donnees saisies ($percentage%). '
                    'Les postes non renseignes restent en estimation jusqu au diagnostic complet.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: MintColors.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          const Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _TrustChip(label: 'saisi', color: MintColors.success),
              _TrustChip(label: 'estime', color: MintColors.warning),
              _TrustChip(label: 'a completer', color: MintColors.textMuted),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCoachPulseCard() {
    final l10n = S.of(context);
    final pulseTextRaw = _narrative?.scoreSummary ?? _defaultCoachPulseText();
    final pulseText =
        CoachNarrativeService.applyDetailMode(pulseTextRaw, _narrativeMode);
    final hasLlmNarrative = _narrative != null && _narrative!.isLlmGenerated;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MintColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasLlmNarrative
              ? MintColors.info.withValues(alpha: 0.35)
              : MintColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                size: 16,
                color: MintColors.info,
              ),
              const SizedBox(width: 8),
              Text(
                l10n?.coachPulseTitle ?? 'Coach Pulse',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textPrimary,
                ),
              ),
              const Spacer(),
              if (hasLlmNarrative)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: MintColors.info.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'personnalise',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: MintColors.info,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            pulseText,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              height: 1.4,
              color: MintColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNarrativeModeControl() {
    final l10n = S.of(context);
    return Align(
      alignment: Alignment.centerRight,
      child: SegmentedButton<CoachNarrativeMode>(
        segments: [
          ButtonSegment<CoachNarrativeMode>(
            value: CoachNarrativeMode.concise,
            label: Text(l10n?.coachNarrativeModeConcise ?? 'Court'),
          ),
          ButtonSegment<CoachNarrativeMode>(
            value: CoachNarrativeMode.detailed,
            label: Text(l10n?.coachNarrativeModeDetailed ?? 'Détail'),
          ),
        ],
        selected: {_narrativeMode},
        onSelectionChanged: (selection) {
          if (selection.isEmpty) return;
          unawaited(_setNarrativeMode(selection.first));
        },
        showSelectedIcon: false,
        emptySelectionAllowed: false,
        multiSelectionEnabled: false,
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: WidgetStatePropertyAll(
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          ),
          textStyle: WidgetStatePropertyAll(
            GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  String _defaultCoachPulseText() {
    if (_score == null) {
      return 'Ton profil est en cours de construction. Complete ton diagnostic pour activer un plan plus precis.';
    }
    final score = _score!.global.round();
    if (score >= 75) {
      return 'Tu avances bien. Priorite du mois: verrouille une action a fort impact pour maintenir ta trajectoire.';
    }
    if (score >= 55) {
      return 'Ta base est correcte, mais il reste des optimisations claires. Active une action prioritaire pour gagner des points rapidement.';
    }
    return 'Ton plan a besoin d une stabilisation rapide. Commence par la protection budget/dettes avant les optimisations long terme.';
  }

  // ────────────────────────────────────────────────────────────
  //  B.2 PARTIAL SCORE CARD — score estimatif avec badge
  // ────────────────────────────────────────────────────────────

  Widget _buildPartialScoreCard(CoachProfileProvider provider) {
    if (_score == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ton Fitness Financier (estimatif)',
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: MintColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: MintColors.card,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              MintScoreGauge(
                score: _score!.global,
                budgetScore: _score!.budget.score,
                prevoyanceScore: _score!.prevoyance.score,
                patrimoineScore: _score!.patrimoine.score,
                trend: _score!.trend.name,
                previousScore: null,
                onTap: () {},
              ),
              const SizedBox(height: 16),
              // Estimation disclaimer
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: MintColors.scoreAttention.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        color: MintColors.scoreAttention, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Score estimatif base sur 4 donnees. '
                        'Complete le diagnostic pour un score precis.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: MintColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _openRecommendedWizardSection(provider),
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: Text(
                    _enrichButtonLabel(provider),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: MintColors.primary,
                    side:
                        const BorderSide(color: MintColors.primary, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────
  //  B.3 ENRICHIR BANNER
  // ────────────────────────────────────────────────────────────

  Widget _buildEnrichirBanner(CoachProfileProvider provider) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            MintColors.primary,
            MintColors.primary.withValues(alpha: 0.88),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: MintColors.primary.withValues(alpha: 0.20),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.rocket_launch_outlined,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _enrichBannerTitle(provider),
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _enrichBannerBody(provider),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: Colors.white.withValues(alpha: 0.85),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => _openRecommendedWizardSection(provider),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: MintColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                _enrichButtonLabel(provider),
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  ETAT C : EMPTY DASHBOARD (utilisateur curieux)
  // ════════════════════════════════════════════════════════════════

  Widget _buildEmptyDashboard() {
    return Scaffold(
      backgroundColor: MintColors.background,
      body: CustomScrollView(
        slivers: [
          _buildEmptyAppBar(),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildEmptyScoreCard(),
                const SizedBox(height: 24),
                _buildResumePlan30Card(),
                if (_hasOnboarding30PlanToResume()) const SizedBox(height: 24),
                const ExploreHub(),
                const SizedBox(height: 24),
                _buildTeaserTrajectory(),
                const SizedBox(height: 24),
                _buildQuickWinCards(),
                const SizedBox(height: 24),
                _buildAskMintCard(),
                const SizedBox(height: 24),
                _buildMotivationBanner(),
                const SizedBox(height: 32),
                _buildDisclaimer(),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  //  B1. EMPTY APP BAR
  // ────────────────────────────────────────────────────────────

  Widget _buildEmptyAppBar() {
    final l10n = S.of(context);
    final isCompact = MediaQuery.of(context).size.height <= 760;
    return SliverAppBar(
      pinned: true,
      expandedHeight: isCompact ? 74 : 90,
      toolbarHeight: isCompact ? 44 : 48,
      automaticallyImplyLeading: false,
      backgroundColor: MintColors.primary,
      actions: [
        _buildResetMenuButton(),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: EdgeInsets.only(
          left: 20,
          bottom: isCompact ? 10 : 12,
          right: 20,
        ),
        title: Text(
          l10n?.coachWelcome ?? 'Bienvenue sur MINT',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            fontSize: isCompact ? 18 : 20,
            color: Colors.white,
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                MintColors.primary,
                MintColors.primary.withValues(alpha: 0.85),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  //  B2. EMPTY SCORE CARD — jauge grisee avec "?"
  // ────────────────────────────────────────────────────────────

  Widget _buildEmptyScoreCard() {
    final l10n = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n?.coachFitnessTitle ?? 'Ton Fitness Financier',
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: MintColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => context.push('/advisor'),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: MintColors.card,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // ── Header ──
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: MintColors.border.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.fitness_center,
                        color: MintColors.textMuted,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n?.coachFinancialForm ?? 'Forme financière',
                            style: GoogleFonts.montserrat(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: MintColors.textPrimary,
                            ),
                          ),
                          Text(
                            l10n?.coachScoreComposite ??
                                'Score composite · 3 piliers',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: MintColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: MintColors.border.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '?',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: MintColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Grayed-out gauge with "?" ──
                SizedBox(
                  width: 180,
                  height: 180,
                  child: CustomPaint(
                    painter: _EmptyGaugePainter(),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '?',
                            style: GoogleFonts.montserrat(
                              fontSize: 56,
                              fontWeight: FontWeight.w800,
                              color: MintColors.border,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '/100',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color:
                                  MintColors.textMuted.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Grayed-out sub-score bars ──
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: MintColors.surface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      _buildEmptySubScoreBar(
                        label: l10n?.coachPillarBudget ?? 'Budget',
                        icon: Icons.account_balance_wallet_outlined,
                      ),
                      const SizedBox(height: 12),
                      _buildEmptySubScoreBar(
                        label: l10n?.coachPillarPrevoyance ?? 'Prévoyance',
                        icon: Icons.shield_outlined,
                      ),
                      const SizedBox(height: 12),
                      _buildEmptySubScoreBar(
                        label: l10n?.coachPillarPatrimoine ?? 'Patrimoine',
                        icon: Icons.trending_up,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── CTA text ──
                Text(
                  l10n?.coachCompletePrompt ??
                      'Complète ton diagnostic pour découvrir ton score',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: MintColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),

                // ── CTA button ──
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => context.push('/advisor'),
                    icon: const Icon(Icons.play_arrow_rounded, size: 20),
                    label: Text(
                      l10n?.coachDiscoverScore ??
                          'Découvrir mon score \u2014 10 min',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: MintColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptySubScoreBar({
    required String label,
    required IconData icon,
  }) {
    return Row(
      children: [
        Icon(icon,
            size: 16, color: MintColors.textMuted.withValues(alpha: 0.5)),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: MintColors.textMuted.withValues(alpha: 0.5),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: const SizedBox(
              height: 8,
              child: LinearProgressIndicator(
                value: 0,
                backgroundColor: MintColors.lightBorder,
                color: MintColors.border,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 32,
          child: Text(
            '--',
            textAlign: TextAlign.right,
            style: GoogleFonts.montserrat(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: MintColors.textMuted.withValues(alpha: 0.5),
            ),
          ),
        ),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────
  //  B3. TEASER TRAJECTORY — graphique floute avec overlay
  // ────────────────────────────────────────────────────────────

  Widget _buildTeaserTrajectory() {
    final l10n = S.of(context);

    // Show REAL trajectory with disclaimer when projection data exists
    if (_projection != null && _profile != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                l10n?.coachTrajectory ?? 'Ta trajectoire',
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: MintColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Estimation partielle',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: MintColors.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: MintColors.card,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                MintTrajectoryChart(
                  result: _projection!,
                  goalALabel: _profile!.goalA.label,
                  goalAType: _profile!.goalA.type,
                  initialDebt: _profile!.dettes.totalDettes,
                  onTap: () {
                    final provider = context.read<CoachProfileProvider>();
                    _openRecommendedWizardSection(provider);
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'Complete ton diagnostic pour affiner cette projection.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: MintColors.textMuted,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Fallback: blurred teaser when no projection data yet
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n?.coachTrajectory ?? 'Ta trajectoire',
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: MintColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => context.push('/advisor'),
          child: Container(
            decoration: BoxDecoration(
              color: MintColors.card,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: SizedBox(
                      height: 180,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: _PlaceholderTrajectoryPainter(),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      final glowOpacity = 0.03 + (_pulseAnimation.value * 0.05);
                      return Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: RadialGradient(
                            center: Alignment.center,
                            radius: 0.8,
                            colors: [
                              MintColors.coachAccent
                                  .withValues(alpha: glowOpacity),
                              Colors.white.withValues(alpha: 0.85),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Positioned.fill(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: MintColors.coachAccent
                                  .withValues(alpha: 0.10),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.timeline_rounded,
                              color: MintColors.coachAccent,
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            l10n?.coachTrajectoryPrompt ??
                                'Ta trajectoire financiere t\'attend',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.montserrat(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: MintColors.textPrimary,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '3 scenarios personnalises selon ta situation',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: MintColors.textSecondary,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────
  //  B4. QUICK WIN CARDS — faits educatifs
  // ────────────────────────────────────────────────────────────

  Widget _buildQuickWinCards() {
    final l10n = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n?.coachDidYouKnow ?? 'Le savais-tu ?',
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: MintColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        _buildQuickWinCard(
          icon: Icons.savings_outlined,
          iconColor: MintColors.scoreExcellent,
          fact: l10n?.coachFact3a ??
              'Le 3e pilier peut te faire économiser jusqu\'à CHF 2\'500 d\'impôts par an, selon ton canton et ton revenu.',
          route: '/simulator/3a',
          linkLabel: l10n?.coachFact3aLink ?? 'Simuler mon économie 3a',
        ),
        const SizedBox(height: 12),
        _buildQuickWinCard(
          icon: Icons.shield_outlined,
          iconColor: MintColors.scoreAttention,
          fact: l10n?.coachFactAvs ??
              'En Suisse, chaque année AVS manquante = −2.3% de rente à vie. Un rattrapage est possible dans certains cas.',
          route: '/retirement',
          linkLabel: l10n?.coachFactAvsLink ?? 'Vérifier mes années AVS',
        ),
        const SizedBox(height: 12),
        _buildQuickWinCard(
          icon: Icons.account_balance_outlined,
          iconColor: MintColors.coachAccent,
          fact: l10n?.coachFactLpp ??
              'Le rachat LPP est l\'un des leviers fiscaux les plus puissants pour les salarié·es en Suisse. Il est intégralement déductible du revenu imposable.',
          route: '/lpp-deep/rachat',
          linkLabel: l10n?.coachFactLppLink ?? 'Explorer le rachat LPP',
        ),
      ],
    );
  }

  Widget _buildQuickWinCard({
    required IconData icon,
    required Color iconColor,
    required String fact,
    required String route,
    required String linkLabel,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: MintColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  fact,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: MintColors.textPrimary,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => context.push(route),
              style: TextButton.styleFrom(
                foregroundColor: MintColors.coachAccent,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    linkLabel,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward, size: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  //  B5. MOTIVATION BANNER
  // ────────────────────────────────────────────────────────────

  Widget _buildMotivationBanner() {
    final l10n = S.of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            MintColors.primary,
            MintColors.primary.withValues(alpha: 0.88),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: MintColors.primary.withValues(alpha: 0.20),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.people_outline_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n?.coachMotivation ??
                'Rejoins les milliers d\'utilisateurs qui ont déjà fait leur diagnostic financier',
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n?.coachMotivationSub ?? 'et recevoir des actions concrètes.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: Colors.white.withValues(alpha: 0.85),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => context.push('/advisor'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: MintColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                l10n?.coachLaunchDiagnostic ?? 'Lancer mon diagnostic',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  ETAT A : DASHBOARD COMPLET (profil existe)
  // ════════════════════════════════════════════════════════════════

  // ════════════════════════════════════════════════════════════════
  //  1. SLIVER APP BAR
  // ════════════════════════════════════════════════════════════════

  Widget _buildAppBar() {
    final l10n = S.of(context);
    final rawName = _profile!.firstName;
    final firstName =
        (rawName != null && rawName.isNotEmpty && rawName.toLowerCase() != 'utilisateur')
            ? rawName
            : null;
    final isCompact = MediaQuery.of(context).size.height <= 760;
    return SliverAppBar(
      pinned: true,
      expandedHeight: isCompact ? 74 : 90,
      toolbarHeight: isCompact ? 44 : 48,
      automaticallyImplyLeading: false,
      backgroundColor: MintColors.primary,
      actions: [
        _buildResetMenuButton(),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: EdgeInsets.only(
          left: 20,
          bottom: isCompact ? 10 : 12,
          right: 20,
        ),
        title: Text(
          _narrative?.greeting ??
              (firstName != null
                  ? (l10n?.coachHello(firstName) ?? 'Bonjour $firstName')
                  : 'Bonjour'),
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            fontSize: isCompact ? 18 : 20,
            color: Colors.white,
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                MintColors.primary,
                MintColors.primary.withValues(alpha: 0.85),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  2. COACH ALERT CARD
  // ════════════════════════════════════════════════════════════════

  /// Build a dynamic coaching card based on the user's biggest gap.
  ///
  /// Instead of a generic message per fitness level, this surfaces
  /// the most impactful coaching tip with a specific CHF amount
  /// and a direct CTA to the relevant simulator.
  ///
  /// Urgency levels:
  /// - Alerte urgente (haute priority + deadline proche): red border, warning icon
  /// - Conseil actif (haute priority, no deadline): orange border
  /// - Info coach (moyenne/basse): green border
  Widget _buildCoachAlertCard() {
    final tips = _coachingTips;
    final topTip = tips.isNotEmpty ? tips.first : null;

    // Determine urgency level from tip priority + deadline proximity
    final _AlertUrgency urgency = _computeAlertUrgency(topTip);

    final Color borderColor;
    final IconData iconData;
    switch (urgency) {
      case _AlertUrgency.urgent:
        borderColor = const Color(0xFFEF4444); // red
        iconData = Icons.warning_amber_rounded;
      case _AlertUrgency.active:
        borderColor = const Color(0xFFF59E0B); // orange
        iconData = Icons.lightbulb_outline;
      case _AlertUrgency.info:
        borderColor = const Color(0xFF10B981); // green
        iconData = Icons.info_outline;
    }

    // Compute deadline countdown for known tips
    final String? deadlineText = _computeDeadlineText(topTip);

    // Use the top coaching tip if available; fallback to generic message
    final String message;
    final String? ctaLabel;
    final String? ctaRoute;
    if (topTip != null) {
      message = topTip.narrativeMessage ??
          (_narrative?.topTipNarrative ?? topTip.message);
      ctaLabel = topTip.action;
      ctaRoute = tipRoute(topTip);
    } else {
      message = _score!.coachMessage;
      ctaLabel = null;
      ctaRoute = null;
    }

    // Count active (non-dismissed) tips
    final activeTipCount = tips.length;

    // T7: Build urgent alert widget from narrative if available
    final Widget? urgentAlertWidget;
    if (_narrative?.urgentAlert != null) {
      urgentAlertWidget = Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(12),
          border: const Border(
            left: BorderSide(color: Color(0xFFEF4444), width: 4),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Color(0xFFEF4444), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _narrative!.urgentAlert!,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFFEF4444),
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      urgentAlertWidget = null;
    }

    final alertCard = Container(
      decoration: BoxDecoration(
        color: urgency == _AlertUrgency.urgent
            ? const Color(0xFFFEF2F2)
            : MintColors.coachBubble,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(color: borderColor, width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(topTip?.icon ?? iconData, color: borderColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (topTip != null) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              topTip.title,
                              style: GoogleFonts.montserrat(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: MintColors.textPrimary,
                              ),
                            ),
                          ),
                          if (deadlineText != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: borderColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                deadlineText,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: borderColor,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      message,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: MintColors.textPrimary,
                        height: 1.5,
                      ),
                    ),
                    if (topTip?.estimatedImpactChf != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: borderColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Impact estime : ~CHF ${topTip!.estimatedImpactChf!.toStringAsFixed(0)}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: borderColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Active tips count badge
              if (activeTipCount > 1)
                GestureDetector(
                  onTap: () => context.push('/coach/agir'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: MintColors.textSecondary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${activeTipCount - 1} autre${activeTipCount > 2 ? 's' : ''} action${activeTipCount > 2 ? 's' : ''}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: MintColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              const Spacer(),
              TextButton(
                onPressed: () => context.push(ctaRoute ?? '/report'),
                style: TextButton.styleFrom(
                  foregroundColor: borderColor,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      ctaLabel ?? 'Explorer',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward, size: 16),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    // T7: Wrap with urgent alert if present
    if (urgentAlertWidget != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          urgentAlertWidget,
          alertCard,
        ],
      );
    }

    return alertCard;
  }

  _AlertUrgency _computeAlertUrgency(CoachingTip? tip) {
    if (tip == null) return _AlertUrgency.info;
    if (tip.priority != CoachingPriority.haute) return _AlertUrgency.info;

    // Check if this tip has an imminent deadline
    final deadlineDays = _getDeadlineDaysForTip(tip);
    if (deadlineDays != null && deadlineDays <= 30) {
      return _AlertUrgency.urgent;
    }

    return _AlertUrgency.active;
  }

  String? _computeDeadlineText(CoachingTip? tip) {
    if (tip == null) return null;
    final days = _getDeadlineDaysForTip(tip);
    if (days == null || days < 0) return null;
    if (days == 0) return "Aujourd'hui";
    if (days == 1) return 'Demain';
    return 'J-$days';
  }

  int? _getDeadlineDaysForTip(CoachingTip tip) {
    final now = DateTime.now();
    DateTime? deadline;

    switch (tip.id) {
      case 'deadline_3a':
        // 3a must be paid by Dec 31
        deadline = DateTime(now.year, 12, 31);
      case 'tax_deadline':
        // Tax declaration due March 31
        deadline = DateTime(now.year, 3, 31);
      default:
        return null;
    }

    return deadline.difference(now).inDays;
  }

  // ════════════════════════════════════════════════════════════════
  //  2B. NOW VS WITH MINT ACTIONS
  // ════════════════════════════════════════════════════════════════

  Widget _buildNowVsWithCard() {
    if (_baselineProjection == null || _projection == null) {
      return const SizedBox.shrink();
    }

    final capitalSans = _baselineProjection!.base.capitalFinal;
    final capitalAvec = _projection!.base.capitalFinal;
    final deltaCapital = capitalAvec - capitalSans;

    final tauxSans = _baselineProjection!.tauxRemplacementBase;
    final tauxAvec = _projection!.tauxRemplacementBase;
    final deltaTaux = tauxAvec - tauxSans;

    // Guard: do not show absurd replacement rates (below 15% is clearly
    // the result of missing LPP/3a data, not reality).
    if (tauxAvec < 15 && _confidenceScore < 60) {
      return const SizedBox.shrink();
    }

    // Tax savings from 3a + LPP deductions
    // LIFD art. 9 al. 1: seuls les mariés déclarent conjointement.
    // Concubins = taxés individuellement (single).
    double taxSavingsAnnual = 0;
    double savings3a = 0;
    double savingsLpp = 0;
    if (_profile != null) {
      final profile = _profile!;
      final isMarriedForTax = profile.etatCivil == CoachCivilStatus.marie;
      // Married: combined household income (joint filing)
      // Single/Concubin: only main user's income (individual filing)
      final netMonthlyForTax = isMarriedForTax
          ? profile.salaireBrutMensuel * 0.87 +
              (profile.conjoint?.salaireBrutMensuel ?? 0) * 0.87
          : profile.salaireBrutMensuel * 0.87;

      if (netMonthlyForTax > 0) {
        final marginalRate = TaxEstimatorService.estimateMarginalTaxRate(
          netMonthlyIncome: netMonthlyForTax,
          cantonCode: profile.canton.isNotEmpty ? profile.canton : 'ZH',
          civilStatus: isMarriedForTax ? 'married' : 'single',
          communeName:
              (profile.commune?.isNotEmpty ?? false) ? profile.commune : null,
        );

        final annual3a = profile.total3aMensuel * 12;
        final annualLppBuyback = profile.totalLppBuybackMensuel * 12;
        savings3a =
            TaxEstimatorService.calculateTaxSavings(annual3a, marginalRate);
        savingsLpp = TaxEstimatorService.calculateTaxSavings(
            annualLppBuyback, marginalRate);
        taxSavingsAnnual = savings3a + savingsLpp;
      }
    }

    if (deltaCapital <= 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: MintColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: MintColors.success.withValues(alpha: 0.25),
          ),
          boxShadow: [
            BoxShadow(
              color: MintColors.success.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: MintColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.trending_up,
                    color: MintColors.success,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ton impact MINT',
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: MintColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Avec tes actions vs sans rien faire',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: MintColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Capital row
            _buildNowVsRow(
              label: 'Capital retraite',
              valueSans: capitalSans,
              valueAvec: capitalAvec,
              delta: deltaCapital,
              isCurrency: true,
            ),
            const SizedBox(height: 14),
            // Taux de remplacement row
            _buildNowVsRow(
              label: 'Taux de remplacement',
              valueSans: tauxSans,
              valueAvec: tauxAvec,
              delta: deltaTaux,
              isCurrency: false,
            ),
            if (taxSavingsAnnual > 0) ...[
              const SizedBox(height: 14),
              _buildTaxSavingsRow(
                totalSavings: taxSavingsAnnual,
                savings3a: savings3a,
                savingsLpp: savingsLpp,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNowVsRow({
    required String label,
    required double valueSans,
    required double valueAvec,
    required double delta,
    required bool isCurrency,
  }) {
    String fmt(double v) => isCurrency
        ? ForecasterService.formatChf(v)
        : '${v.toStringAsFixed(1)}%';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: MintColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            // Sans
            Text(
              fmt(valueSans),
              style: GoogleFonts.inter(
                fontSize: 14,
                color: MintColors.textMuted,
                decoration: TextDecoration.lineThrough,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward,
                size: 14, color: MintColors.success),
            const SizedBox(width: 8),
            // Avec
            Text(
              fmt(valueAvec),
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: MintColors.textPrimary,
              ),
            ),
            const Spacer(),
            // Delta badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: MintColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '+${fmt(delta)}',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: MintColors.success,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTaxSavingsRow({
    required double totalSavings,
    required double savings3a,
    required double savingsLpp,
  }) {
    final parts = <String>[];
    if (savings3a > 0) {
      parts.add('3a: ${ForecasterService.formatChf(savings3a)}');
    }
    if (savingsLpp > 0) {
      parts.add('LPP: ${ForecasterService.formatChf(savingsLpp)}');
    }
    final detail = parts.join(' + ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Économie d\'impôt annuelle',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: MintColors.textSecondary,
          ),
        ),
        if (detail.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            detail,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: MintColors.textMuted,
            ),
          ),
        ],
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              ForecasterService.formatChf(0),
              style: GoogleFonts.inter(
                fontSize: 14,
                color: MintColors.textMuted,
                decoration: TextDecoration.lineThrough,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward,
                size: 14, color: MintColors.success),
            const SizedBox(width: 8),
            Text(
              '${ForecasterService.formatChf(totalSavings)}/an',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: MintColors.textPrimary,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: MintColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '+${ForecasterService.formatChf(totalSavings)}',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: MintColors.success,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'LIFD art. 33 \u00b7 Estimation \u00e9ducative',
          style: GoogleFonts.inter(
            fontSize: 10,
            color: MintColors.textMuted,
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  3. SCORE SECTION
  // ════════════════════════════════════════════════════════════════

  Widget _buildScoreSection() {
    final l10n = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n?.coachFitnessTitle ?? 'Ton Fitness Financier',
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: MintColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: MintColors.card,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: MintScoreGauge(
            score: _score!.global,
            budgetScore: _score!.budget.score,
            prevoyanceScore: _score!.prevoyance.score,
            patrimoineScore: _score!.patrimoine.score,
            trend: _score!.trend.name,
            previousScore: _score!.deltaVsPreviousMonth != null
                ? _score!.global - _score!.deltaVsPreviousMonth!
                : null,
            onTap: () => context.push('/report'),
          ),
        ),
        if (_narrative?.scoreSummary != null) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: MintColors.coachBubble,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: MintColors.lightBorder),
            ),
            child: Text(
              CoachNarrativeService.applyDetailMode(
                _narrative!.scoreSummary,
                _narrativeMode,
              ),
              style: GoogleFonts.inter(
                fontSize: 12,
                color: MintColors.textSecondary,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMilestoneNarrativeChip() {
    final message = _narrative?.milestoneMessage;
    if (message == null || message.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: MintColors.success.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: MintColors.success.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(
                Icons.emoji_events_outlined,
                size: 16,
                color: MintColors.success,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: MintColors.textPrimary,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreTrendText() {
    if (_scoreHistory == null || _scoreHistory!.length < 2) {
      return const SizedBox.shrink();
    }

    final history = _scoreHistory!;
    final recent =
        history.length >= 3 ? history.sublist(history.length - 3) : history;
    final firstScore = (recent.first['score'] as num?)?.toDouble() ?? 0;
    final lastScore = (recent.last['score'] as num?)?.toDouble() ?? 0;
    final trend = lastScore - firstScore;

    final String text;
    final IconData icon;
    final Color color;

    // T7: Use LLM-generated trend message if available
    if (_narrative != null && _narrative!.isLlmGenerated) {
      text = _narrative!.trendMessage;
      // Still determine icon/color from numeric trend
      if (trend > 3) {
        icon = Icons.trending_up;
        color = const Color(0xFF10B981);
      } else if (trend < -3) {
        icon = Icons.trending_down;
        color = const Color(0xFFEF4444);
      } else {
        icon = Icons.trending_flat;
        color = const Color(0xFF6B7280);
      }
    } else if (trend > 3) {
      text = 'En progression — continue comme ca';
      icon = Icons.trending_up;
      color = const Color(0xFF10B981);
    } else if (trend < -3) {
      text = 'Attention — ton score baisse. Verifie tes actions.';
      icon = Icons.trending_down;
      color = const Color(0xFFEF4444);
    } else {
      text = 'Stable — tes efforts maintiennent le cap.';
      icon = Icons.trending_flat;
      color = const Color(0xFF6B7280);
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  3.1 SCORE ATTRIBUTION — delta pts depuis dernier check-in
  // ════════════════════════════════════════════════════════════════

  Widget _buildScoreAttribution() {
    if (_score == null) return const SizedBox.shrink();
    final coachProvider = context.read<CoachProfileProvider>();
    final previousScore = coachProvider.previousScore;
    final delta = previousScore == null
        ? (_lastScoreDeltaPersisted ?? 0)
        : _score!.global - previousScore;
    if (previousScore == null &&
        (_lastScoreDeltaReason == null || _lastScoreDeltaReason!.isEmpty)) {
      return const SizedBox.shrink();
    }
    if (delta == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
        child: Column(
          children: [
            Text(
              'Stable — tes efforts maintiennent le cap.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: MintColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (_lastScoreDeltaReason != null &&
                _lastScoreDeltaReason!.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                CoachNarrativeService.applyDetailMode(
                  _lastScoreDeltaReason!,
                  _narrativeMode,
                ),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: MintColors.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      );
    }

    final sign = delta > 0 ? '+' : '';
    final color = delta > 0 ? MintColors.success : MintColors.warning;
    final icon = delta > 0 ? Icons.trending_up : Icons.trending_down;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                '$sign$delta pts depuis le dernier check-in',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (_lastScoreDeltaReason != null &&
              _lastScoreDeltaReason!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              CoachNarrativeService.applyDetailMode(
                _lastScoreDeltaReason!,
                _narrativeMode,
              ),
              style: GoogleFonts.inter(
                fontSize: 12,
                color: MintColors.textMuted,
                height: 1.35,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  3.2 STREAK BADGE — serie + badges gagnes
  // ════════════════════════════════════════════════════════════════

  Widget _buildStreakBadge() {
    if (_streak == null || _profile == null) return const SizedBox.shrink();

    final streak = _streak!;

    // No check-ins at all: show onboarding message
    if (streak.currentStreak == 0 && _profile!.checkIns.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_fire_department,
              size: 18,
              color: MintColors.textMuted,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Commence ta serie avec un check-in mensuel',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: MintColors.textMuted,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // No current streak (had check-ins but gap)
    if (streak.currentStreak == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Column(
        children: [
          // Streak row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.local_fire_department,
                size: 20,
                color: Color(0xFFFF6D00),
              ),
              const SizedBox(width: 6),
              Text(
                'Serie : ${streak.currentStreak} mois consecutifs',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFFF6D00),
                ),
              ),
            ],
          ),
          // Earned badges as chips
          if (streak.earnedBadges.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: streak.earnedBadges.map((badge) {
                return Chip(
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  avatar: Icon(badge.icon, size: 14, color: MintColors.primary),
                  label: Text(
                    badge.label,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: MintColors.textPrimary,
                    ),
                  ),
                  backgroundColor: MintColors.surface,
                  side: BorderSide(color: MintColors.lightBorder),
                  padding: EdgeInsets.zero,
                );
              }).toList(),
            ),
          ],
          // Next badge teaser
          if (streak.nextBadge != null) ...[
            const SizedBox(height: 4),
            Text(
              'Encore ${streak.monthsToNextBadge} mois pour "${streak.nextBadge!.label}"',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: MintColors.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  3a. SCORE HISTORY MINI-CHART — Evolution mensuelle du score
  // ════════════════════════════════════════════════════════════════

  /// Mois abreges en francais pour l'axe X du mini-chart.
  static const _monthLabelsFr = [
    'Jan',
    'Fev',
    'Mar',
    'Avr',
    'Mai',
    'Juin',
    'Juil',
    'Aou',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  Widget _buildScoreHistorySection() {
    if (_scoreHistory == null || _scoreHistory!.length < 2) {
      return const SizedBox.shrink();
    }

    final history = _scoreHistory!;

    // Determiner la tendance (amelioration ou degradation)
    final firstScore = (history.first['score'] as num?)?.toInt() ?? 0;
    final lastScore = (history.last['score'] as num?)?.toInt() ?? 0;
    final isImproving = lastScore >= firstScore;

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Container(
        decoration: BoxDecoration(
          color: MintColors.card,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Evolution de ton score',
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: MintColors.textPrimary,
                    ),
                  ),
                ),
                // Badge tendance
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isImproving
                        ? MintColors.success.withValues(alpha: 0.12)
                        : MintColors.scoreAttention.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isImproving ? Icons.trending_up : Icons.trending_down,
                        size: 14,
                        color: isImproving
                            ? MintColors.success
                            : MintColors.scoreAttention,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${lastScore - firstScore > 0 ? '+' : ''}${lastScore - firstScore} pts',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isImproving
                              ? MintColors.success
                              : MintColors.scoreAttention,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Mini-chart
            SizedBox(
              height: 80,
              width: double.infinity,
              child: CustomPaint(
                painter: _ScoreHistoryPainter(
                  history: history,
                  isImproving: isImproving,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Labels X-axis (premier et dernier mois)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatMonthLabel(history.first['month'] as String? ?? ''),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: MintColors.textMuted,
                  ),
                ),
                Text(
                  _formatMonthLabel(history.last['month'] as String? ?? ''),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: MintColors.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Formate "2026-02" en "Fev 2026".
  String _formatMonthLabel(String monthKey) {
    if (monthKey.length < 7) return monthKey;
    try {
      final parts = monthKey.split('-');
      final year = parts[0];
      final monthIndex = int.parse(parts[1]);
      if (monthIndex < 1 || monthIndex > 12) return monthKey;
      return '${_monthLabelsFr[monthIndex - 1]} $year';
    } catch (_) {
      return monthKey;
    }
  }

  // ════════════════════════════════════════════════════════════════
  //  Helpers used by SLM prompt construction
  // ════════════════════════════════════════════════════════════════

  // ════════════════════════════════════════════════════════════════
  //  4b. SCENARIO NARRATIONS (T7 — Coach AI Layer)
  // ════════════════════════════════════════════════════════════════

  /// Displays LLM-generated scenario narrations (Prudent / Base / Optimiste).
  /// Returns SizedBox.shrink() if no narrative or no scenarios available.
  Widget _buildScenarioNarrations() {
    final l10n = S.of(context);
    final narrations = _narrative?.scenarioNarrations;
    if (narrations == null || narrations.isEmpty) {
      return const SizedBox.shrink();
    }

    final labels = ['Prudent', 'Base', 'Optimiste'];
    final colors = [
      const Color(0xFF6B7280), // grey for prudent
      MintColors.primary, // mint green for base
      const Color(0xFF10B981), // emerald for optimiste
    ];
    final icons = [
      Icons.shield_outlined,
      Icons.balance,
      Icons.trending_up,
    ];
    final coachBadgeLabel = (_narrative?.isLlmGenerated ?? false)
        ? (l10n?.coachIaBadge ?? 'Coach IA')
        : (l10n?.coachBadgeStatic ?? 'Coach');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              const Icon(Icons.auto_stories,
                  size: 18, color: MintColors.primary),
              const SizedBox(width: 8),
              Text(
                l10n?.coachScenarioDecodedTitle ?? 'Tes scenarios decryptes',
                style: GoogleFonts.montserrat(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: MintColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  coachBadgeLabel,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: MintColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        for (int i = 0; i < min(narrations.length, 3); i++)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors[i].withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border(left: BorderSide(color: colors[i], width: 3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icons[i], size: 16, color: colors[i]),
                    const SizedBox(width: 6),
                    Text(
                      labels[i],
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w700,
                        color: colors[i],
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  CoachNarrativeService.applyDetailMode(
                    narrations[i],
                    _narrativeMode,
                  ),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: MintColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            CoachNarrativeService.disclaimer,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontStyle: FontStyle.italic,
              color: MintColors.textMuted,
            ),
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  4a. "ET SI..." INTERACTIVE SLIDER PANEL
  // ════════════════════════════════════════════════════════════════

  Widget _buildEtSiPanel() {
    // Gate: if no subscription access, show teaser
    if (!SubscriptionService.hasAccess(CoachFeature.scenariosEtSi)) {
      return _buildEtSiTeaser();
    }

    return Container(
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        children: [
          // Header — expandable
          InkWell(
            onTap: () => setState(() {
              _etSiExpanded = !_etSiExpanded;
              if (!_etSiExpanded) {
                // Reset to defaults
                _etSiLppReturn = ScenarioAssumptions.base.lppReturn;
                _etSiThreeAReturn = ScenarioAssumptions.base.threeAReturn;
                _etSiInvestReturn = ScenarioAssumptions.base.investmentReturn;
                _etSiInflation = ScenarioAssumptions.base.inflation;
                _etSiProjection = null;
              }
            }),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: MintColors.info.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.tune,
                      color: MintColors.info,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Et si... ?',
                      style: GoogleFonts.montserrat(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: MintColors.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    _etSiExpanded ? 'Replier' : 'Ajuster les hypotheses',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: MintColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _etSiExpanded ? Icons.expand_less : Icons.expand_more,
                    color: MintColors.textMuted,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // Expanded content — sliders
          if (_etSiExpanded) ...[
            const Divider(height: 1, color: MintColors.lightBorder),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ajuste les hypotheses de rendement du scenario Base.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: MintColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _etSiSlider(
                    label: 'Rendement LPP',
                    value: _etSiLppReturn * 100,
                    min: 0,
                    max: 5,
                    suffix: '%',
                    decimals: 1,
                    onChanged: (v) =>
                        _updateEtSi(() => _etSiLppReturn = v / 100),
                  ),
                  const SizedBox(height: 12),
                  _etSiSlider(
                    label: 'Rendement 3a',
                    value: _etSiThreeAReturn * 100,
                    min: 0,
                    max: 10,
                    suffix: '%',
                    decimals: 1,
                    onChanged: (v) =>
                        _updateEtSi(() => _etSiThreeAReturn = v / 100),
                  ),
                  const SizedBox(height: 12),
                  _etSiSlider(
                    label: 'Rendement investissements',
                    value: _etSiInvestReturn * 100,
                    min: 0,
                    max: 15,
                    suffix: '%',
                    decimals: 1,
                    onChanged: (v) =>
                        _updateEtSi(() => _etSiInvestReturn = v / 100),
                  ),
                  const SizedBox(height: 12),
                  _etSiSlider(
                    label: 'Inflation',
                    value: _etSiInflation * 100,
                    min: 0,
                    max: 4,
                    suffix: '%',
                    decimals: 1,
                    onChanged: (v) =>
                        _updateEtSi(() => _etSiInflation = v / 100),
                  ),
                  const SizedBox(height: 16),

                  // Impact summary
                  if (_etSiProjection != null) _buildEtSiImpact(),

                  // Reset button
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => _updateEtSi(() {
                        _etSiLppReturn = ScenarioAssumptions.base.lppReturn;
                        _etSiThreeAReturn =
                            ScenarioAssumptions.base.threeAReturn;
                        _etSiInvestReturn =
                            ScenarioAssumptions.base.investmentReturn;
                        _etSiInflation = ScenarioAssumptions.base.inflation;
                      }),
                      icon: const Icon(Icons.refresh, size: 16),
                      label: Text(
                        'Reinitialiser',
                        style: GoogleFonts.inter(fontSize: 13),
                      ),
                    ),
                  ),

                  // Disclaimer
                  const SizedBox(height: 8),
                  Text(
                    'Simulation educative. Les rendements sont des hypotheses '
                    'et ne presagent pas des performances futures (LSFin).',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: MintColors.textMuted,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _etSiSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required String suffix,
    int decimals = 1,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: MintColors.textSecondary,
              ),
            ),
            Text(
              '${value.toStringAsFixed(decimals)}$suffix',
              style: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: MintColors.textPrimary,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: ((max - min) * 10).round(), // 0.1% steps
            activeColor: MintColors.info,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  void _updateEtSi(VoidCallback update) {
    setState(() {
      update();
      _etSiProjection = ForecasterService.projectEtSi(
        profile: _profile!,
        customBase: ScenarioAssumptions(
          label: 'Et si...',
          lppReturn: _etSiLppReturn,
          threeAReturn: _etSiThreeAReturn,
          investmentReturn: _etSiInvestReturn,
          savingsReturn: ScenarioAssumptions.base.savingsReturn,
          inflation: _etSiInflation,
        ),
      );
    });
  }

  Widget _buildEtSiImpact() {
    final baseCapital = _projection!.base.capitalFinal;
    final etSiCapital = _etSiProjection!.base.capitalFinal;
    final delta = etSiCapital - baseCapital;
    final isPositive = delta >= 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            (isPositive ? MintColors.scoreExcellent : MintColors.scoreCritique)
                .withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            isPositive ? Icons.trending_up : Icons.trending_down,
            color: isPositive
                ? MintColors.scoreExcellent
                : MintColors.scoreCritique,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Impact sur ton capital a la retraite',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: MintColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${isPositive ? "+" : "\u2212"}\u00A0${ForecasterService.formatChf(delta.abs())}',
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isPositive
                        ? MintColors.scoreExcellent
                        : MintColors.scoreCritique,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEtSiTeaser() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: MintColors.info.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.tune, color: MintColors.info, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Et si... ?',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ajuste tes hypotheses de rendement pour explorer differents scenarios.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: MintColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.lock_outline, color: MintColors.textMuted, size: 18),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  4b. BENCHMARK SECTION — Anonymous Swiss comparison
  // ════════════════════════════════════════════════════════════════

  Widget _buildBenchmarkSection() {
    final age = _profile!.age;
    final netMensuel = _profile!.salaireBrutMensuel * 0.87;
    final epargneMensuelle = _profile!.totalContributionsMensuelles;

    // Savings rate benchmark
    final savingsBenchmark = BenchmarkService.compareSavings(
      age: age,
      monthlyNetIncome: netMensuel,
      monthlySavings: epargneMensuelle,
    );

    // 3a participation benchmark
    final has3a = _profile!.prevoyance.nombre3a > 0;
    final annualContribution3a = _profile!.total3aMensuel * 12;
    final benchmark3a = BenchmarkService.compare3a(
      age: age,
      has3a: has3a,
      annualContribution: annualContribution3a,
    );

    // Emergency fund benchmark
    final chargesMensuelles = _profile!.depenses.totalMensuel;
    final epargneLiquide = _profile!.patrimoine.epargneLiquide;
    final emergencyMonths =
        chargesMensuelles > 0 ? epargneLiquide / chargesMensuelles : 0.0;
    final emergencyBenchmark = BenchmarkService.compareEmergencyFund(
      age: age,
      emergencyFundMonths: emergencyMonths,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Toi vs la Suisse',
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: MintColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Comparaison anonyme avec les statistiques OFS',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: MintColors.textSecondary,
          ),
        ),
        const SizedBox(height: 14),
        BenchmarkCard(
          benchmark: savingsBenchmark,
          label: 'Taux d\'épargne',
          icon: Icons.savings_outlined,
        ),
        const SizedBox(height: 12),
        BenchmarkCard(
          benchmark: benchmark3a,
          label: 'Prévoyance 3a',
          icon: Icons.shield_outlined,
        ),
        const SizedBox(height: 12),
        BenchmarkCard(
          benchmark: emergencyBenchmark,
          label: 'Fonds d\'urgence',
          icon: Icons.health_and_safety_outlined,
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  5. QUICK ACTIONS
  // ════════════════════════════════════════════════════════════════

  Widget _buildQuickActions() {
    final l10n = S.of(context);
    final checkInDone = _isCheckInDoneThisMonth();

    // Build personalized actions from coaching tips
    final actions =
        <({IconData icon, String label, String route, bool done})>[];

    if (checkInDone) {
      // Check-in done → show with "Fait" badge, fill remaining from tips
      actions.add((
        icon: Icons.check_circle_outlined,
        label: l10n?.coachCheckin ?? 'Check-in\nmensuel',
        route: '/coach/checkin',
        done: true,
      ));
    } else {
      actions.add((
        icon: Icons.calendar_today_outlined,
        label: l10n?.coachCheckin ?? 'Check-in\nmensuel',
        route: '/coach/checkin',
        done: false,
      ));
    }

    // Add top 2 coaching tips (by priority + impact, already sorted)
    final usedRoutes = <String>{'/coach/checkin'};
    for (final tip in _coachingTips) {
      if (actions.length >= 3) break;
      final route = tipRoute(tip);
      if (usedRoutes.contains(route)) continue;
      usedRoutes.add(route);
      // Truncate title to ~15 chars for chip display
      final shortTitle = tip.title.length > 18
          ? '${tip.title.substring(0, 15)}...'
          : tip.title;
      actions
          .add((icon: tip.icon, label: shortTitle, route: route, done: false));
    }

    // Fallback: pad with defaults if not enough tips
    if (actions.length < 2) {
      actions.add((
        icon: Icons.savings_outlined,
        label: l10n?.coachVerse3a ?? 'Verser\n3a',
        route: '/simulator/3a',
        done: false,
      ));
    }
    if (actions.length < 3) {
      actions.add((
        icon: Icons.account_balance_outlined,
        label: l10n?.coachSimBuyback ?? 'Simuler\nrachat',
        route: '/lpp-deep/rachat',
        done: false,
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n?.coachQuickActions ?? 'Actions rapides',
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: MintColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (int i = 0; i < actions.length && i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(
                child: _buildActionChip(
                  icon: actions[i].icon,
                  label: actions[i].label,
                  route: actions[i].route,
                  showDoneBadge: actions[i].done,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required String route,
    bool showDoneBadge = false,
  }) {
    return GestureDetector(
      onTap: () => context.push(route),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            decoration: BoxDecoration(
              color:
                  showDoneBadge ? const Color(0xFFF0FDF4) : MintColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: showDoneBadge
                    ? const Color(0xFF10B981)
                    : MintColors.lightBorder,
                width: showDoneBadge ? 1.5 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 28,
                  color: showDoneBadge
                      ? const Color(0xFF10B981)
                      : MintColors.coachAccent,
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: MintColors.textPrimary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          if (showDoneBadge)
            Positioned(
              top: -6,
              right: -6,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Fait',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  5a. STREAK + MILESTONES SECTION
  // ════════════════════════════════════════════════════════════════

  Widget _buildStreakMilestoneSection() {
    if (_profile == null) return const SizedBox.shrink();

    final streakResult = _streak ?? StreakService.compute(_profile!);
    final milestones = StreakService.computeMilestones(_profile!);
    final reachedCount = milestones.where((m) => m.isReached).length;

    // Nothing to show if no streak and no milestones reached
    if (streakResult.currentStreak == 0 && reachedCount == 0) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tes jalons',
          style: GoogleFonts.montserrat(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: MintColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: MintColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: MintColors.lightBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Left: fire icon + streak count
              if (streakResult.currentStreak > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.local_fire_department,
                        color: Color(0xFFFF6D00),
                        size: 22,
                      ),
                      const SizedBox(width: 6),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${streakResult.currentStreak}',
                            style: GoogleFonts.montserrat(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFFF6D00),
                              height: 1.0,
                            ),
                          ),
                          Text(
                            'mois',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFFFF6D00),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
              ],
              // Right: milestone icons in a row
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: milestones.map((milestone) {
                    return Tooltip(
                      message: milestone.label,
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: milestone.isReached
                            ? MintColors.primary.withValues(alpha: 0.12)
                            : MintColors.lightBorder,
                        child: Icon(
                          milestone.icon,
                          size: 16,
                          color: milestone.isReached
                              ? MintColors.primary
                              : MintColors.textMuted.withValues(alpha: 0.4),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  5b. ASK MINT CARD — Contextual AI entry point
  // ════════════════════════════════════════════════════════════════

  Widget _buildAskMintCard() {
    final byok = context.watch<ByokProvider>();

    if (byok.isConfigured) {
      return _buildAskMintCardActive();
    }
    return _buildAskMintCardSetup();
  }

  /// BYOK configured — "Ton IA est pr\u00eate, pose ta question"
  Widget _buildAskMintCardActive() {
    return GestureDetector(
      onTap: () => context.push('/ask-mint'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1D1D1F),
              Color(0xFF2D2D30),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: MintColors.primary.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Ask MINT',
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: MintColors.success.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'ACTIF',
                          style: GoogleFonts.montserrat(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: MintColors.success,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pose ta question sur la finance suisse',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.7),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.white.withValues(alpha: 0.5),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  /// BYOK not configured — "Active l'IA"
  Widget _buildAskMintCardSetup() {
    return GestureDetector(
      onTap: () => context.push('/profile/byok'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: MintColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MintColors.lightBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: MintColors.accentPastel,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: MintColors.accent,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ask MINT',
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: MintColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Active l\'IA pour des r\u00e9ponses personnalis\u00e9es',
                    style: TextStyle(
                      fontSize: 13,
                      color: MintColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: MintColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Configurer',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  6. DISCLAIMER
  // ════════════════════════════════════════════════════════════════

  Widget _buildDisclaimer() {
    final l10n = S.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        l10n?.coachDisclaimer ??
            'Estimations éducatives \u2014 ne constitue pas un conseil financier. Les rendements passés ne présagent pas des rendements futurs. Consulte un\u00B7e spécialiste pour un plan personnalisé. LSFin.',
        style: GoogleFonts.inter(
          fontSize: 11,
          color: MintColors.textMuted,
          height: 1.5,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  EMPTY GAUGE CUSTOM PAINTER
// ════════════════════════════════════════════════════════════════
//
// Jauge grisee identique a la vraie MintScoreGauge mais
// sans arc rempli — seulement le track (fond).
// Utilisee dans l'etat vide (utilisateur curieux).
// ════════════════════════════════════════════════════════════════

class _EmptyGaugePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 16;
    const strokeWidth = 14.0;
    const startAngle = 0.75 * pi;
    const totalSweep = 1.5 * pi;

    // ── Background track (grayed out) ──
    final trackPaint = Paint()
      ..color = MintColors.lightBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      totalSweep,
      false,
      trackPaint,
    );

    // ── Tick marks (grayed out) ──
    final tickRadius = radius + strokeWidth / 2 + 4;
    for (int i = 0; i <= 4; i++) {
      final fraction = i / 4;
      final angle = startAngle + totalSweep * fraction;
      final innerPoint = Offset(
        center.dx + tickRadius * cos(angle),
        center.dy + tickRadius * sin(angle),
      );
      final outerPoint = Offset(
        center.dx + (tickRadius + 5) * cos(angle),
        center.dy + (tickRadius + 5) * sin(angle),
      );

      final tickPaint = Paint()
        ..color = MintColors.border.withValues(alpha: 0.30)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(innerPoint, outerPoint, tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _EmptyGaugePainter oldDelegate) => false;
}

// ════════════════════════════════════════════════════════════════
//  PLACEHOLDER TRAJECTORY PAINTER
// ════════════════════════════════════════════════════════════════
//
// Dessine 3 courbes simulees (optimiste, base, prudent)
// qui seront floutees en surcouche. Purement decoratif.
// ════════════════════════════════════════════════════════════════

class _PlaceholderTrajectoryPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── Grid lines ──
    final gridPaint = Paint()
      ..color = MintColors.lightBorder.withValues(alpha: 0.5)
      ..strokeWidth = 0.5;

    for (int i = 1; i <= 4; i++) {
      final y = h * i / 5;
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }

    // ── Optimistic curve (green, rising steeply) ──
    _drawSmoothCurve(
      canvas,
      size,
      color: MintColors.trajectoryOptimiste.withValues(alpha: 0.7),
      points: [
        Offset(0, h * 0.65),
        Offset(w * 0.2, h * 0.55),
        Offset(w * 0.4, h * 0.42),
        Offset(w * 0.6, h * 0.30),
        Offset(w * 0.8, h * 0.20),
        Offset(w, h * 0.12),
      ],
    );

    // ── Base curve (blue, moderate rise) ──
    _drawSmoothCurve(
      canvas,
      size,
      color: MintColors.trajectoryBase.withValues(alpha: 0.7),
      points: [
        Offset(0, h * 0.65),
        Offset(w * 0.2, h * 0.60),
        Offset(w * 0.4, h * 0.52),
        Offset(w * 0.6, h * 0.45),
        Offset(w * 0.8, h * 0.40),
        Offset(w, h * 0.35),
      ],
    );

    // ── Prudent curve (orange, gentle rise) ──
    _drawSmoothCurve(
      canvas,
      size,
      color: MintColors.trajectoryPrudent.withValues(alpha: 0.7),
      points: [
        Offset(0, h * 0.65),
        Offset(w * 0.2, h * 0.63),
        Offset(w * 0.4, h * 0.60),
        Offset(w * 0.6, h * 0.58),
        Offset(w * 0.8, h * 0.57),
        Offset(w, h * 0.55),
      ],
    );
  }

  void _drawSmoothCurve(
    Canvas canvas,
    Size size, {
    required Color color,
    required List<Offset> points,
  }) {
    if (points.length < 2) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final path = Path()..moveTo(points.first.dx, points.first.dy);

    for (int i = 0; i < points.length - 1; i++) {
      final current = points[i];
      final next = points[i + 1];
      final controlX = (current.dx + next.dx) / 2;
      path.cubicTo(
        controlX,
        current.dy,
        controlX,
        next.dy,
        next.dx,
        next.dy,
      );
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PlaceholderTrajectoryPainter oldDelegate) =>
      false;
}

// ════════════════════════════════════════════════════════════════
//  SCORE HISTORY MINI-CHART PAINTER
// ════════════════════════════════════════════════════════════════
//
// Dessine une courbe lissee reliant les scores mensuels (max 24).
// Gradient sous la courbe (vert si amelioration, orange sinon).
// Points aux donnees, point final mis en evidence.
// ════════════════════════════════════════════════════════════════

class _ScoreHistoryPainter extends CustomPainter {
  final List<Map<String, dynamic>> history;
  final bool isImproving;

  _ScoreHistoryPainter({
    required this.history,
    required this.isImproving,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (history.length < 2) return;

    final w = size.width;
    final h = size.height;
    const padding = 8.0;
    final chartW = w - padding * 2;
    final chartH = h - padding * 2;

    // Convertir les scores en points
    final scores =
        history.map((e) => (e['score'] as num?)?.toDouble() ?? 0.0).toList();
    final count = scores.length;

    // Y-axis: 0 a 100 (scores de fitness)
    const minY = 0.0;
    const maxY = 100.0;

    List<Offset> points = [];
    for (int i = 0; i < count; i++) {
      final x = padding + (i / (count - 1)) * chartW;
      final normalizedY = (scores[i] - minY) / (maxY - minY);
      final y = padding + chartH - (normalizedY * chartH);
      points.add(Offset(x, y));
    }

    // ── Couleur principale ──
    final lineColor =
        isImproving ? MintColors.success : MintColors.scoreAttention;

    // ── Dessiner le gradient sous la courbe ──
    final gradientPath = _buildSmoothPath(points);
    final fillPath = Path.from(gradientPath)
      ..lineTo(points.last.dx, padding + chartH)
      ..lineTo(points.first.dx, padding + chartH)
      ..close();

    final gradientPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          lineColor.withValues(alpha: 0.25),
          lineColor.withValues(alpha: 0.02),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawPath(fillPath, gradientPaint);

    // ── Dessiner la ligne ──
    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(gradientPath, linePaint);

    // ── Points aux donnees ──
    final dotPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;

    final dotBorderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    for (int i = 0; i < points.length; i++) {
      final isLast = i == points.length - 1;
      final dotRadius = isLast ? 5.0 : 3.0;
      final borderRadius = isLast ? 7.0 : 0.0;

      if (isLast) {
        // Bordure blanche pour le dernier point
        canvas.drawCircle(points[i], borderRadius, dotBorderPaint);
      }
      canvas.drawCircle(points[i], dotRadius, dotPaint);
    }
  }

  /// Construit un path lisse (courbe cubique) a travers les points.
  Path _buildSmoothPath(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);

    for (int i = 0; i < points.length - 1; i++) {
      final current = points[i];
      final next = points[i + 1];
      final controlX = (current.dx + next.dx) / 2;
      path.cubicTo(
        controlX,
        current.dy,
        controlX,
        next.dy,
        next.dx,
        next.dy,
      );
    }

    return path;
  }

  @override
  bool shouldRepaint(covariant _ScoreHistoryPainter oldDelegate) {
    return oldDelegate.history != history ||
        oldDelegate.isImproving != isImproving;
  }
}

class _TrustChip extends StatelessWidget {
  const _TrustChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
